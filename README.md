# omc (Oh My Buddy) — CodeBuddy 插件版

> 为 AI 编程代理提供多代理编排能力。本插件是 [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) 的 CodeBuddy 适配发行版。
>
> **版本：** 5.4.2 · **插件名：** `omc` · **市场源：** `omc-plugins`（调用命名空间：`omc:`）

本插件把 omc 的 skills、commands、subagents、hooks 打包成 CodeBuddy 可直接加载的格式。**不包含 omc 的 MCP 服务器** —— 其含义与替代方案见 [限制与迁移指南](#限制与迁移指南)。

---

## 插件内容

| 组件 | 数量 | 来源位置 |
|------|-----:|---------|
| Skills | 39 | `skills/<name>/SKILL.md` |
| Slash commands | 21 | `commands/*.md` |
| Subagents | 19 | `agents/*.md` |
| Hooks | **11 个事件、25 条命令** | `hooks/hooks.json`（事件列表见下） |
| MCP 服务器 | — | **已排除**（见迁移指南） |

### 触发的事件与脚本

| 事件 | 匹配规则 | 脚本 |
|------|---------|------|
| `UserPromptSubmit` | `*` | `keyword-detector`、`skill-injector` |
| `SessionStart` | `*` | `session-start`、`project-memory-session`、`wiki-session-start` |
| `SessionStart` | `init` | `setup-init` |
| `SessionStart` | `maintenance`¹ | `setup-maintenance` |
| `PreToolUse` | `*` | `pre-tool-enforcer` |
| `PermissionRequest` | `Bash` | `permission-handler` |
| `PostToolUse` | `*` | `post-tool-verifier`、`project-memory-posttool`、`post-tool-rules-injector` |
| `PostToolUseFailure` | `*` | `post-tool-use-failure` |
| `SubagentStart` | `*` | `subagent-tracker.mjs start` |
| `SubagentStop` | `*` | `subagent-tracker.mjs stop`、`verify-deliverables` |
| `PreCompact` | `*` | `pre-compact`、`project-memory-precompact`、`wiki-pre-compact` |
| `Stop` | `*` | `context-guard-stop`、`workflow-drift-guard`、`persistent-mode`、`code-simplifier` |
| `SessionEnd` | `*` | `session-end`（异步）、`wiki-session-end`（异步） |

> ¹ `maintenance` 匹配规则是 **死代码**（参见 spec §4.3）：`maintenance` 既不在 CodeBuddy 也不在 Claude Code 的标准 `SessionStart` source 列表（标准是 `startup`、`resume`、`clear`、`compact`）中，因此这条匹配规则在两个运行时里都从未触发过。保留它只是为了与上游 omc 的 hook 契约保持一致。

合计 **11 个事件 / 25 条命令**，与上游 oh-my-claudecode 完全一致。

---

## 功能对照表：CodeBuddy omc vs Claude Code OMC

用本表判断 CodeBuddy 版是否满足需求。

### 主要功能对齐

| 维度 | Claude Code OMC | CodeBuddy omc（本发行版） | 说明 |
|------|---------------:|--------------------------:|------|
| 通过 `$name` 加载的 Skills | 39 / 39 | 39 / 39 | 内容完全一致；frontmatter schema 相同 |
| 通过 `/name` 加载的 Commands | 21 / 21 | 21 / 21 | 内容完全一致 |
| 通过 `@name` 加载的 Subagents | 19 / 19 | 19 / 19 | 同一份 `agents/*.md` |
| `marketplace.json` 格式 | Claude Code schema | 同 schema | 两个运行时都接受同一 marketplace 格式 |
| `plugin.json` 位置 | `.claude-plugin/plugin.json` | `.codebuddy-plugin/plugin.json` | CodeBuddy 优先查找 `.codebuddy-plugin/`，再查找 `.claude-plugin/` |
| Hook stdin/stdout 协议 | JSON 入参，JSON 出参 | 同 | 遵循同一份 hook 契约 |
| `${CODEBUDDY_PLUGIN_ROOT}` 替换 | ✅（注入 `${CLAUDE_PLUGIN_ROOT}`） | ✅（注入 `${CODEBUDDY_PLUGIN_ROOT}`） | `${CODEBUDDY_PLUGIN_ROOT}` 为权威环境变量，`hooks/hooks.json` 全部使用该引用；本插件自 v5.4.3 起不再读取 `${CLAUDE_PLUGIN_ROOT}` 兼容别名 |
| `.omc/` 磁盘状态文件 | ✅ | ✅ | 同路径、同 JSON 结构；skill 直接读取 |
| `package.json` / `npm`（hook 脚本） | 必需 | 无要求 | 本发行版 hook 脚本全部用纯 Node + stdin/stdout；唯一可选原生模块（`better-sqlite3`）在已安装时被兼容 |

### Hook 事件

| 事件 | Claude Code OMC | CodeBuddy omc | ZCode omz（裁剪版） | 功能差异 |
|------|:--------------:|:-------------:|:-------------------:|---------|
| `UserPromptSubmit` | ✅ 触发 | ✅ 触发 | ✅ 触发 | 无 |
| `SessionStart`（`startup` / `resume` / `clear` / `compact`） | ✅ 触发 | ✅ 触发 | ✅ 触发 | 无 |
| `SessionStart`（`init`） | ✅ 触发 | ✅ 触发 | ⚠️ 几乎不会触发 | CodeBuddy 与 Claude Code 一样识别 `init`；ZCode 标准 source 不含 `init`，因此那条匹配规则在那里不会自动触发（保留它仅是为对齐 hook 契约） |
| `SessionStart`（`maintenance`）¹ | ❌ 不触发 | ❌ 不触发 | ❌ 不触发 | 死代码；保留只为对齐上游 |
| `PreToolUse` | ✅ 触发 | ✅ 触发 | ✅ 触发 | 无 |
| `PermissionRequest` | ✅ 触发 | ✅ 触发 | ✅ 触发 | 无 |
| `PostToolUse` | ✅ 触发 | ✅ 触发 | ✅ 触发 | 无 |
| `PostToolUseFailure` | ✅ 触发 | ✅ 触发 | ✅ 触发 | 无 |
| `Stop` | ✅ 触发 | ✅ 触发 | ✅ 触发 | 无 |
| `SubagentStart` | ✅ 触发 | ✅ 触发 | ❌ 已移除 | CodeBuddy omc 完整保留 `subagent-tracker.mjs` 启动日志 |
| `SubagentStop` | ✅ 触发 | ✅ 触发 | ❌ 已移除 | CodeBuddy omc 完整保留 `verify-deliverables.mjs`（交付物校验） |
| `PreCompact` | ✅ 触发 | ✅ 触发 | ❌ 已移除 | CodeBuddy omc 完整保留压缩前快照（3 个脚本） |
| `SessionEnd` | ✅ 触发 | ✅ 触发 | ❌ 已移除 | CodeBuddy omc 完整保留会话结束异步清理（2 个脚本） |

> ¹ `maintenance` 匹配规则按 spec §4.3 在 README 中标注为 **dead code documented in README**。两个运行时都不识别 `maintenance`，所以这条规则 **从未触发**；保留它是为了让本插件的 `hooks/hooks.json` 与上游 oh-my-claudecode 完全一致。
>
> **CodeBuddy omc 的关键优势**：11 个 hook 事件 **全部保留**，无需任何手动补偿。ZCode omz 因为裁剪掉了 4 个事件，需要为 `verify-deliverables.mjs`、压缩快照、会话清理添加手动替代路径（参见 oh-my-zcode README）。

---

## Hook 事件覆盖表

| # | 事件 | 状态 | 主要用途 |
|--:|------|:----:|---------|
| 1 | `UserPromptSubmit` | ✅ | 关键词检测、skill 自动注入 |
| 2 | `SessionStart`（`startup` / `resume` / `clear` / `compact`） | ✅ | 加载会话状态、项目记忆、wiki |
| 3 | `SessionStart`（`init`） | ✅ | 调用 `setup-init.mjs`（与 Claude Code 对齐） |
| 4 | `SessionStart`（`maintenance`） | ⚠️ 死代码 | 匹配规则保留仅为对齐契约 |
| 5 | `PreToolUse` | ✅ | 工具调用前的强制 / 改写 |
| 6 | `PermissionRequest`（`Bash`） | ✅ | Bash 权限门禁 |
| 7 | `PostToolUse` | ✅ | 工具结果校验、项目记忆写入、规则注入 |
| 8 | `PostToolUseFailure` | ✅ | 失败恢复提示 |
| 9 | `SubagentStart` | ✅ | 子代理启动追踪 |
| 10 | `SubagentStop` | ✅ | 子代理停止 + 交付物校验 |
| 11 | `PreCompact` | ✅ | 上下文压缩前快照（3 个脚本） |
| 12 | `Stop` | ✅ | 上下文守卫、漂移守卫、persistent mode、code simplifier |
| 13 | `SessionEnd` | ✅ | 会话结束异步清理（2 个脚本） |

合计 **13 行 / 11 个真正可触发的事件**（`maintenance` 单独列出但不会触发）。

---

## 限制与迁移指南

### 1. MCP 服务器（`bridge/mcp-server.cjs`）—— 已排除

MCP 服务器按用途分组暴露以下工具，全部在本插件中不可用。

| 分类 | 工具 | 用途 | 迁移 |
|------|------|------|------|
| **State** | `state_write`、`state_read`、`state_list_active`、`state_get_status`、`state_clear`、`state_migrate_non_git` | 每个项目的工作流状态（`.omc/state/`） | 状态文件仍在磁盘上。读取它们的 skill（如 `plan`、`execute`）回退到直接用 `Read` 工具读文件，不需要 MCP |
| **项目记忆** | `project_memory_write`、`project_memory_read`、`project_memory_add_note`、`project_memory_add_directive` | 持久化项目上下文（`.omc/project-memory.json`） | 直接用 `Read` / `Edit` / `Write` 操作 `.omc/project-memory.json`，或调用 **`remember`** skill（封装相同逻辑） |
| **记事本** | `notepad_write_working`、`notepad_write_priority`、`notepad_write_manual`、`notepad_read`、`notepad_stats`、`notepad_prune` | 工作中的会话笔记（`.omc/notepad.md`） | 调用 **`remember`** skill 或直接读写 `.omc/notepad.md`。`persistent-mode.mjs` Stop hook 已在会话结束时自动持久化记事本 |
| **共享记忆** | `shared_memory_write`、`shared_memory_read`、`shared_memory_list`、`shared_memory_delete`、`shared_memory_cleanup` | 跨会话、跨项目的知识库 | 直接读写 `.omc/shared-memory/` 下的文件。`wiki` skill 提供类似能力，结构更严谨 |
| **Wiki** | `wiki_ingest`、`wiki_read`、`wiki_query`、`wiki_add`、`wiki_delete`、`wiki_list`、`wiki_lint` | 结构化知识图谱 | 直接调用 **`wiki`** skill（聊天中 `$wiki`），所有 wiki 操作都以文件编辑形式封装 |
| **LSP** | `lsp_servers`、`lsp_diagnostics`、`lsp_diagnostics_directory`、`lsp_hover`、`lsp_goto_definition`、`lsp_find_references`、`lsp_document_symbols`、`lsp_workspace_symbols`、`lsp_code_actions`、`lsp_code_action_resolve`、`lsp_prepare_rename`、`lsp_rename` | 代码智能 | **使用 CodeBuddy 内置的 `Read` / `Grep` / `Glob` 工具** 已覆盖大部分导航需求。重构 / 重命名依靠编辑器原生 LSP 或 CodeBuddy 的 `Edit` 工具 |
| **AST grep** | `ast_grep_search`、`ast_grep_replace` | 结构化代码搜索/替换 | 用 **`Grep`** + 正则即可。编排工作流中很少需要 AST 级精度 |
| **Python REPL** | `python_repl` | 进程内执行 Python | 用 **`Bash`** + `python3 -c '...'` 或写入临时文件 |
| **追踪 (Trace)** | `trace_summary`、`trace_timeline` | 查看历史会话的执行追踪 | 直接用 `Read` 读追踪文件（`.omc/traces/`） |
| **会话检索** | `session_search` | 跨会话搜索 | `Bash` + `grep -r` 检索本地 transcripts 目录 |
| **oh-my-claudecode skills 加载器** | `list_omc_skills`、`load_omc_skills_global`、`load_omc_skills_local` | 发现可用的 oh-my-claudecode skills | CodeBuddy 中通过 `$skill-name` 直接调用 skill，无需枚举工具 |
| **Deepinit manifest** | `deepinit_manifest` | 生成项目初始化清单 | 调用 **`deepinit`** skill（`$deepinit`），效果相同 |
| **Merge readiness** | `merge_readiness_start`、`merge_readiness_report`、`merge_readiness_set_content`、`merge_readiness_record_answer`、`merge_readiness_cancel` | 多方合并 Q&A 工作流 | 使用 **`review`** skill，它以手动编排方式覆盖相同工作流 |

#### ZCode omz 与 CodeBuddy omc 的实现差异

- **ZCode omz**：由于裁剪掉 `SubagentStart` / `SubagentStop` / `PreCompact` / `SessionEnd`，丢失了 `verify-deliverables.mjs`、3 个压缩快照脚本、2 个会话结束脚本。需要在用户配置里手动加 `PostToolUse` 钩子来补齐 `verify-deliverables`；用 `$remember` skill 替代 `SessionEnd` 持久化。
- **CodeBuddy omc**：**保留全部 11 个事件**。`verify-deliverables.mjs` 在每次 `SubagentStop` 时自动校验交付物；`pre-compact.mjs` / `project-memory-precompact.mjs` / `wiki-pre-compact.mjs` 在压缩前自动快照；`session-end.mjs` / `wiki-session-end.mjs` 在会话结束时异步清理。**不需要任何手动补偿**。

**经验法则**：如果某个 Claude Code 调用本来会调用 oh-my-claudecode MCP 工具，在 CodeBuddy 中改为调用对应的 `skills/<name>/SKILL.md` 或直接读写底层文件。Skills（39 个）才是主要入口；MCP 服务器只是一层便利封装。

### 2. `maintenance` 匹配规则 —— 死代码（spec §4.3）

omc 在 `SessionStart` 里定义了一个调用 `setup-maintenance.mjs` 的 `maintenance` 匹配规则。CodeBuddy 与 Claude Code 都没有把 `maintenance` 列为标准会话 source（标准是 `startup`、`resume`、`clear`、`compact`），所以这条匹配规则 **在两个运行时里都从未触发**。它被刻意保留以保持与上游 omc 的 hook 契约一致。

**迁移：** 如果你以前用过 omc 的 `/omc-setup maintenance` 工作流，改用 `$omc-setup` skill 配以相应子命令手动调用。

### 3. CodeBuddy 插件缓存布局（spec §6.7 item 3）

从 marketplace 安装（方式 B）后，CodeBuddy 把插件快照克隆到本地缓存路径：

```text
~/.codebuddy/plugins/cache/omc-plugins/omc/5.4.2/
```

- 缓存根：`~/.codebuddy/plugins/cache/`
- marketplace 目录：`omc-plugins/`（对应 `marketplace.json` 里的 name）
- 插件目录：`omc/5.4.2/`（`omc` 是插件名，也是调用命名空间前缀，`5.4.2` 是当前版本）

**读取 cache 中的文件来定位插件根目录**：

```bash
# 列缓存里的 hooks 文件
ls ~/.codebuddy/plugins/cache/omc-plugins/omc/5.4.2/hooks/hooks.json

# 读取插件清单（验证安装版本）
cat ~/.codebuddy/plugins/cache/omc-plugins/omc/5.4.2/.codebuddy-plugin/plugin.json
```

**手动清理缓存**：删除上述目录后执行 `/reload-plugins` 即可让 CodeBuddy 在下次加载时重新克隆。

**版本升级**：CodeBuddy 不会原地覆盖旧版本；新版本会以 `5.5.0/` 这样的新子目录并列存在。`/reload-plugins` 后两个版本都会加载，建议卸载旧版本以避免重复命令。

**从旧插件名 `omb` 升级到 `omc`**：两者会被 CodeBuddy 视为不同插件，旧缓存 `~/.codebuddy/plugins/cache/omb-plugins/omb/` 不会自动清理。请先执行 `/plugin uninstall omb`（或手动删除该缓存目录及 plugins 索引中的 `omb` 条目），再安装 `omc@omc-plugins`，否则旧 hooks 会重复加载。

**从旧市场名 `omb-plugins` 迁移到 `omc-plugins`**：marketplace 改名后，旧市场注册与缓存不会被自动迁移。请先执行 `/plugin uninstall omc` 与移除旧市场（或手动删除 `~/.codebuddy/plugins/marketplaces/omb-plugins/` 与 `~/.codebuddy/plugins/cache/omb-plugins/`），再重新 `/plugin marketplace add ooptsd/oh-my-codebuddy` 并安装 `omc@omc-plugins`。

**从源码运行（方式 A）时不走该缓存**：`codebuddy --plugin-dir ./oh-my-codebuddy` 直接读取工作区，零缓存命中，方便调试。

---

## 持久化文件（`.omc/` 目录）

两个发行版（Claude Code oh-my-claudecode 和 CodeBuddy omc）写入相同的磁盘位置。区别在于**写入方式**：在 Claude Code oh-my-claudecode 中，hook 与 MCP 工具完成写入；在 CodeBuddy omc 中，hook 完成全部写入（因为保留了全部 11 个事件），MCP 触发的写入需要替换为 skill 调用或直接文件编辑。

| 路径 | 用途 | CodeBuddy omc 下的读写方式 |
|------|------|--------------------------|
| `.omc/state/*.json` | 每个项目的工作流状态 | `Read` / `Edit` / `Write` 工具，或由 hook 驱动 |
| `.omc/project-memory.json` | 持久化的项目上下文 | 同上；`project-memory-session.mjs` / `project-memory-posttool.mjs` 自动写入 |
| `.omc/notepad.md` | 工作中的会话笔记 | 同上；`persistent-mode.mjs` Stop hook 会自动持久化 |
| `.omc/wiki/` | 结构化知识图谱 | 任何变更都通过 `$wiki` 调用；`wiki-session-start.mjs` / `wiki-session-end.mjs` 自动加载与保存 |
| `.omc/shared-memory/` | 跨会话知识库 | `Read` / `Write` 工具 |
| `.omc/traces/` | 执行追踪日志 | `Read` 工具；`subagent-tracker.mjs` 在 `SubagentStart` / `SubagentStop` 时写入 |
| `.omc/plans/*.md` | `$plan` / `$ralplan` 产出的计划文件 | `Read` / `Edit` 工具 |
| `.omc/handoffs/` | Team 模式的 handoff 文档 | 同上 |

---

## 安装

### 前置条件

CodeBuddy 原生支持 Node.js hook —— 本插件的 hook 脚本以 `node` 运行并从 stdin 读取 JSON。本插件 **零必需 npm 依赖**：唯一曾经被引用的 Node 模块 `bridge/mcp-server.cjs` 已随 MCP 排除一起移除。

**唯一可选的原生模块**：`better-sqlite3`。它对插件加载/运行并非必需。装上后启用并发工作流状态锁；不装时部分工作流状态写入（autopilot / ralph / team）会静默降级，但插件仍能工作。

```bash
node --version    # 任意现代 Node（18+）即可

# 可选：仅当依赖 autopilot/ralph/team 工作流时安装。
# 不装也能跑，但状态写入是尽力而为。
npm install -g better-sqlite3
```

### 安装步骤

#### 方式 A：从本地源码快速测试

```bash
codebuddy --plugin-dir ./oh-my-codebuddy
```

启动后 CodeBuddy 会直接从 `./oh-my-codebuddy` 加载 `omc` 插件及其 hooks，无需 marketplace 注册。适合修改、调试、贡献代码时使用。

#### 方式 B：从 GitHub 远程安装（推荐发布后使用）

1. **添加 GitHub marketplace 源**（在 CodeBuddy 中执行）

   ```text
   /plugin marketplace add https://github.com/ooptsd/oh-my-codebuddy.git
   ```

   CodeBuddy 会自动克隆该仓库，从仓库根目录读取 `.codebuddy-plugin/marketplace.json`。在 **Personal** marketplace 下面应该能看到 `omc-plugins`。

   > 仓库当前为 public，clone 不需要凭证。

2. **安装插件**

   ```text
   /plugin install omc@omc-plugins
   ```

3. **重载插件列表**

   ```text
   /reload-plugins
   ```

4. **验证**
   - 在 CodeBuddy 设置中，**Settings → Plugins** 应显示 `omc` 处于已安装状态。
   - **Settings → Hooks** 应显示该插件的 hooks（只读）。
   - **Settings → MCP servers** **不应** 列出任何 `plugin:omc:*` 服务（本发行版没有）。
   - 在聊天会话中输入 `/`，能看到 omc 的命令（`/omc:omc-setup`、`/omc:plan`、`/omc:ask` 等）；输入 `$`，能看到 skills（`$omc:plan`、`$omc:execute`、`$omc:review` 等）。
   - 开启新会话，`SessionStart` hook 应触发（可在本地 CodeBuddy 日志中查找 `hook.run` 记录）。

---

## 与 Claude Code OMC 行为一致的部分

在受支持的事件集合（全部 11 个）上，行为与 omc 的 Claude Code 版完全相同：

- 每个 prompt 上的关键词检测与 skill 注入（`UserPromptSubmit`）。
- 跨工具调用持久化的项目记忆（`PostToolUse` → `project-memory-posttool`）。
- 工具使用强制（`PreToolUse`）。
- Bash 权限门禁（`PermissionRequest`）。
- 工具结果校验（`PostToolUse`）。
- 失败恢复提示（`PostToolUseFailure`）。
- 子代理启动 / 停止追踪与交付物校验（`SubagentStart` / `SubagentStop`）。
- 上下文压缩前快照（`PreCompact`）。
- Stop 时刻的上下文守卫、漂移守卫、persistent mode、code simplifier（`Stop`）。
- 会话结束异步清理（`SessionEnd`）。

变量 `${CODEBUDDY_PLUGIN_ROOT}`（出现在每条 hook 命令中）由 CodeBuddy 在 hook 执行时替换为插件根目录。**CodeBuddy 注入机制**：权威环境变量是 `${CODEBUDDY_PLUGIN_ROOT}`，指向插件根目录。`hooks/hooks.json` 全部使用权威的 `${CODEBUDDY_PLUGIN_ROOT}` 引用；脚本读取统一为 `process.env.CODEBUDDY_PLUGIN_ROOT`（自 v5.4.3 起不再读取 `${CLAUDE_PLUGIN_ROOT}` 历史别名）。包装脚本 `scripts/run.cjs` 按 hook 契约从 stdin 读取、向 stdout 写入 JSON。

---

## 本发行版 **没有** 的内容（汇总）

供对比上游 oh-my-claudecode 的用户参考：

- ❌ MCP 服务器（`bridge/mcp-server.cjs`）及其约 55 个工具
- ❌ `maintenance` 匹配规则（死代码，但保留以对齐 hook 契约）

**净效果：** omc 的 *skills、commands、subagents*（真正的工作流入口）行为完全一致；hook 事件 **全部 11 个保留**，与 Claude Code 版一致；omz 的 *运行时簿记*（MCP 状态）在 CodeBuddy omc 中完全缺失，需要手动或基于 git 的补偿。

如果你需要完整的 MCP 功能集（`lsp_rename`、`ast_grep_search` 等），请通过其原生安装器（`.claude-plugin/marketplace.json`）安装 oh-my-claudecode。

---

## 开发

### 本发行版是 5.3.0 的快照

本发行版是 oh-my-claudecode **5.4.0** 的代码快照（具体 commit 见 git log）。当上游发布新版本时，需要按以下步骤从 `/Users/lizhouyang/code2/omc/oh-my-claudecode/` 重新同步：

```bash
SRC=/Users/lizhouyang/code2/omc/oh-my-claudecode
DST=/Users/lizhouyang/code2/omc/oh-my-codebuddy

# 重新拷贝组件
rsync -av --delete \
  "$SRC/skills/" \
  "$DST/skills/"

rsync -av --delete \
  "$SRC/commands/" \
  "$DST/commands/"

rsync -av --delete \
  "$SRC/agents/" \
  "$DST/agents/"

rsync -av --delete \
  "$SRC/scripts/" \
  "$DST/scripts/"
```

同步后还需要执行品牌重命名（`omc-*` → `omc-*`）和重新生成 `.codebuddy-plugin/{plugin,marketplace}.json`。品牌重命名规则见上游迁移指南；本目录无脚本化等价物，需人工执行。

### 文件数量（安装后）

```bash
cd /Users/lizhouyang/code2/omc/oh-my-codebuddy
find . \
  \( -path './skills/*/SKILL.md' \
     -o -path './commands/*.md' \
     -o -path './agents/*.md' \) | wc -l
# 预期：79（39 个 skills + 21 个 commands + 19 个 agents）
```

---

## 许可证

MIT —— 见 `LICENSE`（继承自上游 oh-my-claudecode）。