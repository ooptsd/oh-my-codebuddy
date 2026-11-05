import { homedir } from 'node:os';
import { join, normalize, parse, sep } from 'node:path';

function stripTrailingSep(p) {
  if (!p.endsWith(sep)) {
    return p;
  }

  return p === parse(p).root ? p : p.slice(0, -1);
}

// Host CLI is CodeBuddy. Resolution order:
//   1) CODEBUDDY_CONFIG_DIR (explicit override)
//   2) ~/.codebuddy default (homedir()-based, platform-adaptive)
function resolveConfiguredDir() {
  const value = process.env.CODEBUDDY_CONFIG_DIR?.trim();
  return value || '';
}

export function getConfigDir() {
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
  return join(getConfigDir(), '.omc');
}

export function getUpdateCheckCachePath() {
  return join(getOmcConfigDir(), 'update-check.json');
}
