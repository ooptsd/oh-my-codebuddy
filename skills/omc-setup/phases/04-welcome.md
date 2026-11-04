# Phase 4: Completion

## Detect Upgrade from 2.x

Check if user has existing 2.x configuration:

```bash
CONFIG_DIR="${CODEBUDDY_CONFIG_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.codebuddy}}"
case "$CONFIG_DIR" in
  "~") CONFIG_DIR="$HOME" ;;
  "~/"*) CONFIG_DIR="$HOME/${CONFIG_DIR#\~/}" ;;
  "~\\"*) CONFIG_DIR="$HOME/${CONFIG_DIR#\~\\}" ;;
esac
ls "$CONFIG_DIR/commands/ralph-loop.md" 2>/dev/null
```

If found, this is an upgrade from 2.x. Set `IS_UPGRADE=true`.

## Show Welcome Message

### For New Users (IS_UPGRADE is not true):

```
omc Setup Complete!

You don't need to learn any commands. I now have intelligent behaviors that activate automatically.

WHAT HAPPENS AUTOMATICALLY:
- Complex tasks -> I parallelize and delegate to specialists

MAGIC KEYWORDS (optional power-user shortcuts):
Just include these words naturally in your request:

| Keyword | Effect | Example |
|---------|--------|---------|
| autopilot | Autonomous execution | "autopilot build me a todo app" |
| ralph | Persistence mode | "ralph: fix the auth bug" |
| ralplan | Iterative consensus planning | "ralplan this feature" |
| deep interview | Requirements interview | "deep interview me before coding" |
| deslop / anti-slop | Cleanup review | "deslop this module" |
| deep-analyze | Analysis mode | "deep-analyze the flaky test" |
| tdd | TDD mode | "tdd the parser" |
| deepsearch | Codebase search | "deepsearch where config is loaded" |
| ultrathink | Deep reasoning | "ultrathink this design" |
| cancelomc | Stop active omc modes | "cancelomc" |

CANONICAL WORKFLOWS (Tier-0):
plan -> execute -> review -> verify, invoked as /omc:plan and /omc:review.
/deep-interview and /ralplan are independent planning workflows.
/research and /team are internal lanes; /autopilot, /autoresearch, /ralph, /ultragoal stay directly invocable.

TEAMS:
Spawn coordinated agents with shared task lists and real-time messaging:
- /omc:team 3:executor "fix all TypeScript errors"
- /omc:team 5:debugger "fix build errors in src/"
Teams use CodeBuddy's native team runtime (TeamCreate/teammate spawning).
Team orchestration is explicit via /team — there is no bare "team" keyword.

MCP SERVERS:
Register extra MCP servers (web search, GitHub, etc.) through CodeBuddy's native
MCP config: ~/.codebuddy/mcp.json (global) or .mcp.json (project).

HUD STATUSLINE:
The status bar now shows omc state. Restart CodeBuddy to see it.

omc CLI HELPERS (if installed):
- omc hud         - Render the current HUD statusline
- omc teleport    - Create an isolated git worktree
- omc team status - Inspect a running team job
- Session summaries are written to `.omc/sessions/*.json`

That's it! Just use CodeBuddy normally.
```

### Retired in 5.0.0 (all users)

The following commands and keywords were removed in 5.0.0 and are not aliased:
/ultrawork, /ultraqa, /ultrapilot, /swarm, /pipeline, /merge-readiness,
/deep-dive, /sciomc, /ccg, /omc-teams, /setup, /mcp-setup, /omc-reference,
/learner, /writer-memory, /local-build-reminder.
Use the replacement instead — commonly /execute for ultrawork, /verify for ultraqa,
/team for omc-teams, /omc-setup for setup, and CodeBuddy's native MCP config for
mcp-setup; /wiki for omc-reference.

### For Users Upgrading from 2.x (IS_UPGRADE is true):

```
omc Setup Complete! (Upgraded from 2.x)

IMPORTANT: Some legacy 2.x and 3.x commands were retired in 5.0.0 and are
not aliased. Use the replacement workflows.

WHAT'S NEW in 3.0+:
You no longer NEED those commands. Everything is automatic now:
- Just say "autopilot build me ..." instead of /autopilot
- Just say "ralph: <task>" instead of /ralph
- Just say "cancelomc" instead of /cancel

MAGIC KEYWORDS (power-user shortcuts):
| Keyword | Same as old... | Example |
|---------|----------------|---------|
| autopilot | /autopilot | "autopilot build me a todo app" |
| ralph | /ralph | "ralph: fix the bug" |
| ralplan | /ralplan | "ralplan this feature" |
| deep interview | /deep-interview | "deep interview me before coding" |
| cancelomc | /cancel | "cancelomc" |

TEAMS (NEW!):
Spawn coordinated agents with shared task lists and real-time messaging:
- /omc:team 3:executor "fix all TypeScript errors"
- Uses CodeBuddy's native team runtime (TeamCreate/teammate spawning)

HUD STATUSLINE:
The status bar now shows omc state. Restart CodeBuddy to see it.

Your configuration is preserved; retired commands are not recreated.
```

## Optional Rule Templates

If the plugin ships `templates/rules/`, you can copy rule templates into your project's `.codebuddy/rules/` directory for automatic context injection. Check availability first:

```bash
ls "${OMC_SETUP_PLUGIN_ROOT:-${CODEBUDDY_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}}/templates/rules/"*.md 2>/dev/null
```

If present, copy with:
```bash
mkdir -p .codebuddy/rules
cp "${OMC_SETUP_PLUGIN_ROOT:-${CODEBUDDY_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}}/templates/rules/"*.md .codebuddy/rules/
```

## Mark Completion

Get the current omc version and mark setup complete:

```bash
# Get current omc version from the installed OMC block
OMC_VERSION=""
CONFIG_DIR="${CODEBUDDY_CONFIG_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.codebuddy}}"
case "$CONFIG_DIR" in
  "~") CONFIG_DIR="$HOME" ;;
  "~/"*) CONFIG_DIR="$HOME/${CONFIG_DIR#\~/}" ;;
  "~\\"*) CONFIG_DIR="$HOME/${CONFIG_DIR#\~\\}" ;;
esac
for f in "CODEBUDDY.md" ".codebuddy/CODEBUDDY.md" "$CONFIG_DIR/CODEBUDDY.md"; do
  if [ -f "$f" ]; then
    OMC_VERSION=$(grep -m1 'OMC:VERSION:' "$f" 2>/dev/null | sed -E 's/.*OMC:VERSION:([^ ]+).*/\1/' || true)
    [ -n "$OMC_VERSION" ] && break
  fi
done
if [ -z "$OMC_VERSION" ]; then
  OMC_VERSION=$(omc --version 2>/dev/null | head -1 || true)
fi
if [ -z "$OMC_VERSION" ]; then
  OMC_VERSION="unknown"
fi

# Persist completion marker in .omc-config.json
CONFIG_FILE="$CONFIG_DIR/.omc-config.json"
if command -v jq >/dev/null 2>&1; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  EXISTING=$(cat "$CONFIG_FILE" 2>/dev/null || echo '{}')
  TEMP_FILE=$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")
  trap 'rm -f "$TEMP_FILE"' EXIT
  printf '%s\n' "$EXISTING" | jq \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg ver "$OMC_VERSION" \
    '. + {setupCompleted: $ts, setupVersion: $ver}' > "$TEMP_FILE" \
    && mv "$TEMP_FILE" "$CONFIG_FILE" || rm -f "$TEMP_FILE"
  trap - EXIT
fi
echo "Setup complete: omc $OMC_VERSION"
```
