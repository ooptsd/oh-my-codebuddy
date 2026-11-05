# 2026-11-05 状态根与技能层命名空间隔离（.omcb/ + 原生技能路径）— 设计

## 背景

oh-my-codebuddy 从 oh-my-claudecode（v5.4.0）移植而来（当前基线 5.0.0），两边 hooks
逐字节同构（仅 `$CLAUDE_PLUGIN_ROOT` vs `$CODEBUDDY_PLUGIN_ROOT` 不同），且状态解析
逻辑完全一致。用户在多工具场景（Claude Code + CodeBuddy 交替/并行/团队混合）下，
所有同名状态面共享，产生跨工具状态互踩。全部场景（交替、分项目、团队混合）均需评估，
冲突矩阵已确认。

**共享面盘点（冲突根源，5 层）：**

1. **项目级 `.omc/`**（最严重）：两边 `resolveOmcStateRoot` 解析顺序一致
   （`OMC_STATE_DIR > .omc-workspace > git 根 > cwd`），同一 repo 解析到同一
   `.omc/state/`，文件名一致（`autopilot-state.json`、`ralph-state.json`、
   `idle-notif-cooldown.json`、`pre-tool-advisory-throttle.json` 等）。
   autopilot/ralph 工作流状态互踩：另一工具的 persistent-mode/Stop hook 会读到
   并尝试推进或触发 drift guard，工作流被劫持。版本偏差（5.4 vs 5.0）放大风险：
   新版 workflow 字段被旧版 `isValidWorkflowDescriptor` 判非法而重置。
2. **用户级 `~/.omc/`**：`~/.omc/config.json`、`~/.omc/state/autopilot-state.json`
   全局兜底、`~/.omc/skills/` 交叉注入（codebuddy 的 skill-injector 与 claudecode
   的 learner 都读写）。
3. **环境变量**：`OMC_STATE_DIR`、`DISABLE_OMC`、`OMC_SKIP_HOOKS` 同名。
4. **计划/交接文件**：`.omc/plans/ralplan-*.md`、`.omc/specs/`、`.omc/handoffs/`
   两边 autopilot 都扫描消费。
5. **工作流制品**：`.omc/notepad.md`、`.omc/project-memory.json`、`.omc/skills/`。

**家族先例**：oh-my-kimi 已做同样隔离（`.omk/` + `.omk-workspace`，env var 保留
`OMC_STATE_DIR`）。

**技能层事实（已验证）**：

- `.omc/skills/` 无任何默认内容（插件自带 40+ skills 全在插件包 `skills/` 目录，
  宿主原生加载）；它是纯运行时层：skill-injector.mjs:341 扫描目录 + skillify 写入目标。
- CodeBuddy 官方有原生技能机制（workbuddy.ai/docs/zh/cli/skills）：项目级
  `.codebuddy/skills/`、用户级 `~/.codebuddy/skills/`，AI 按 description 自动发现，
  `/skills` 面板管理，`skillOverrides` 四态可见性控制，官方支持团队共享提交。
- omc 技能层现状是双路径写入：用户级 `~/.codebuddy/skills/omc-learned/`（已宿主域）
  + 项目级 `.omc/skills/`（自有域）。

## 决策（用户确认）

- **方案 1（状态根命名空间拆分）**：项目级 `.omc/` → `.omcb/`；home 级 `~/.omc/`
  → `~/.omcb/`；marker `.omc-workspace` → `.omcb-workspace`。
- **命名**：`.omcb/`（与 kimi 的 `.omk/` 同构）。env var 新增 `OMCB_STATE_DIR`，
  优先级高于 `OMC_STATE_DIR`（兼容回退保留）。
- **技能层双轨制**：
  - OMC 运营层技能（team/autopilot 等工作流内部技能）→ 维持自有命名空间
    `.omcb/skills/`（仅 injector 消费）；
  - 业务型生成技能（skillify /skill 产出的领域知识技能）→ 迁到 CodeBuddy 原生
    路径：项目级 `.codebuddy/skills/`、用户级 `~/.codebuddy/skills/`（去掉
    `omc-learned` 子目录层）。
- **迁移策略**：干净切换，不做双读。插件尚未重发市场（正是窗口期）。

## 变更点

### 1. 状态根解析（核心）

`scripts/lib/state-root.mjs` + `state-root.cjs` 同步改：

- 优先级：`OMCB_STATE_DIR` > `OMC_STATE_DIR`（兼容回退）> `.omcb-workspace`
  marker > git 根 > cwd；
- 目录名：`join(root, '.omc')` → `join(root, '.omcb')`（workspace/git/cwd 三处）；
- 无 git 兜底：`join(home, '.omc')` → `join(home, '.omcb')`；
- marker 文件名：`.omc-workspace` → `.omcb-workspace`（findWorkspaceRoot 与
  workspaceIdentifier 两处读取）；
- `isSafeWorkspaceRoot` 排除列表追加 `'.omcb'`（防 `.omcb/` 自身被当 workspace 根）。

### 2. Home 级直连点（4 处）

| 位置 | 现值 | 新值 |
|---|---|---|
| `code-simplifier.mjs:41` | `~/.omc/config.json` | `~/.omcb/config.json` |
| `persistent-mode.mjs:206` | `~/.omc/config.json` | `~/.omcb/config.json` |
| `persistent-mode.mjs:1096` | `~/.omc/state`（autopilot 全局兜底） | `~/.omcb/state` |
| `skill-injector.mjs:635` | `GLOBAL_SKILLS_DIR ~/.omc/skills` | `~/.omcb/skills`（运营层技能） |

### 3. 技能层双轨制

**写入目标（skillify /skill skill docs）：**

- 项目级：`.omc/skills/<name>.md` → `.codebuddy/skills/<name>/SKILL.md`
  （CodeBuddy 原生约定：每技能一目录，官方支持提交共享）；
- 用户级：`~/.codebuddy/skills/omc-learned/<name>.md` →
  `~/.codebuddy/skills/<name>/SKILL.md`（去掉 `omc-learned` 层级）；
- 格式：从扁平单文件改为目录 + SKILL.md（原生发现要求）。

**skill-injector 扫描源调整：**

- 删 `GLOBAL_SKILLS_DIR`（`~/.omc/skills`）与 `USER_SKILLS_DIR`
  （`~/.codebuddy/skills/omc-learned/`）扫描；
- `PROJECT_SKILLS_SUBDIR` 保持 `join('.omcb', 'skills')`，仅扫描运营层技能；
- 业务技能改由 CodeBuddy 原生发现机制加载（懒加载，模型按 name+description
  决定调用），不再经 hook 注入。

**明确不改的：**

- 插件包内 `skills/`（Tier-0 工作流技能）——宿主 plugin 机制原生加载，已正确；
- `keyword-detector.mjs`——Tier-0 关键词路由（`autopilot`/`ralplan` 等）与技能
  发现无关，保留；
- `DISABLE_OMC`/`OMC_SKIP_HOOKS` kill switch——全局语义合理，保留；
- `~/.codebuddy/.omc/`（getOmcConfigDir、hud-config、cache-occupancy registry）
  ——已在 `~/.codebuddy` 工具域内隔离，且 `.omc` 在这里是“omc 插件”的子目录语义，
  与 claudecode 无冲突；
- `.codebuddy/omc.jsonc` 项目配置——工具域内，不变。

### 4. 文档（约 82 处 `.omc` 引用）

- `docs/CODEBUDDY.md` 模板 `<worktree_paths>` 节全面改写（`.omc/` → `.omcb/`，
  增补 `OMCB_STATE_DIR` 优先级与技能层双轨说明）；
- skills/agents/README 中 `.omc/...` 路径引用同步改；skillify/skill/wiki 相关
  章节改为原生路径约定；
- 仓库 `.gitignore`：`.omc/` → `.omcb/`（保持“全忽略”现状，运营层技能
  `.omcb/skills/` 是否 re-include 维持现状不扩张）。

### 5. 验证

- `verify.sh` 第 7 节扩展：同时审计 `.omc` 旧名残留（零容忍，白名单仅
  oh-my-claudecode 上游项目名引用）；
- `node --check` 全部改动 `.mjs`；`bash -n` 改动 `.sh`；
- grep 清扫：`\.omc[/='"' ]` 与 `OMC_STATE_DIR`（文档中保留兼容说明除外）预期
  仅剩白名单命中。

## 影响面

- scripts 25 处 + skills/agents/docs 82 处，约 107 处引用改名；4 处 home 直连点；
  skill-injector 扫描逻辑缩减；skillify/skill 写入目标与文档格式改版。
- 行为变化：(a) 旧 `.omc/` 状态不再被读（有意，干净切换）；(b) 业务技能经 CodeBuddy
  原生发现加载，不再每会话注入最多 5 个（token 更省）；(c) `~/.omc/skills/` 交叉
  注入切断，claudecode learner 与 codebuddy injector 彻底解耦。
- 与 claudecode 的冲突面：状态层与全局技能注入面完全消除；`.omc/skills/`（可提交）
  交叉消费面消除（团队混合场景下两工具各自维护技能，版本漂移下本就是隐患）。
- 一次性迁移：文档给出 `git mv .omc .omcb` 指引（含 worktree 场景）；
  `~/.codebuddy/CODEBUDDY.md` 需在模板更新后重刷。

## Alternatives 考虑过

1. **所有权标签 + 互斥锁**：共享路径 + `owner` 字段。保留跨工具交接，但每个 hook
   加检查、diff 大、漏一处即 bug，且对 `~/.omc/skills/` 交叉注入无效。否决。
2. **纯文档约定**：不改代码靠自律。团队场景必然踩。否决。
3. **技能层全原生化**（含运营层）：冲突面最小，但运营层技能（工作流内部提示词）
   与 Tier-0 关键词路由耦合紧密，且 injector 的确定性注入与原生懒加载行为不同。
   用户选择双轨制：运营层留自有域保确定性，业务层原生化保生态。
4. **`.omc-cb/` 长名**：可读性优先。`.omcb/` 与家族先例（`.omk/`）同构，简洁一致。否决。
