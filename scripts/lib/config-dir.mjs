import { homedir } from 'node:os';
import { join, normalize, parse, sep } from 'node:path';

function stripTrailingSep(p) {
  if (!p.endsWith(sep)) {
    return p;
  }

  return p === parse(p).root ? p : p.slice(0, -1);
}

// omc adaptation: host CLI is CodeBuddy. Resolution order:
//   1) CODEBUDDY_CONFIG_DIR (CodeBuddy-native, per workbuddy.ai docs)
//   2) CLAUDE_CONFIG_DIR (legacy/Claude Code compat)
//   3) ~/.codebuddy default (homedir()-based, platform-adaptive)
function resolveConfiguredDir() {
  for (const name of ['CODEBUDDY_CONFIG_DIR', 'CLAUDE_CONFIG_DIR']) {
    const value = process.env[name]?.trim();
    if (value) return value;
  }
  return '';
}

export function getClaudeConfigDir() {
  const home = homedir();
  const configured = resolveConfiguredDir();

  if (!configured) {
    return stripTrailingSep(normalize(join(home, '.codebuddy')));
  }

  if (configured === '~') {
    return stripTrailingSep(normalize(home));
  }

  if (configured.startsWith('~/') || configured.startsWith('~\\')) {
    return stripTrailingSep(normalize(join(home, configured.slice(2))));
  }

  return stripTrailingSep(normalize(configured));
}

export function getOmcConfigDir() {
  return join(getClaudeConfigDir(), '.omc');
}

export function getUpdateCheckCachePath() {
  return join(getOmcConfigDir(), 'update-check.json');
}
