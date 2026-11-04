const { homedir } = require('node:os');
const { join, normalize, parse, sep } = require('node:path');

function stripTrailingSep(p) {
  if (!p.endsWith(sep)) {
    return p;
  }

  return p === parse(p).root ? p : p.slice(0, -1);
}

// omc adaptation: host CLI is CodeBuddy. Resolution order:
//   1) CODEBUDDY_CONFIG_DIR (CodeBuddy-native)
//   2) CLAUDE_CONFIG_DIR (legacy/Claude Code compat)
//   3) ~/.codebuddy default
function resolveConfiguredDir() {
  for (const name of ['CODEBUDDY_CONFIG_DIR', 'CLAUDE_CONFIG_DIR']) {
    const value = process.env[name]?.trim();
    if (value) return value;
  }
  return '';
}

function getClaudeConfigDir() {
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

function getOmcConfigDir() {
  return join(getClaudeConfigDir(), '.omc');
}

function getUpdateCheckCachePath() {
  return join(getOmcConfigDir(), 'update-check.json');
}

module.exports = { getClaudeConfigDir, getOmcConfigDir, getUpdateCheckCachePath };
