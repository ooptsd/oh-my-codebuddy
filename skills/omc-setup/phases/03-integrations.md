# Phase 3: Integration Setup

## Step 3.1: Verify Plugin Installation

```bash
CONFIG_DIR="${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"
case "$CONFIG_DIR" in
  "~") CONFIG_DIR="$HOME" ;;
  "~/"*) CONFIG_DIR="$HOME/${CONFIG_DIR#\~/}" ;;
  "~\\"*) CONFIG_DIR="$HOME/${CONFIG_DIR#\~\\}" ;;
esac
if [ -f "$CONFIG_DIR/plugins/installed_plugins.json" ] \
  && grep -q '"omc@omc-plugins"' "$CONFIG_DIR/plugins/installed_plugins.json" 2>/dev/null; then
  echo "Plugin verified"
else
  echo "Plugin NOT found - run: /plugin install omc@omc-plugins"
fi
```

## Step 3.2: MCP Server Configuration (Pointer Only)

MCP servers extend CodeBuddy with additional tools (web search, GitHub, etc.). omc no longer ships an MCP setup skill; servers are registered through CodeBuddy's native MCP surfaces.

If the user asks about MCP servers, point them at the native registration path:

- Global: `~/.codebuddy/mcp.json` (user-level MCP servers)
- Project: `.mcp.json` in the project root (shared with the team)
- Manage via the native MCP settings surface (`/mcp` command or `mcp.json` editing)

Do **not** try to invoke an MCP setup skill — `mcp-setup` was removed in 5.0.0 and has no replacement skill; the native surfaces above are the whole story.

## Step 3.3: Configure Agent Teams (Optional)

Agent teams let you spawn N coordinated agents working on a shared task list with inter-agent messaging. CodeBuddy provides native team support via `TeamCreate`/`TeamDelete` and the Agent tool's teammate spawning; no experimental settings flag is required.

Use AskUserQuestion:

**Question:** "Would you like to configure agent team defaults? Teams let you spawn coordinated agents (e.g., `/omc:team 3:executor 'fix all errors'`)."

**Options:**
1. **Yes, configure defaults (Recommended)** - Set team defaults (agent count, type)
2. **No, skip** - Keep built-in defaults (can configure later)

### If User Chooses YES:

#### Configure Team Defaults in omc-config

Use AskUserQuestion:

**Question 1:** "How many agents should teams spawn by default?"

**Options:**
1. **3 agents (Recommended)** - Good balance of speed and resource usage
2. **5 agents (maximum)** - Maximum parallelism for large tasks
3. **2 agents** - Conservative, for smaller projects

Store the team configuration in the active config directory's `.omc-config.json`:

```bash
CONFIG_DIR="${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"
case "$CONFIG_DIR" in
  "~") CONFIG_DIR="$HOME" ;;
  "~/"*) CONFIG_DIR="$HOME/${CONFIG_DIR#\~/}" ;;
  "~\\"*) CONFIG_DIR="$HOME/${CONFIG_DIR#\~\\}" ;;
esac
CONFIG_FILE="$CONFIG_DIR/.omc-config.json"
mkdir -p "$(dirname "$CONFIG_FILE")"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to update $CONFIG_FILE safely."
  echo "Install jq and rerun setup. Existing config was not modified."
  exit 1
fi

if [ -f "$CONFIG_FILE" ]; then
  EXISTING=$(cat "$CONFIG_FILE")
else
  EXISTING='{}'
fi

# Replace MAX_AGENTS with user choice
TEMP_FILE=$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")
trap 'rm -f "$TEMP_FILE"' EXIT
if printf '%s\n' "$EXISTING" | jq \
  --argjson maxAgents MAX_AGENTS \
  '. + {team: {ops: {maxAgents: $maxAgents, monitorIntervalMs: 30000, shutdownTimeoutMs: 15000}}}' > "$TEMP_FILE" \
  && mv "$TEMP_FILE" "$CONFIG_FILE"; then
  :
else
  echo "ERROR: Failed to update $CONFIG_FILE. Existing config was not modified."
  rm -f "$TEMP_FILE"
  exit 1
fi
trap - EXIT

echo "Team configuration saved:"
echo "  Max agents: MAX_AGENTS"
echo "  Model: teammates inherit your session model"
```

**Note:** Teammates do not have a separate model default. Each teammate inherits your configured model. Subagents spawned by teammates can use any model tier.

### If User Chooses NO:

Skip this step. Team defaults remain built-in. User can re-run `/omc:omc-setup --force` later to configure them.
