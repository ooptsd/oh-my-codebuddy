---
name: omc-doctor
description: Diagnose and fix oh-my-codebuddy (omc) installation issues on CodeBuddy
level: 3
---

# Doctor Skill

Note: All `~/.codebuddy/...` paths in this guide respect `CODEBUDDY_CONFIG_DIR` when that environment variable is set

## Task: Run Installation Diagnostics

You are the omc Doctor - diagnose and fix installation issues.

### Step 1: Check Plugin Version

```bash
# Get installed and latest versions (cross-platform)
node -e "const p=require('path'),f=require('fs'),h=require('os').homedir(),d=process.env.CODEBUDDY_CONFIG_DIR||p.join(h,'.codebuddy'),b=p.join(d,'plugins','cache','omc-plugins','omc');try{const v=f.readdirSync(b).filter(x=>/^\d/.test(x)).sort((a,c)=>a.localeCompare(c,void 0,{numeric:true}));console.log('Installed:',v.length?v[v.length-1]:'(none)')}catch{console.log('Installed: (none)')}"
npm view oh-my-claude-sisyphus version 2>/dev/null || echo "Latest: (unavailable)"
```

**Diagnosis**:
- If no version installed: CRITICAL - plugin not installed
- If INSTALLED != LATEST: WARN - outdated plugin
- If multiple versions exist: WARN - stale cache

### Step 2: Check for Legacy Hooks in settings.json

Read both `${CODEBUDDY_CONFIG_DIR:-~/.codebuddy}/settings.json` (profile-level) and `./.codebuddy/settings.json` (project-level) and check if there's a `"hooks"` key with entries like:
- `bash ${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}/hooks/keyword-detector.sh`
- `bash ${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}/hooks/persistent-mode.sh`
- `bash ${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}/hooks/session-start.sh`

**Diagnosis**:
- If found: CRITICAL - legacy hooks causing duplicates

### Step 3: Check for Legacy Bash Hook Scripts

```bash
ls -la "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/hooks/*.sh 2>/dev/null
```

**Diagnosis**:
- If `keyword-detector.sh`, `persistent-mode.sh`, `session-start.sh`, or `stop-continuation.sh` exist: WARN - legacy scripts (can cause confusion)

### Step 4: Check CODEBUDDY.md

```bash
# Check if CODEBUDDY.md exists (root-level CODEBUDDY.md is also valid for projects)
ls -la "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/CODEBUDDY.md 2>/dev/null

# Check for omc markers (<!-- OMC:START --> is the canonical marker)
grep -q "<!-- OMC:START -->" "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}/CODEBUDDY.md" 2>/dev/null && echo "Has omc config" || echo "Missing omc config in CODEBUDDY.md"

# Check memory-file version marker and compare with latest installed plugin cache version
node -e "const p=require('path'),f=require('fs'),h=require('os').homedir(),d=process.env.CODEBUDDY_CONFIG_DIR||p.join(h,'.codebuddy');const base=p.join(d,'CODEBUDDY.md');let memV='(missing)';let memSource='(none)';try{const c=f.readFileSync(base,'utf8');const m=c.match(/<!--\s*OMC:VERSION:([^\s]+)\s*-->/i);if(m){memV=m[1];memSource=base}}catch{};let pluginV='(none)';try{const b=p.join(d,'plugins','cache','omc-plugins','omc');const v=f.readdirSync(b).filter(x=>/^\d/.test(x)).sort((a,c)=>a.localeCompare(c,void 0,{numeric:true}));pluginV=v.length?v[v.length-1]:'(none)';}catch{};console.log('CODEBUDDY.md omc version:',memV);console.log('omc version source:',memSource);console.log('Latest cached plugin version:',pluginV);if(memV==='(missing)'){console.log('VERSION CHECK SKIPPED: memory file or marker missing')}else if(pluginV==='(none)'){console.log('VERSION CHECK SKIPPED: plugin cache missing')}else if(memV===pluginV){console.log('VERSION MATCH: memory file and plugin cache are aligned')}else{console.log('VERSION DRIFT: CODEBUDDY.md and plugin versions differ')}"
```

**Diagnosis**:
- If CODEBUDDY.md missing: CRITICAL - memory file not configured
- If `<!-- OMC:START -->` found in CODEBUDDY.md: OK
- If no omc markers in CODEBUDDY.md: WARN - outdated CODEBUDDY.md
- If `CODEBUDDY.md omc version` != `Latest cached plugin version`: WARN - version drift detected (run `/omc:omc-setup`)

### Step 5: Check Ralph Runtime Prerequisites

Ralph is an agent-driven persistence loop, not a compiled program: its only hard runtime prerequisites are the Node runtime that executes omc's hook scripts (`persistent-mode.mjs`, `keyword-detector.mjs`) and a writable config directory for `.omcb/state/` state files such as `ralph-state.json`.

```bash
node --version || echo "Node for Ralph: MISSING"
mkdir -p "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}" 2>/dev/null
touch "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}/.omc-write-probe" 2>/dev/null && rm -f "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}/.omc-write-probe" && echo "Config dir writable" || echo "Config dir NOT writable"
```

**Diagnosis**:
- If Node runs and prints a version: OK - Ralph runtime prerequisite present
- If `node` is missing or fails: CRITICAL - omc hooks and Ralph cannot run without Node (see https://nodejs.org for installers; nvm/fnm users need Node on the PATH of non-interactive shells)
- If the config dir is not writable: WARN - Ralph state persistence will fail until it is writable

### Step 6: Check for Stale Plugin Cache

```bash
# Count versions in cache (cross-platform)
node -e "const p=require('path'),f=require('fs'),h=require('os').homedir(),d=process.env.CODEBUDDY_CONFIG_DIR||p.join(h,'.codebuddy'),b=p.join(d,'plugins','cache','omc-plugins','omc');try{const v=f.readdirSync(b).filter(x=>/^\d/.test(x));console.log(v.length+' version(s):',v.join(', '))}catch{console.log('0 versions')}"
```

**Diagnosis**:
- If > 1 version: WARN - multiple cached versions (cleanup recommended)

### Step 7: Check for Legacy Curl-Installed Content

Check for legacy agents, commands, and skills installed via curl (before plugin system).
**Important**: Only flag files whose names match actual plugin-provided names. Do NOT flag user's custom agents/commands/skills that are unrelated to OMC.

```bash
# Check for legacy agents directory
ls -la "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/agents/ 2>/dev/null

# Check for legacy commands directory
ls -la "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/commands/ 2>/dev/null

# Check for legacy skills directory
ls -la "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/skills/ 2>/dev/null
```

**Diagnosis**:
- If `~/.codebuddy/agents/` exists with files matching plugin agent names: WARN - legacy agents (now provided by plugin)
- If `~/.codebuddy/commands/` exists with files matching plugin command names: WARN - legacy commands (now provided by plugin)
- If `~/.codebuddy/skills/` exists with files matching plugin skill names: WARN - legacy skills (now provided by plugin)
- If custom files exist that do NOT match plugin names: OK - these are user custom content, do not flag them

**Known plugin agent names** (check agents/ for these):
`architect.md`, `document-specialist.md`, `explore.md`, `executor.md`, `debugger.md`, `planner.md`, `analyst.md`, `critic.md`, `verifier.md`, `test-engineer.md`, `designer.md`, `writer.md`, `qa-tester.md`, `scientist.md`, `security-reviewer.md`, `code-reviewer.md`, `git-master.md`, `code-simplifier.md`

**Known plugin skill names** (check skills/ for these):
`ai-slop-cleaner`, `ask`, `autopilot`, `cancel`, `configure-notifications`, `deep-interview`, `deepinit`, `external-context`, `hud`, `omc-doctor`, `omc-setup`, `plan`, `project-session-manager`, `ralph`, `ralplan`, `release`, `skill`, `team`, `visual-verdict`, `wiki`

**Known plugin command names** (check commands/ for these):
`deepsearch.md`

---

## Report Format

After running all checks, output a report:

```
## omc Doctor Report

### Summary
[HEALTHY / ISSUES FOUND]

### Checks

| Check | Status | Details |
|-------|--------|---------|
| Plugin Version | OK/WARN/CRITICAL | ... |
| Legacy Hooks (settings.json) | OK/CRITICAL | ... |
| Legacy Scripts (~/.codebuddy/hooks/) | OK/WARN | ... |
| CODEBUDDY.md | OK/WARN/CRITICAL | ... |
| Ralph Runtime Prerequisites (Node, config dir) | OK/CRITICAL | ... |
| Plugin Cache | OK/WARN | ... |
| Legacy Agents (~/.codebuddy/agents/) | OK/WARN | ... |
| Legacy Commands (~/.codebuddy/commands/) | OK/WARN | ... |
| Legacy Skills (~/.codebuddy/skills/) | OK/WARN | ... |

### Issues Found
1. [Issue description]
2. [Issue description]

### Recommended Fixes
[List fixes based on issues]
```

---

## Auto-Fix (if user confirms)

If issues found, ask user: "Would you like me to fix these issues automatically?"

If yes, apply fixes:

### Fix: Legacy Hooks in settings.json
Remove the `"hooks"` section from `${CODEBUDDY_CONFIG_DIR:-~/.codebuddy}/settings.json` (keep other settings intact)

### Fix: Legacy Bash Scripts
```bash
rm -f "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/hooks/keyword-detector.sh
rm -f "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/hooks/persistent-mode.sh
rm -f "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/hooks/session-start.sh
rm -f "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/hooks/stop-continuation.sh
```

### Fix: Outdated Plugin
```bash
# Clear plugin cache (cross-platform)
node -e "const p=require('path'),f=require('fs'),d=process.env.CODEBUDDY_CONFIG_DIR||p.join(require('os').homedir(),'.codebuddy'),b=p.join(d,'plugins','cache','omc-plugins','omc');try{f.rmSync(b,{recursive:true,force:true});console.log('Plugin cache cleared. Restart CodeBuddy and reinstall omc to fetch the latest version.')}catch{console.log('No plugin cache found')}"
```

### Fix: Stale Cache (multiple versions)
```bash
# Keep only latest version (cross-platform)
node -e "const p=require('path'),f=require('fs'),h=require('os').homedir(),d=process.env.CODEBUDDY_CONFIG_DIR||p.join(h,'.codebuddy'),b=p.join(d,'plugins','cache','omc-plugins','omc');try{const v=f.readdirSync(b).filter(x=>/^\d/.test(x)).sort((a,c)=>a.localeCompare(c,void 0,{numeric:true}));v.slice(0,-1).forEach(x=>f.rmSync(p.join(b,x),{recursive:true,force:true}));console.log('Removed',v.length-1,'old version(s)')}catch(e){console.log('No cache to clean')}"
```

### Fix: Missing/Outdated CODEBUDDY.md
Run `/omc:omc-setup` to reinstall the canonical memory file through the plugin coordinator (never hand-write or download it in the shell).

### Fix: Legacy Curl-Installed Content

Remove legacy agents, commands, and skills directories (now provided by plugin):

```bash
# Backup first (optional - ask user)
# mv "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/agents "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/agents.bak
# mv "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/commands "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/commands.bak
# mv "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/skills "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/skills.bak

# Or remove directly
rm -rf "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/agents
rm -rf "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/commands
rm -rf "${CODEBUDDY_CONFIG_DIR:-$HOME/.codebuddy}"/skills
```

**Note**: Only remove if these contain oh-my-codebuddy-related files. If user has custom agents/commands/skills, warn them and ask before removing.

---

## Post-Fix

After applying fixes, inform user:
> Fixes applied. **Restart CodeBuddy** for changes to take effect.
