/**
 * Delegation Enforcer
 *
 * Middleware for Task/Agent delegation calls. Model handling follows the
 * CodeBuddy pass-through contract (2026-11-04 tier-routing removal):
 * an explicit model param is preserved verbatim; when absent, nothing is
 * injected and CodeBuddy's native subagent model resolution decides.
 */
/**
 * Agent input structure from Claude Agent SDK
 */
export interface AgentInput {
    description: string;
    prompt: string;
    subagent_type: string;
    model?: string;
    resume?: string;
    run_in_background?: boolean;
}
/**
 * Result of model enforcement
 */
export interface EnforcementResult {
    /** Original input */
    originalInput: AgentInput;
    /** Modified input with model enforced */
    modifiedInput: AgentInput;
    /** Whether model was auto-injected */
    injected: boolean;
    /** The model that was used */
    model: string;
    /** Warning message (only if OMC_DEBUG=true) */
    warning?: string;
}
/**
 * Enforce contract for an agent delegation call (CodeBuddy semantics)
 *
 * Model handling after tier-routing removal (2026-11-04 design):
 * - Explicit model param -> passed through verbatim. No CC-alias
 *   normalization, no stripping: CodeBuddy accepts model IDs, names,
 *   aliases, and lite/reasoning scene variants natively.
 * - No model param -> nothing injected. CodeBuddy's own resolution chain
 *   decides (per-agent settings -> built-in declaration -> inherit main
 *   model).
 *
 * @param agentInput - The agent/task input parameters
 * @returns Enforcement result with modified input
 * @throws Error if agent type is unknown (issue #3667)
 */
export declare function enforceModel(agentInput: AgentInput): EnforcementResult;
/**
 * Check if tool input is an agent delegation call
 */
export declare function isAgentCall(toolName: string, toolInput: unknown): toolInput is AgentInput;
/**
 * Process a pre-tool-use hook for model enforcement
 */
export declare function processPreToolUse(toolName: string, toolInput: unknown): {
    modifiedInput: unknown;
    warning?: string;
};
/**
 * Get model for an agent type (for testing/debugging)
 */
export declare function getModelForAgent(agentType: string): string;
//# sourceMappingURL=delegation-enforcer.d.ts.map