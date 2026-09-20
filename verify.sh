#!/usr/bin/env bash
# Verification script for the CodeBuddy omb plugin distribution.
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

echo "PASS: all verification checks"
