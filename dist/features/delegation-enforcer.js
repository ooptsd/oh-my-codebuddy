/**
 * Delegation Enforcer
 *
 * Middleware for Task/Agent delegation calls. Model handling follows the
 * CodeBuddy pass-through contract (2026-11-04 tier-routing removal):
 * an explicit model param is preserved verbatim; when absent, nothing is
 * injected and CodeBuddy's native subagent model resolution decides.
 */
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';
import { getAgentDefinitions } from '../agents/definitions.js';
import { normalizeDelegationRole } from './delegation-routing/types.js';
import { loadConfig } from '../config/loader.js';
import { createBuiltinSkills, getSkillsDir } from './builtin-skills/skills.js';
import { isSkininthegamebrosUser } from '../utils/skininthegamebros-user.js';
import entitlementManifest from '../config/builtin-skill-entitlements.json' with { type: 'json' };
// ---------------------------------------------------------------------------
// Config cache — avoids repeated disk reads on every enforceModel() call (F10)
//
// The cache key is built from every env var that loadConfig() reads.
// When any env var changes (as tests do between cases), the key changes and
// loadConfig() is called fresh. The mock in routing-force-inherit.test.ts
// replaces the loadConfig import binding, so vi.fn() return values flow
// through here automatically — no extra wiring needed.
// ---------------------------------------------------------------------------
/** All env var names that affect the output of loadConfig(). */
const CONFIG_ENV_KEYS = [
    'ANTHROPIC_BASE_URL',
    'CLAUDE_MODEL',
    'ANTHROPIC_MODEL',
    'OMC_ROUTING_ENABLED',
    'OMC_MODEL_HIGH',
    'OMC_MODEL_MEDIUM',
    'OMC_MODEL_LOW',
    'CLAUDE_CODE_BEDROCK_HAIKU_MODEL',
    'CLAUDE_CODE_BEDROCK_SONNET_MODEL',
    'CLAUDE_CODE_BEDROCK_OPUS_MODEL',
    'CLAUDE_CODE_BEDROCK_FABLE_MODEL',
    'ANTHROPIC_DEFAULT_HAIKU_MODEL',
    'ANTHROPIC_DEFAULT_SONNET_MODEL',
    'ANTHROPIC_DEFAULT_OPUS_MODEL',
    'ANTHROPIC_DEFAULT_FABLE_MODEL',
];
function buildEnvCacheKey() {
    return CONFIG_ENV_KEYS.map((k) => `${k}=${process.env[k] ?? ''}`).join('|');
}
let _cachedConfig = null;
let _cachedConfigKey = '';
function getCachedConfig() {
    // In test environments, skip the cache so vi.mock/vi.fn() overrides of
    // loadConfig are always respected without needing to invalidate the cache.
    if (process.env.VITEST) {
        return loadConfig();
    }
    const key = buildEnvCacheKey();
    if (_cachedConfig === null || key !== _cachedConfigKey) {
        _cachedConfig = loadConfig();
        _cachedConfigKey = key;
    }
    return _cachedConfig;
}
function isDelegationToolName(toolName) {
    const normalizedToolName = toolName.toLowerCase();
    return normalizedToolName === 'agent' || normalizedToolName === 'task';
}
function canonicalizeSubagentType(subagentType) {
    const hasPrefix = subagentType.startsWith('oh-my-claudecode:');
    const rawAgentType = subagentType.replace(/^oh-my-claudecode:/, '');
    const canonicalAgentType = normalizeDelegationRole(rawAgentType);
    return hasPrefix ? `oh-my-claudecode:${canonicalAgentType}` : canonicalAgentType;
}
/**
 * Bundled-skill guidance for an unknown agent identifier (issue #3667).
 *
 * Task/Agent subagent_type identifiers and bundled skills share the
 * `oh-my-claudecode:` namespace. When an identifier resolves to a bundled
 * skill rather than an agent, the error names the Skill tool and the correct
 * identifier instead of a generic "Unknown agent type", so the caller cannot
 * mistake the failure for a typo and substitute a closest-match agent.
 * Exact match only — no fuzzy substitution.
 */
function skillInvocationHint(agentType, originalSubagentType) {
    const primary = resolveBundledSkillPrimary(agentType, originalSubagentType);
    if (!primary) {
        return null;
    }
    return ` "${agentType}" is a bundled Skill, not an agent — invoke it with the Skill tool (Skill(skill="oh-my-claudecode:${primary}")) instead of Task/Agent subagent_type, and do NOT substitute a similarly-named agent`;
}
const SKININTHEGAMEBROS_ONLY_SKILLS = new Set(entitlementManifest.skininthegamebrosOnlySkills.map((skill) => skill.trim().toLowerCase()));
/**
 * Whether a bundled skill directory is visible to the current user, mirroring
 * loadSkillsFromDirectory's entitlement filter. Hidden skills must never be
 * suggested as invocable, even when their directory exists on disk.
 */
function isSkillVisibleToUser(skillName) {
    // Case-fold before the Set lookup: identifiers are matched case-insensitively
    // while filesystem lookup is case-insensitive on Windows/macOS.
    return !SKININTHEGAMEBROS_ONLY_SKILLS.has(skillName.toLowerCase()) || isSkininthegamebrosUser();
}
/**
 * Resolve the canonical primary name for a bundled-skill identifier, mirroring
 * the PreToolUse hook's resolution order (issue #3667): canonical registry
 * precedence wins before any directory shortcut. `learner` therefore resolves
 * to its canonical owner `skillify` (deprecated alias claimed before the
 * legacy skills/learner directory), while dir-only names such as `plan` fall
 * back to their registered name (`omc-plan`). The same visibility/entitlement
 * filter as the runtime loader applies, failing closed for runtime-hidden
 * skills.
 * Exact match only — no fuzzy substitution.
 */
function resolveBundledSkillPrimary(agentType, originalSubagentType) {
    // Strip the OMC namespace aliases case-insensitively, then case-fold once
    // before every check: registry, alias, visibility, and filesystem lookups
    // must agree even on case-insensitive filesystems (Windows/macOS), where a
    // case-variant identifier resolves the same directory.
    const foldedInput = agentType.toLowerCase();
    const stripped = foldedInput.startsWith('oh-my-claudecode:')
        ? foldedInput.slice('oh-my-claudecode:'.length)
        : foldedInput.startsWith('omc:')
            ? foldedInput.slice('omc:'.length)
            : foldedInput;
    const skills = createBuiltinSkills();
    const match = skills.find((s) => s.name.toLowerCase() === stripped);
    if (match) {
        return match.aliasOf ?? match.name;
    }
    // Bare (un-namespaced) identifiers stop here: the directory shortcut is
    // reserved for the pinned plugin namespace so native/session-defined agents
    // (e.g. Claude Code's built-in `Plan` vs the skills/plan dir registering
    // omc-plan) are never mistaken for skills (issue #3667 P1, JS/TS parity).
    const wasNamespaced = typeof originalSubagentType === 'string'
        && /^(?:oh-my-claudecode|omc):/i.test(originalSubagentType.trim());
    if (!wasNamespaced) {
        return null;
    }
    // Fail closed before the directory shortcut: a hidden skill directory must
    // never be recommended as an invocable bundled skill.
    if (!isSkillVisibleToUser(stripped)) {
        return null;
    }
    // Directory shortcut parity with the hook: names that exist as skill
    // directories but are not canonical claims (e.g. plan -> omc-plan).
    const directPath = join(getSkillsDir(), stripped, 'SKILL.md');
    if (!existsSync(directPath)) {
        return null;
    }
    try {
        const content = readFileSync(directPath, 'utf-8').replace(/^\uFEFF/, '');
        const fmMatch = content.match(/^---[\r\n]+([\s\S]*?)[\r\n]+---/);
        if (fmMatch) {
            const nameMatch = fmMatch[1].match(/^name:\s*(\S+)/m);
            if (nameMatch) {
                return nameMatch[1].trim().replace(/^["']|["']$/g, '');
            }
        }
    }
    catch {
        // Fall through to the directory name.
    }
    return stripped;
}
/**
 * Enforce contract for an agent delegation call (CodeBuddy semantics)
 *
 * Model handling after tier-routing removal (2026-11-04 design):
 * - Explicit model param -> passed through verbatim. No CC-alias
 *   normalization, no stripping: CodeBuddy accepts model IDs, names,
 *   aliases, and lite/reasoning scene variants natively.
 * - No model param -> nothing injected. CodeBuddy's own resolution chain
 *   decides (per-agent settings -> built-in declaration -> inherit main
 *   model).
 *
 * @param agentInput - The agent/task input parameters
 * @returns Enforcement result with modified input
 * @throws Error if agent type is unknown (issue #3667)
 */
export function enforceModel(agentInput) {
    const canonicalSubagentType = canonicalizeSubagentType(agentInput.subagent_type);
    const agentType = canonicalSubagentType.replace(/^oh-my-claudecode:/, '');
    // Validate the agent BEFORE anything else so the unknown-agent error and
    // Skill-tool guidance fire even when a model is explicit (issue #3667 P2).
    const config = getCachedConfig();
    const agentDefs = getAgentDefinitions({ config });
    const agentDef = agentDefs[agentType];
    if (!agentDef) {
        const hint = skillInvocationHint(agentType, agentInput.subagent_type);
        throw new Error(hint
            ? `Unknown agent type: ${agentType} (from ${agentInput.subagent_type}) —${hint}.`
            : `Unknown agent type: ${agentType} (from ${agentInput.subagent_type})`);
    }
    // Explicit model: pass through verbatim.
    if (agentInput.model) {
        return {
            originalInput: agentInput,
            modifiedInput: { ...agentInput, subagent_type: canonicalSubagentType },
            injected: false,
            model: agentInput.model,
        };
    }
    // No model: inject nothing. CodeBuddy's native subagent model resolution
    // takes over (per-agent settings -> built-in declaration -> main model).
    const modifiedInput = { ...agentInput, subagent_type: canonicalSubagentType };
    return {
        originalInput: agentInput,
        modifiedInput,
        injected: false,
        model: 'inherit',
    };
}
/**
 * Check if tool input is an agent delegation call
 */
export function isAgentCall(toolName, toolInput) {
    if (!isDelegationToolName(toolName)) {
        return false;
    }
    if (!toolInput || typeof toolInput !== 'object') {
        return false;
    }
    const input = toolInput;
    return (typeof input.subagent_type === 'string' &&
        typeof input.prompt === 'string' &&
        typeof input.description === 'string');
}
/**
 * Process a pre-tool-use hook for model enforcement
 */
export function processPreToolUse(toolName, toolInput) {
    if (!isAgentCall(toolName, toolInput)) {
        return { modifiedInput: toolInput };
    }
    const result = enforceModel(toolInput);
    if (result.warning) {
        console.warn(result.warning);
    }
    return {
        modifiedInput: result.modifiedInput,
        warning: result.warning,
    };
}
/**
 * Get model for an agent type (for testing/debugging)
 */
export function getModelForAgent(agentType) {
    const normalizedType = normalizeDelegationRole(agentType.replace(/^oh-my-claudecode:/, ''));
    const agentDefs = getAgentDefinitions({ config: getCachedConfig() });
    const agentDef = agentDefs[normalizedType];
    if (!agentDef) {
        const hint = skillInvocationHint(normalizedType, agentType);
        throw new Error(hint ? `Unknown agent type: ${normalizedType} —${hint}.` : `Unknown agent type: ${normalizedType}`);
    }
    return agentDef.model ?? 'inherit';
}
//# sourceMappingURL=delegation-enforcer.js.map