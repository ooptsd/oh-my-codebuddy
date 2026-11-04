# Marketplace 重命名设计：omb-plugins → omc-plugins

日期：2026-11-05
状态：已确认（用户批准两部分设计）

## 背景

插件本体已从 `omb` 改名为 `omc`（插件名、命令命名空间 `omc:`、状态目录 `.omc/`），
但 marketplace 名称仍为 `omb-plugins`，导致安装缓存路径为
`~/.codebuddy/plugins/cache/omb-plugins/omc/<version>/`，命名不一致。
同时 hook 消息前缀仍用 `[OMB ...]`，与 `omc` 品牌不符。

## 改动范围

1. **市场名**：`.codebuddy-plugin/marketplace.json` 的 `name` 从 `omb-plugins` 改为 `omc-plugins`。
2. **脚本路径**（`scripts/session-start.mjs`）：
   - `getPluginCacheBase()` 优先返回 `plugins/cache/omc-plugins/omc`，旧路径
     `plugins/cache/omb-plugins/omc` 作为回退（兼容未迁移的存量会话）。
   - `isManagedPluginCacheRoot()` 同时接受两种缓存根，路径正则改为
     `/\/plugins\/cache\/(omb-plugins|omc-plugins)\/omc\/…/`。
   - `getMarketplaceCloneVersion()` 优先读 `plugins/marketplaces/omc-plugins`，
     回退 `omb-plugins`。
   - HUD 检查与缓存 GC 复用 `getPluginCacheBase()`，不再各自硬编码。
3. **用户提示文案**（`session-start.mjs` 4 处）：更新/安装命令统一为
   `omc-plugins`（如 `/plugin marketplace update omc-plugins`、`/plugin install omc@omc-plugins`）。
4. **消息前缀**：`[OMB ...]` → `[OMC ...]`（session-start.mjs 2 处、
   context-guard-stop.mjs 1 处、post-tool-verifier.mjs 2 处）。前缀仅为展示标记，无解析依赖。
5. **README.md**：路径示例、安装命令改为 `omc-plugins`；迁移章节补写
   市场名变更的一次性迁移步骤（重新 add marketplace + 重装 + 手动清理旧缓存）。

## 不改

- `plugin.json`（插件名 `omc` 不变）
- `.omc/` 状态目录、`verify.sh`、skills/agents/commands 内容
- 版本号（重发插件属 maintainer 发布动作，另行处理）

## 迁移策略（存量用户）

- 市场名无别名机制，属一次性硬切换。
- 新代码通过双路径回退识别旧缓存，保证未迁移会话的版本漂移检测继续工作。
- README 指引：`/plugin marketplace add ooptsd/oh-my-codebuddy` →
  `/plugin install omc@omc-plugins`，并手动删除 `~/.codebuddy/plugins/cache/omb-plugins/`
  与旧 marketplace 目录。

## 验证

- `bash verify.sh` 全绿
- `node --check` 所有改动脚本
- 全仓 grep 确认无遗漏的 `omb-plugins` 引用（README 迁移说明与脚本回退路径除外）
