---
description: ""
---

# omc deepinit

This compatibility command keeps `/omc:deepinit` available without loading the full `deepinit` skill description in every Claude Code session.

## Dispatch

1. Read the full bundled skill instructions from the active omc plugin/install: `skills/deepinit/SKILL.md`.
2. Follow that SKILL.md exactly, treating the user's arguments as:

```text
$ARGUMENTS
```

If the file is not directly readable from the current working directory, locate it under the active `CLAUDE_PLUGIN_ROOT`/`OMC_PLUGIN_ROOT`, package root, or installed omc plugin directory, then continue.
