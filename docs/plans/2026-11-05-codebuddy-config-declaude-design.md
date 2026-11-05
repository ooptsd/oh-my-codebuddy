# 2026-11-05 CodeBuddy 化收尾：配置路径/文件全面去 Claude 残留 — 设计

## 背景

上次提交（e65737e）声称全面迁移配置触点，但留下了四类残留：约 40 个文件中的
`CODEBUDDY_X || CLAUDE_X` 回退链、pre-tool-enforcer/session-start 里约 280 行
Bedrock/Vertex 模型路由守卫（CodeBuddy 宿主不注入 CLAUDE_MODEL/ANTHROPIC_* 等
env，永远不会触发的死代码）、claude_* 状态字段候选名、以及文档性残留。
另发现两处遗漏：state-root.cjs 只读 CLAUDE_PLUGIN_ROOT（漏改），
keyword-detector.mjs 的 isTeamEnabled 无任何调用方（双料死代码）。

## 决策（用户确认）

- 范围：全部清除（不留 CLAUDE_* legacy fallback）。
- 模型路由守卫：删除死代码（Task/Agent 分支仅保留 skill-namespace 守卫与
  agents.<name>.model 注入，注入简化为"非 inherit 则原样注入"）。
- isTeamEnabled：确认死代码后删除；官方 ralph-loop 插件检测一并删除
  （ralph-loop@claude-plugins-official 在 CodeBuddy 市场不存在，永远返回空）。

## 变更点

1. **Env 解析单一化**：config-dir.{sh,mjs,cjs} 只认 CODEBUDDY_CONFIG_DIR；
   所有脚本 plugin root 只认 CODEBUDDY_PLUGIN_ROOT；session id 只认
   CODEBUDDY_SESSION_ID；getClaudeConfigDir→getConfigDir（三份实现 + 8 个调用方）。
2. **路由守卫删除**：pre-tool-enforcer 删 isProviderSpecificModelId/
   isBedrockProviderEnv/isVertexProviderEnv/resolveTierAliasToSafeModel/
   normalizeToCcAlias/TIER_TO_DEFAULT_ENV_KEYS/hasExtendedContextSuffix/
   isSubagentSafeModelId/acceptsProxyAnthropicDefaultTierValue/isNonClaudeProviderEnv/
   isConfigForceInheritProxyEnv/hasNormalClaudeActiveModel/isNormalClaudeModelId/
   getActiveModelIds/isTierAlias/TIER_ALIASES/isForceInheritEnabled/loadOmcConfig/
   readAgentDefinitionModel + forceInherit 分支；session-start 删
   shouldEmitModelRoutingOverride/isBedrockSession/isVertexSession/
   isTruthyProviderFlag/getSessionModelId/readRoutingForceInheritFromConfig +
   优先级表项 [MODEL ROUTING OVERRIDE；删 lib/model-routing-override-message.mjs。
   agents.<name>.model 注入不再 normalizeToCcAlias，非 'inherit' 原样注入
   updatedInput。
3. **keyword-detector 死代码**：删 isTeamEnabled、OFFICIAL_RALPH_LOOP_PLUGIN_ID
   及全部 officialRalphLoop* 函数与两个调用点（skillName === 'ralph' 分支）。
4. **状态字段**：goal 候选删 claude_goal_objective/claudeGoalObjective/
   claudeObjective/codex_*（保留 goal_objective/goalObjective/objective）；
   extractClaudeGoalSnapshot→extractGoalSnapshot；getClaudeMdVersion→
   getMemoryFileVersion；session-start 删 CLAUDE.md legacy 读取；
   ultragoal SKILL.md --claude-goal-json→--goal-json。
5. **文档**：skills/commands 的 env 回退模式简化；commands 第 18 行样板；
   workflow-drift-guard 注释；autopilot 删 CC 版本号细节；README 第 59 行；
   state-root.cjs 排除列表去掉 '.claude'/'.codex'（保留注释说明 CodeBuddy home）。
6. **verify.sh 收紧**：标记任何 CLAUDE_* env、.claude 路径、CLAUDE.md 引用；
   白名单仅 oh-my-claudecode（上游项目名）与 .claude-plugin（README 兼容表）。
7. **验证**：node --check 全部 .mjs、bash -n 全部 .sh、verify.sh、grep 清扫
   预期 0 意外命中。单一 commit。

## 影响面

- 约 60+ 文件，删除约 350 行死代码/回退。
- 行为变化：CLAUDE_CONFIG_DIR/CLAUDE_PLUGIN_ROOT/CLAUDE_SESSION_ID 不再被识别
  （有意）；模型路由 deny 分支不再存在（在 CodeBuddy 中本就不可达）。
- verify.sh 从"允许 legacy 配对"收紧为"零容忍 + 两项白名单"。
