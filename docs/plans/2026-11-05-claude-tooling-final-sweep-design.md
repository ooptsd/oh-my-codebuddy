# Claude Tooling Final Sweep — Design

**Date:** 2026-11-05
**Status:** approved (user chose full cleanup + delete team legacy CLI lane)
**Predecessor:** `2026-11-05-codebuddy-config-declaude-design.md` (5.4.3, env/config level)

## Problem

After the 5.4.3 config-level migration, verify.sh passes — but its allow-list
hides a second class of residue: **Claude Code tool-call semantics** written
into skill instructions and hook code. Unlike env vars or paths, these are
behavioral: an LLM following the skill text will emit tool calls that
CodeBuddy rejects or silently mis-routes.

## Inventory (verified by grep, 2026-11-05)

### A. Tool-call syntax (functional)

| Where | Legacy | CodeBuddy-native |
|---|---|---|
| autopilot:119-121 | `Task(subagent_type="omc:architect"...)` | `Agent(subagent_type="architect"...)` |
| external-context:47-52 | `Task(... omc:document-specialist, model="sonnet")` | `Agent(... document-specialist, model="default")` |
| team:334,659 | `"subagent_type": "omc:executor"` | `"subagent_type": "executor"` |
| ralph:159,183,208-210 | `Skill("omc:ai-slop-cleaner")`, `Task(subagent_type="omc:...")` | `Skill("ai-slop-cleaner")`, `Agent(subagent_type="...")` |
| plan:105-106,137,161-163 | `Task(subagent_type="omc:...")` | `Agent(subagent_type="...")` |
| deep-interview:553 | `Task(subagent_type="omc:explore", model="haiku")` | `Agent(subagent_type="explore", model="lite")` |
| deepinit:88 | `Task(subagent_type="explore", model="haiku")` | `Agent(subagent_type="explore", model="lite")` |
| scripts/code-simplifier.mjs:77 | `Task(subagent_type="omc:code-simplifier"` | `Agent(subagent_type="code-simplifier"` |

Model tier mapping: `haiku → lite`, `sonnet → default`, `opus → reasoning`.
Bare `Task tool` prose → `Agent tool`.

Note: hooks already dual-match `Task || Agent` (pre-tool-enforcer.mjs:1583,
post-tool-verifier.mjs:1071), so hook-side tool-name matching needs no change
for Agent. The `omc:` namespace is the part CodeBuddy cannot resolve — its
agents live at the bare name (agents/*.md frontmatter has no namespace).

### B. TodoWrite vocabulary

- `skills/team/SKILL.md` — 14 prose refs "TodoWrite or the active task-list
  surface" (some already hedged; drop the Claude-first naming)
- `scripts/pre-tool-enforcer.mjs:1294-1299` — message branch keyed on tool
  name `TodoWrite`; CodeBuddy emits `TaskCreate`/`TaskUpdate`, so the branch
  is dead code. Re-key to `TaskCreate`/`TaskUpdate`.
- `scripts/post-tool-verifier.mjs:1002` — `case 'TodoWrite'` same problem;
  re-key to `TaskCreate`/`TaskUpdate` (they already have a Task case; merge
  accordingly).

### C. team legacy CLI lane (user decision: delete entirely)

`omc team` tmux/CLI orchestration docs describe the omc CLI binary
(oh-my-claude-sisyphus), not CodeBuddy surfaces. Deleting per user decision:

- team/SKILL.md: `claude_worker` + CLI worker table (§CLI Workers, ~L589-663),
  outbox ingestion §(~L665-723), Runtime V2 §(~L858-868), Dynamic Scaling
  §(~L870-877), Per-Role Provider & Model Routing §(~L907-978), psmux gate
  §(~L198-207), orphan scan Step 5 (~L567-580), `defaultAgentType` config
  (~L888,897), tmux references in preamble rules, Git Worktree Integration
  §(~L997-1028) — that § documents `createWorkerWorktree` for MCP/tmux
  workers; native teammates need no worktree API.
- autopilot/SKILL.md:~191-212: "team execution via tmux CLI runtime +
  `omc team 1:cursor` + `/omc-teams`" block → replace with native team note.
- cancel/SKILL.md: tmux orphan scan (~L241-258), kill-session blocks
  (~L379-390), `omc-teams requires tmux session` (~L59) — legacy CLI cleanup
  steps removed; keep state-based team cleanup.
- Keep: `omc ask` provider routing (different feature, `claude` there names
  an external CLI, covered by existing allow-list).

### D. verify.sh extension (prevent regression)

Add zero-tolerance patterns to audit §7 (same file set):

1. `subagent_type="omc:` / `subagent_type": "omc:` — namespaced agent calls
2. `Task(subagent_type` — Claude Code tool name in call syntax
3. `Skill("omc:` — namespaced skill invocation
4. `model="(sonnet|haiku|opus)"` — Claude model tiers
5. `\bTodoWrite\b` — Claude task tool name (hooks + docs)
6. `claude_worker` — deleted lane
7. `defaultAgentType` — deleted lane config key

Allow-list note: existing upstream-name exemption
(/oh-my-claude|claude-plugins-official/) stays for identifiers; the new
patterns are syntax-level and get no exemptions.

### E. Wording edge items

- `skills/skill/SKILL.md:10,26,46` "oh-my-claudecode skills" → "omc skills"
  (upstream-name exemption makes this optional; do it for reader clarity,
  keep npm package refs like `oh-my-claude-sisyphus` untouched)
- `skills/ask/SKILL.md:42` `claude --version` — legitimate: `claude` is the
  external provider CLI being probed. Keep.

## Non-goals

- Skill read-path work: verified equivalent. Plugin skills resolve via
  `${CODEBUDDY_PLUGIN_ROOT}/skills/<name>/SKILL.md` (keyword-detector.mjs:35,
  97-104), user skills via `${CODEBUDDY_CONFIG_DIR:-~/.codebuddy}/skills/omc-learned/`,
  project skills via `.omc/skills/` — all CodeBuddy-native already.
- `omc ask` provider lists that include `claude` — external CLI semantics.
- Upstream npm package identifiers (`oh-my-claude-sisyphus`,
  `oh-my-claudecode.js` basename in pre-tool-enforcer.mjs:1061-1072) — the
  CLI binary keeps its real name.
- README/docs comparisons with Claude Code OMC — documentation context.

## Execution order

1. Tool-call syntax (A) — smallest blast radius, highest functional value
2. TodoWrite re-keying (B) — hook dead code becomes live code
3. Legacy lane deletion (C) — largest diff, after A/B stabilize team file
4. verify.sh extension (D) + full run — gate
5. Wording (E) — cosmetic pass

## Verification

`./verify.sh` must pass with the extended audit (zero residue). Manual
spot-check: grep for each new pattern returns 0 hits outside allow-list.
