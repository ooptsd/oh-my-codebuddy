/**
 * CodeBuddy Configuration Directory Resolution (dist port)
 *
 * Port note (oh-my-codebuddy): the upstream reads CLAUDE_CONFIG_DIR with a
 * ~/.claude fallback. This port follows the repo convention — env is
 * CODEBUDDY_CONFIG_DIR only (no CLAUDE_* fallback), default ~/.codebuddy.
 * Mirrors scripts/lib/config-dir.mjs.
 */
import { join, normalize, parse, sep } from 'path';
import { homedir } from 'os';
/**
 * Strip a single trailing path separator (preserve filesystem root).
 * @internal Shared with scripts/lib/config-dir.{mjs,cjs,sh} — keep in sync.
 */
function stripTrailingSep(p) {
    if (!p.endsWith(sep)) {
        return p;
    }
    return p === parse(p).root ? p : p.slice(0, -1);
}
/**
 * Resolve the CodeBuddy configuration directory (kept under the upstream
 * export name; wiki session-hooks imports this symbol).
 *
 * Honours CODEBUDDY_CONFIG_DIR (absolute path, or ~-prefixed) with fallback
 * to ~/.codebuddy.  Trailing separators are stripped; filesystem roots are
 * preserved.
 */
export function getClaudeConfigDir() {
    const home = homedir();
    const configured = process.env.CODEBUDDY_CONFIG_DIR?.trim();
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
/**
 * Resolve the OMC global configuration/cache directory under the active
 * CodeBuddy config dir. Keeps hook/updater/HUD caches aligned with
 * CODEBUDDY_CONFIG_DIR.
 */
export function getOmcConfigDir() {
    return join(getClaudeConfigDir(), '.omc');
}
/** Resolve the canonical update-check cache file path. */
export function getUpdateCheckCachePath() {
    return join(getOmcConfigDir(), 'update-check.json');
}