---
description: ""
---

# omc trace

This compatibility command keeps `/omc:trace` available without loading the full `trace` skill description in every CodeBuddy session.

## Dispatch

1. Read the full bundled skill instructions from the active omc plugin/install: `skills/trace/SKILL.md`.
2. Follow that SKILL.md exactly, treating the user's arguments as:

```text
$ARGUMENTS
```

If the file is not directly readable from the current working directory, locate it under the active `CODEBUDDY_PLUGIN_ROOT`/`OMC_PLUGIN_ROOT`, package root, or installed omc plugin directory, then continue.
