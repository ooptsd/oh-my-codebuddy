#!/usr/bin/env bash
# Verification script for the CodeBuddy omc plugin distribution.
# Resolves PLUGIN from the script's own location so it works regardless of
# where the plugin is cloned or what the user/host is named.
# Exit 0 = all checks pass; non-zero = first failing check.

set -e

PLUGIN="$(cd "$(dirname "$0")" && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok: $*"; }

# 1. Top-level structure
[ -d "$PLUGIN" ] || fail "plugin root $PLUGIN missing"
[ -d "$PLUGIN/.codebuddy-plugin" ] || fail ".codebuddy-plugin/ missing"
[ -f "$PLUGIN/.codebuddy-plugin/plugin.json" ] || fail ".codebuddy-plugin/plugin.json missing"
[ -f "$PLUGIN/.codebuddy-plugin/marketplace.json" ] || fail ".codebuddy-plugin/marketplace.json missing"
[ -d "$PLUGIN/commands" ] || fail "commands/ missing"
[ -d "$PLUGIN/skills" ] || fail "skills/ missing"
[ -d "$PLUGIN/agents" ] || fail "agents/ missing"
[ -d "$PLUGIN/hooks" ] || fail "hooks/ missing"
[ -d "$PLUGIN/scripts" ] || fail "scripts/ missing"
[ -f "$PLUGIN/LICENSE" ] || fail "LICENSE missing"
ok "directory skeleton present"

# 2. No forbidden runtime artifacts
[ -f "$PLUGIN/package.json" ] && fail "package.json should not exist (zero npm deps)"
[ -f "$PLUGIN/package-lock.json" ] && fail "package-lock.json should not exist"
[ -d "$PLUGIN/node_modules" ] && fail "node_modules should not exist"
[ -f "$PLUGIN/.mcp.json" ] && fail ".mcp.json should not exist (MCP excluded)"
[ -d "$PLUGIN/bridge" ] && fail "bridge/ should not exist (MCP excluded)"
# marketplace.json at root is wrong (must be in .codebuddy-plugin/)
[ -f "$PLUGIN/marketplace.json" ] && fail "marketplace.json at plugin root (must be in .codebuddy-plugin/)"
ok "no forbidden runtime artifacts"

# 3. JSON manifests parse
for f in "$PLUGIN/.codebuddy-plugin/plugin.json" \
         "$PLUGIN/.codebuddy-plugin/marketplace.json" \
         "$PLUGIN/hooks/hooks.json"; do
  [ -f "$f" ] || fail "$f missing"
  node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" \
    || fail "$f is not valid JSON"
done
ok "JSON manifests parse"

# 4. Component counts (when populated)
skill_count=$(find "$PLUGIN/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
[ "$skill_count" -gt 0 ] && [ "$skill_count" -ne 39 ] && fail "skill count $skill_count != 39"
cmd_count=$(find "$PLUGIN/commands" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
[ "$cmd_count" -gt 0 ] && [ "$cmd_count" -ne 21 ] && fail "command count $cmd_count != 21"
agent_count=$(find "$PLUGIN/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
[ "$agent_count" -gt 0 ] && [ "$agent_count" -ne 19 ] && fail "agent count $agent_count != 19"
ok "component counts match (39 skills / 21 commands / 19 agents)"

# 5. Hook cross-reference (when hooks.json present)
if [ -f "$PLUGIN/hooks/hooks.json" ]; then
  node -e "
    const fs = require('fs');
    const path = require('path');
    const hooks = JSON.parse(fs.readFileSync('$PLUGIN/hooks/hooks.json','utf8')).hooks;
    const events = Object.keys(hooks);
    const supported = ['SessionStart','UserPromptSubmit','PreToolUse','PermissionRequest','PostToolUse','PostToolUseFailure','SubagentStart','SubagentStop','PreCompact','Stop','SessionEnd'];
    for (const ev of events) {
      if (!supported.includes(ev)) {
        console.error('FAIL: unsupported event ' + ev); process.exit(1);
      }
    }
    let total = 0;
    for (const ev of events) {
      for (const group of hooks[ev]) {
        for (const h of (group.hooks || [])) {
          total++;
          const re = /scripts\/[a-zA-Z0-9_.-]+\.(mjs|cjs)/g;
          const matches = (h.command || '').match(re) || [];
          if (matches.length === 0) { console.error('FAIL: cannot parse script path in ' + ev); process.exit(1); }
          for (const m of matches) {
            const p = path.join('$PLUGIN', m);
            if (!fs.existsSync(p)) { console.error('FAIL: missing script ' + p + ' (referenced by ' + ev + ' hook command)'); process.exit(1); }
          }
        }
      }
    }
    if (total !== 25) { console.error('FAIL: hook command total ' + total + ' != 25'); process.exit(1); }
    // Verify SessionStart 'maintenance' matcher exists (dead-code parity with upstream)
    const ss = hooks.SessionStart || [];
    const hasMaintenance = ss.some(g => g.matcher === 'maintenance');
    if (!hasMaintenance) { console.error('FAIL: SessionStart maintenance matcher missing'); process.exit(1); }
    console.log('ok: ' + total + ' hook commands across ' + events.length + ' supported events; all referenced scripts exist; maintenance matcher present');
  " || fail "hook cross-reference check failed"
fi

# 6. Banned-imports check (Node.js stdlib only)
node -e "
  const fs = require('fs');
  const path = require('path');
  const PLUGIN = '$PLUGIN';
  const STDLIB = /^(node:)?(fs|path|crypto|os|child_process|util|url|stream|module|worker_threads|events|buffer|process)\$/;
  const OUTRIGHT_BAN = new Set(['ajv', 'zod']);
  const RELATIVE = /^(\\.\\.|\\.)(\\/|\\\\|\$)/;
  function walk(dir, out) {
    let entries = [];
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return out; }
    for (const e of entries) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) walk(p, out);
      else if (/\\.(mjs|cjs)\$/.test(e.name)) out.push(p);
    }
    return out;
  }
  const files = Array.from(new Set(walk(path.join(PLUGIN, 'scripts'), [])));
  const violations = [];
  let scanned = 0;
  for (const file of files) {
    scanned++;
    const content = fs.readFileSync(file, 'utf8');
    const lines = content.split(/\r?\n/);
    let lineStart = 0;
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const reqMatch = line.match(/require\\(\\s*['\"]([^'\"]+)['\"]\\s*\\)/);
      const fromMatch = line.match(/from\\s+['\"]([^'\"]+)['\"]/);
      const matches = [];
      if (reqMatch) matches.push({ target: reqMatch[1], idx: reqMatch.index });
      if (fromMatch) matches.push({ target: fromMatch[1], idx: fromMatch.index });
      for (const m of matches) {
        const absIdx = lineStart + m.idx;
        if (RELATIVE.test(m.target)) continue;
        if (STDLIB.test(m.target)) continue;
        if (OUTRIGHT_BAN.has(m.target)) {
          violations.push(file + ':' + (i + 1) + ': outright banned require/import \"' + m.target + '\"');
          continue;
        }
        const tail = content.slice(Math.max(0, absIdx - 200), absIdx);
        const inTry = /try\\s*\\{/.test(tail);
        if (!inTry) {
          violations.push(file + ':' + (i + 1) + ': non-stdlib require/import \"' + m.target + '\" not wrapped in defensive try/catch');
        }
      }
      lineStart += line.length + 1;
    }
  }
  if (violations.length > 0) {
    console.error('FAIL: banned-imports check failed:');
    for (const v of violations) console.error('  ' + v);
    process.exit(1);
  }
  console.log('ok: ' + scanned + ' script files have no banned imports');
" || fail "banned-imports check failed"

# 7. Claude-config residue audit (CodeBuddy-native conventions)
# Zero-tolerance: any CLAUDE_* env var, active .claude path, CLAUDE.md
# target, Claude Code tool-call syntax (Task/omc: namespace, Claude model
# tiers, TodoWrite), or legacy team CLI-lane vocabulary is a violation.
# Allow-list is limited to (a) the upstream project name "oh-my-claudecode"
# family, (b) .claude-plugin/ compat notes that describe host lookup
# behavior, (c) the upstream-shaped worktree-dir encoding
# --claude-worktrees-X, and (d) omc ask provider routing where
# "claude" names an external CLI provider, not the host.
AUDIT_TMP="$(mktemp)"
cat > "$AUDIT_TMP" <<'AUDIT_EOF'
const fs = require('fs');
const path = require('path');
const PLUGIN = process.argv[2];
// docs/plans/ records design history and legitimately mentions removed items.
const roots = ['scripts', 'hooks', 'skills', 'commands', 'agents'].map(d => path.join(PLUGIN, d));
function walk(dir, out) {
  let entries = [];
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return out; }
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (/\.(mjs|cjs|sh|md|json)$/.test(e.name)) out.push(p);
  }
  return out;
}
const files = roots.flatMap(r => walk(r, []));
const violations = [];
for (const file of files) {
  const rel = file.replace(PLUGIN + '/', '');
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    const trimmed = line.trim();
    // Upstream project/package names keep "claude" in their identifier.
    const isUpstreamName = /oh-my-claude|claude-plugins-official/.test(line);
    // Host-lookup compat note (README compat table: .claude-plugin/ fallback).
    const isCompatNote = /\.claude-plugin/.test(line);
    // Upstream-shaped worktree dir encoding kept in defensive regexes.
    const isWorktreeCompat = /worktrees/.test(line) && /claude-worktrees/.test(line);
    // "claude" as an external CLI provider (omc ask / team routing), not the host.
    const isProviderName = /omc ask|provider/.test(line) && /[`|"']claude[`|"']/.test(line);
    const allowed = isUpstreamName || isCompatNote || isWorktreeCompat || isProviderName;
    if (allowed) return;
    // CLAUDE_* env vars (CLAUDE_CONFIG_DIR, CLAUDE_PLUGIN_ROOT, ...) — gone.
    if (/\bCLAUDE_[A-Z_]+\b/.test(line)) {
      violations.push(rel + ':' + (i + 1) + ': CLAUDE_* env: ' + trimmed.slice(0, 90));
    }
    // Active .claude paths.
    if (/['" ]\.claude(\/|['" ])/.test(line) || /~\/\.claude/.test(line)) {
      violations.push(rel + ':' + (i + 1) + ': .claude path: ' + trimmed.slice(0, 90));
    }
    // CLAUDE.md as active target.
    if (/CLAUDE\.md/.test(line)) {
      violations.push(rel + ':' + (i + 1) + ': CLAUDE.md ref: ' + trimmed.slice(0, 90));
    }
    // Claude Code tool-call syntax — the host Agent tool takes bare names.
    if (/subagent_type="\s*omc:|subagent_type":\s*"omc:/.test(line)) {
      violations.push(rel + ':' + (i + 1) + ': omc: subagent_type: ' + trimmed.slice(0, 90));
    }
    if (/Task\(\s*subagent_type/.test(line)) {
      violations.push(rel + ':' + (i + 1) + ': Task(subagent_type: ' + trimmed.slice(0, 90));
    }
    if (/Skill\(\s*"omc:/.test(line)) {
      violations.push(rel + ':' + (i + 1) + ': Skill("omc:..."): ' + trimmed.slice(0, 90));
    }
    // Claude model tiers — CodeBuddy uses default/lite/reasoning.
    if (/model="(sonnet|haiku|opus)"/.test(line)) {
      violations.push(rel + ':' + (i + 1) + ': Claude model tier: ' + trimmed.slice(0, 90));
    }
    // Claude Code task tool name.
    if (/\bTodoWrite\b/.test(line)) {
      violations.push(rel + ':' + (i + 1) + ': TodoWrite: ' + trimmed.slice(0, 90));
    }
    // Deleted legacy team CLI lane vocabulary.
    if (/\bclaude_worker\b/.test(line) || /\bdefaultAgentType\b/.test(line)) {
      violations.push(rel + ':' + (i + 1) + ': legacy team lane: ' + trimmed.slice(0, 90));
    }
  });
}
if (violations.length > 0) {
  console.error('FAIL: Claude-config residue audit found ' + violations.length + ' issue(s):');
  for (const v of violations.slice(0, 40)) console.error('  ' + v);
  if (violations.length > 40) console.error('  ... and ' + (violations.length - 40) + ' more');
  process.exit(1);
}
console.log('ok: no Claude-config residue across ' + files.length + ' files');
AUDIT_EOF
node "$AUDIT_TMP" "$PLUGIN" || { rm -f "$AUDIT_TMP"; fail "Claude-config residue audit failed"; }
rm -f "$AUDIT_TMP"

echo "PASS: all verification checks"
