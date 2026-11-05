const { homedir } = require('node:os');
const { join, normalize, parse, sep } = require('node:path');

function stripTrailingSep(p) {
  if (!p.endsWith(sep)) {
    return p;
  }

  return p === parse(p).root ? p : p.slice(0, -1);
}

// Host CLI is CodeBuddy. Resolution order:
//   1) CODEBUDDY_CONFIG_DIR (explicit override)
//   2) ~/.codebuddy default
function resolveConfiguredDir() {
  const value = process.env.CODEBUDDY_CONFIG_DIR?.trim();
  return value || '';
}

function getConfigDir() {
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
  return join(getConfigDir(), '.omc');
}

function getUpdateCheckCachePath() {
  return join(getOmcConfigDir(), 'update-check.json');
}

module.exports = { getConfigDir, getOmcConfigDir, getUpdateCheckCachePath };
