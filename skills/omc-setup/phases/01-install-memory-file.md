# Phase 1: Install CODEBUDDY.md

## Determine Configuration Target

If `--local` flag was passed, set `CONFIG_TARGET=local`.
If `--global` flag was passed, set `CONFIG_TARGET=global`.

Otherwise (initial setup wizard), use AskUserQuestion to prompt:

**Question:** "Where should I configure oh-my-codebuddy?"

**Options:**
1. **Local (this project)** - Creates `.codebuddy/CODEBUDDY.md` (or root `CODEBUDDY.md`) in the current project directory. Best for project-specific configurations.
2. **Global (all projects)** - Installs the OMC block into `~/.codebuddy/CODEBUDDY.md` for all CodeBuddy sessions. Best for consistent behavior everywhere.

Set `CONFIG_TARGET` to `local` or `global` based on user's choice.

## Install the OMC Block

**Canonical source**: the plugin bundles the canonical OMC block at `docs/CODEBUDDY.md` inside the active plugin root, delimited by `<!-- OMC:START -->` / `<!-- OMC:END -->` markers with an `<!-- OMC:VERSION:x.y.z -->` header.

**Resolution order for target files (CodeBuddy conventions):**
- `local`: `./CODEBUDDY.md` first; if it does not exist, use `./.codebuddy/CODEBUDDY.md` (create the directory when needed). Both locations are equivalent per CodeBuddy's memory loading order.
- `global`: `${CODEBUDDY_CONFIG_DIR:-~/.codebuddy}/CODEBUDDY.md` (create the file if missing).

**Installation procedure** (idempotent, marker-based):

1. Read the canonical block from `${OMC_SETUP_PLUGIN_ROOT:-${CODEBUDDY_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}}/docs/CODEBUDDY.md`.
2. Read the target file if it exists.
3. If the target already contains an `<!-- OMC:START -->...<!-- OMC:END -->` block, replace that exact block (marker-to-marker, inclusive) with the canonical block, leaving all other content untouched.
4. If the target has no OMC block, append the canonical block at the end of the file separated by a blank line (create the file with just the block when absent).
5. Verify after mutation: the target contains exactly one `<!-- OMC:START -->` marker, exactly one `<!-- OMC:END -->` marker, and an `<!-- OMC:VERSION:` header.

**Rules**: never delete user content outside the marker block; never reorder the file; if a pre-existing malformed block (START without END, or multiple blocks) is found, stop and report it instead of guessing.

For `local` installs inside a git repository, also seed `.git/info/exclude` with an omc block that ignores local `.omc/*` artifacts by default while keeping `.omc/skills/` trackable for committed project skills:

```bash
if [ -d .git ] || git rev-parse --git-dir >/dev/null 2>&1; then
  grep -q "# omc local state" .git/info/exclude 2>/dev/null || cat >> .git/info/exclude << 'EOF'
# omc local state
.omc/*
!.omc/skills/
EOF
fi
```

## Report Success

If `CONFIG_TARGET` is `local`:
```
omc Project Configuration Complete
- CODEBUDDY.md: OMC block installed in ./CODEBUDDY.md (or ./.codebuddy/CODEBUDDY.md)
- Git excludes: Added local `.omc/*` ignore rules to `.git/info/exclude` (keeps `.omc/skills/` trackable)
- Scope: PROJECT - applies only to this project
- Hooks: Provided by plugin (no manual installation needed)
- Agents: available via the plugin's agents/ directory

Note: This configuration is project-specific and won't affect other projects or global settings.
```

If `CONFIG_TARGET` is `global`:
```
omc Global Configuration Complete
- CODEBUDDY.md: OMC block installed at ${CODEBUDDY_CONFIG_DIR:-~/.codebuddy}/CODEBUDDY.md
- Scope: GLOBAL - applies to all CodeBuddy sessions
- Hooks: Provided by plugin (no manual installation needed)
- Agents: available via the plugin's agents/ directory

Note: Hooks are managed by the plugin system automatically. No manual hook installation required.
```

## Early Exit for Flag Mode

If `--local` or `--global` flag was used, **STOP HERE** after reporting success.
Do not continue to Phase 2 or other phases.
