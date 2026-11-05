---
name: team
description: N coordinated agents on shared task list using CodeBuddy native agent teams
argument-hint: "[N:agent-type] [ralph] <task description>"
aliases: []
level: 4
---

# Team Skill

Spawn N coordinated agents working on a shared task list using CodeBuddy's native team runtime. Create the team with `TeamCreate`, spawn teammates with the Agent tool using distinct `name` values, coordinate through the shared task list (TaskCreate/TaskUpdate/TaskList) and SendMessage, and tear down with `TeamDelete` when the work is done.

The `swarm` compatibility alias was removed in #1131.

## Usage

```
/omc:team N:agent-type "task description"
/omc:team "task description"
/omc:team ralph "task description"
```

### Parameters

- **N** - Number of teammate agents (1-20). Optional; defaults to auto-sizing based on task decomposition.
- **agent-type** - omc agent to spawn for the `team-exec` stage (e.g., executor, debugger, designer). Optional; defaults to stage-aware routing. See Stage Agent Routing below.
- **task** - High-level task to decompose and distribute among teammates
- **ralph** - Optional modifier. When present, wraps the team pipeline in Ralph's persistence loop (retry on failure, architect verification before completion). See Team + Ralph Composition below.

### Examples

```bash
/team 5:executor "fix all TypeScript errors across the project"
/team 3:debugger "fix build errors in src/"
/team 4:designer "implement responsive layouts for all page components"
/team "refactor the auth module with security review"
/team ralph "build a complete REST API for user management"
```

## Architecture

```
User: "/team 3:executor fix all TypeScript errors"
              |
              v
      [TEAM ORCHESTRATOR (Lead)]
              |
              +-- TeamCreate (native CodeBuddy team runtime)
              |       -> lead remains current session
              |
              +-- Analyze & decompose task into subtasks
              |       -> explore/architect produces subtask list
              |
              +-- Create task list entries from the implementation plan
              |       -> TODO/task entries #1, #2, #3 with dependencies
              |
              +-- Update task-list entries (pre-assign owners)
              |       -> task #1 owner=worker-1, etc.
              |
              +-- Agent(name="worker-1") x 3
              |       -> spawns teammates into the team
              |
              +-- Monitor loop
              |       <- teammate messages (auto-delivered by the active team surface)
              |       -> task-list review for progress
              |       -> message teammates through the active team surface to unblock/coordinate
              |
              +-- Completion
                      -> request shutdown from each teammate through the active team surface
                      <- shutdown acknowledgement from teammates
                      -> TeamDelete (teammates shut down first)
                      -> rm .omc/state/team-state.json
```

**Native CodeBuddy team model:**

```
- No per-team ~/.codebuddy/teams/<name>/ directory is created by this skill.
- `TeamCreate`/`TeamDelete` manage the team lifecycle natively.
- `team_name` is a human-readable slug for omc state and reporting only; do not rely on it for routing.
- Spawn teammates via Agent with `name="worker-N"` and `team_name` when spawning inside a named team.
```

## Goal Workflow Relationship

Team is the omc authority for parallel, staged execution. Use the deterministic conflict policies `refuse`, `adopt_existing`, and `artifact_only` rather than non-deterministic warning handling. If a task mentions a session `/goal` hook, Ralph, or artifact-only Ultragoal, keep Team as the primary loop authority unless the leader explicitly hands off. Use `/goal` only as a documented native handoff target or as visible evidence from the lead session; do not claim the `/goal` evaluator independently runs commands, reads files, or replaces `team-verify` / `team-fix`. Artifact-only Ultragoal references should be treated as durable goal ledger/checkpoint/evidence artifacts, not as worker execution by themselves.

## Staged Pipeline (Canonical Team Runtime)

Team execution follows a staged pipeline:

`team-plan -> team-prd -> team-exec -> team-verify -> team-fix (loop)`

### Stage Agent Routing

Each pipeline stage uses **specialized agents** -- not just executors. The lead selects agents based on the stage and task characteristics.

| Stage           | Required Agents                         | Optional Agents                                                                                                                            | Selection Criteria                                                                                                                                                                                |
| --------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **team-plan**   | `explore` (lite), `planner` (reasoning) | `analyst` (reasoning), `architect` (reasoning)                                                                                             | Use `analyst` for unclear requirements. Use `architect` for systems with complex boundaries.                                                                                                      |
| **team-prd**    | `analyst` (reasoning)                   | `critic` (reasoning)                                                                                                                       | Use `critic` to challenge scope.                                                                                                                                                                  |
| **team-exec**   | `executor` (default)                    | `executor` (reasoning), `debugger` (default), `designer` (default), `writer` (lite), `test-engineer` (default)                             | Match agent to subtask type. Use `executor` (model=reasoning) for complex autonomous work, `designer` for UI, `debugger` for compilation issues, `writer` for docs, `test-engineer` for test creation. |
| **team-verify** | `verifier` (default)                    | `test-engineer` (default), `security-reviewer` (default), `code-reviewer` (reasoning)                                                      | Always run `verifier`. Add `security-reviewer` for auth/crypto changes. Add `code-reviewer` for >20 files or architectural changes. `code-reviewer` also covers style/formatting checks.          |
| **team-fix**    | `executor` (default)                    | `debugger` (default), `executor` (reasoning)                                                                                               | Use `debugger` for type/build errors and regression isolation. Use `executor` (model=reasoning) for complex multi-file fixes.                                                                     |

**Routing rules:**

1. **The lead picks agents per stage, not the user.** The user's `N:agent-type` parameter only overrides the `team-exec` stage worker type. All other stages use stage-appropriate specialists.
2. **Specialist agents complement executor agents.** Route analysis/review to architect/critic agents and UI work to designer agents.
3. **Cost mode affects model tier.** In downgrade: `reasoning` agents to `default`, `default` to `lite` where quality permits. `team-verify` always uses at least `default`.
4. **Risk level escalates review.** Security-sensitive or >20 file changes must include `security-reviewer` + `code-reviewer` (reasoning) in `team-verify`.

### Stage Entry/Exit Criteria

- **team-plan**
  - Entry: Team invocation is parsed and orchestration starts.
  - Agents: `explore` scans codebase, `planner` creates task graph, optionally `analyst`/`architect` for complex tasks.
  - Exit: decomposition is complete and a runnable task graph is prepared.
- **team-prd**
  - Entry: scope is ambiguous or acceptance criteria are missing.
  - Agents: `analyst` extracts requirements, optionally `critic`.
  - Exit: acceptance criteria and boundaries are explicit.
- **team-exec**
  - Entry: task list assignment and worker spawn are complete.
  - Agents: workers spawned as the appropriate specialist type per subtask (see routing table).
  - Exit: execution tasks reach terminal state for the current pass.
- **team-verify**
  - Entry: execution pass finishes.
  - Agents: `verifier` + task-appropriate reviewers (see routing table).
  - Exit (pass): verification gates pass with no required follow-up.
  - Exit (fail): fix tasks are generated and control moves to `team-fix`.
- **team-fix**
  - Entry: verification found defects/regressions/incomplete criteria.
  - Agents: `executor`/`debugger` depending on defect type.
  - Exit: fixes are complete and flow returns to `team-exec` then `team-verify`.

### Verify/Fix Loop and Stop Conditions

Continue `team-exec -> team-verify -> team-fix` until:

1. verification passes and no required fix tasks remain, or
2. work reaches an explicit terminal blocked/failed outcome with evidence.

`team-fix` is bounded by max attempts. If fix attempts exceed the configured limit, transition to terminal `failed` (no infinite loop).

### Stage Handoff Convention

When transitioning between stages, important context — decisions made, alternatives rejected, risks identified — lives only in the lead's conversation history. If the lead's context compacts or agents restart, this knowledge is lost.

**Each completing stage MUST produce a handoff document before transitioning.**

The lead writes handoffs to `.omc/handoffs/<stage-name>.md`.

#### Handoff Format

```markdown
## Handoff: <current-stage> → <next-stage>

- **Decided**: [key decisions made in this stage]
- **Rejected**: [alternatives considered and why they were rejected]
- **Risks**: [identified risks for the next stage]
- **Files**: [key files created or modified]
- **Remaining**: [items left for the next stage to handle]
```

#### Handoff Rules

1. **Lead reads previous handoff BEFORE spawning next stage's agents.** The handoff content is included in the next stage's agent spawn prompts, ensuring agents start with full context.
2. **Handoffs accumulate.** The verify stage can read all prior handoffs (plan → prd → exec) for full decision history.
3. **On team cancellation, handoffs survive** in `.omc/handoffs/` for session resume. They are not deleted by native CodeBuddy team cleanup (`TeamDelete` focuses on teammate shutdown, not omc handoffs).
4. **Handoffs are lightweight.** 10-20 lines max. They capture decisions and rationale, not full specifications (those live in deliverable files like DESIGN.md).

#### Example

```markdown
## Handoff: team-plan → team-exec

- **Decided**: Microservice architecture with 3 services (auth, api, worker). PostgreSQL for persistence. JWT for auth tokens.
- **Rejected**: Monolith (scaling concerns), MongoDB (team expertise is SQL), session cookies (API-first design).
- **Risks**: Worker service needs Redis for job queue — not yet provisioned. Auth service has no rate limiting in initial design.
- **Files**: DESIGN.md, TEST_STRATEGY.md
- **Remaining**: Database migration scripts, CI/CD pipeline config, Redis provisioning.
```

### Resume and Cancel Semantics

- **Resume:** restart from the last non-terminal stage using staged state + live task status. Read `.omc/handoffs/` to recover stage transition context.
- **Cancel:** `/omc:cancel` requests teammate shutdown, waits for responses (best effort), marks phase `cancelled` with `active=false`, captures cancellation metadata, then deletes team resources and clears/preserves Team state per policy. Handoff files in `.omc/handoffs/` are preserved for potential resume.
- Terminal states are `complete`, `failed`, and `cancelled`.

## Workflow

### Phase 1: Parse Input

- Extract **N** (agent count), validate 1-20
- Extract **agent-type**, validate it maps to a known omc subagent
- Extract **task** description

### Phase 2: Analyze & Decompose

Use `explore` or `architect` (via MCP or agent) to analyze the codebase and break the task into N subtasks:

- Each subtask should be **file-scoped** or **module-scoped** to avoid conflicts
- Subtasks must be independent or have clear dependency ordering
- Each subtask needs a concise `subject` and detailed `description`
- Identify dependencies between subtasks (e.g., "shared types must be fixed before consumers")

### Phase 3: Initialize Team State

Use CodeBuddy's native team runtime: call `TeamCreate` once to establish the team, then spawn teammates with the Agent tool.

Derive a slug such as `fix-ts-errors` for omc state, prompt labels, handoffs, and human-readable reporting only; it does not affect native routing.

Write omc state using the `state_write` MCP tool for proper session-scoped persistence:

```
state_write(mode="team", active=true, current_phase="team-plan", state={
  "team_name": "fix-ts-errors",
  "agent_count": 3,
  "agent_types": "executor",
  "task": "fix all TypeScript errors",
  "fix_loop_count": 0,
  "max_fix_loops": 3,
  "linked_ralph": false,
  "stage_history": "team-plan"
})
```

> **Note:** The MCP `state_write` tool transports all values as strings. Consumers must coerce `agent_count`, `fix_loop_count`, `max_fix_loops` to numbers and `linked_ralph` to boolean when reading state.

**State schema fields:**

| Field            | Type    | Description                                                                             |
| ---------------- | ------- | --------------------------------------------------------------------------------------- |
| `active`         | boolean | Whether team mode is active                                                             |
| `current_phase`  | string  | Current pipeline stage: `team-plan`, `team-prd`, `team-exec`, `team-verify`, `team-fix` |
| `team_name`      | string  | omc slug for state, handoffs, and reporting; does not affect native routing |
| `agent_count`    | number  | Number of worker agents                                                                 |
| `agent_types`    | string  | Comma-separated agent types used in team-exec                                           |
| `task`           | string  | Original task description                                                               |
| `fix_loop_count` | number  | Current fix iteration count                                                             |
| `max_fix_loops`  | number  | Maximum fix iterations before failing (default: 3)                                      |
| `linked_ralph`   | boolean | Whether team is linked to a ralph persistence loop                                      |
| `stage_history`  | string  | Comma-separated list of stage transitions with timestamps                               |

**Update state on every stage transition:**

```
state_write(mode="team", current_phase="team-exec", state={
  "stage_history": "team-plan:2026-02-07T12:00:00Z,team-prd:2026-02-07T12:01:00Z,team-exec:2026-02-07T12:02:00Z"
})
```

**Read state for resume detection:**

```
state_read(mode="team")
```

If `active=true` and `current_phase` is non-terminal, resume from the last incomplete stage instead of creating a new team.

### Phase 4: Create Tasks

Create task list entries for each subtask using the task-list surface (TaskCreate/TaskUpdate). Task-list tools are for tracking only; they do not create native teams.

```json
// Task-list entry for subtask 1
{
  "subject": "Fix type errors in src/auth/",
  "description": "Fix all TypeScript errors in src/auth/login.ts, src/auth/session.ts, and src/auth/types.ts. Run tsc --noEmit to verify.",
  "activeForm": "Fixing auth type errors"
}
```

**Response stores a task file (e.g. `1.json`):**

```json
{
  "id": "1",
  "subject": "Fix type errors in src/auth/",
  "description": "Fix all TypeScript errors in src/auth/login.ts...",
  "activeForm": "Fixing auth type errors",
  "owner": "",
  "status": "pending",
  "blocks": [],
  "blockedBy": []
}
```

For tasks with dependencies, update the active task-list entries after creation:

```json
// Task #3 depends on task #1 (shared types must be fixed first)
{
  "taskId": "3",
  "addBlockedBy": ["1"]
}
```

**Pre-assign owners from the lead** to avoid race conditions (there is no atomic claiming):

```json
// Assign task #1 to worker-1
{
  "taskId": "1",
  "owner": "worker-1"
}
```

### Phase 5: Spawn Teammates

Spawn N teammates using the Agent tool with distinct `name` values (plus `team_name` when spawning inside a named team). Each teammate gets the team worker preamble (see below) plus their specific assignment.

```json
{
  "subagent_type": "executor",
  "name": "worker-1",
  "prompt": "<worker-preamble + assigned tasks>"
}
```

**Response:**

```json
{
  "agent_id": "worker-1",
  "name": "worker-1"
}
```

**Side effects:**

- Teammate is spawned into the CodeBuddy team runtime
- An **internal task** is auto-created (with `metadata._internal: true`) tracking the agent lifecycle
- Internal tasks may appear in task-list output -- filter them when counting real tasks

**IMPORTANT:** Spawn all teammates in parallel (they are background agents). Do NOT wait for one to finish before spawning the next.

### Phase 6: Monitor

The lead orchestrator monitors progress through two channels:

1. **Inbound messages** -- Teammates message `team-lead` when they complete tasks or need help. These arrive through the active team/conversation surface.

2. **Task-list polling/review** -- Periodically check the task-list surface for overall progress:
   ```
   #1 [completed] Fix type errors in src/auth/ (worker-1)
   #3 [in_progress] Fix type errors in src/api/ (worker-2)
   #5 [pending] Fix type errors in src/utils/ (worker-3)
   ```
   Format: `#ID [status] subject (owner)`

**Coordination actions the lead can take:**

- **Unblock a teammate:** Send a message with guidance or missing context through the active team surface
- **Reassign work:** If a teammate finishes early, update the task-list entry to assign pending work to them and notify through the active team surface
- **Handle failures:** If a teammate reports failure, reassign the task or spawn a replacement

#### Task Watchdog Policy

Monitor for stuck or failed teammates:

- **Max in-progress age**: If a task stays `in_progress` for more than 5 minutes without messages, send a status check
- **Suspected dead worker**: No messages + stuck task for 10+ minutes → reassign task to another worker
- **Reassign threshold**: If a worker fails 2+ tasks, stop assigning new tasks to it

### Phase 6.5: Stage Transitions (State Persistence)

On every stage transition, update omc state:

```
// Entering team-exec after planning
state_write(mode="team", current_phase="team-exec", state={
  "stage_history": "team-plan:T1,team-prd:T2,team-exec:T3"
})

// Entering team-verify after execution
state_write(mode="team", current_phase="team-verify")

// Entering team-fix after verify failure
state_write(mode="team", current_phase="team-fix", state={
  "fix_loop_count": 1
})
```

This enables:

- **Resume**: If the lead crashes, `state_read(mode="team")` reveals the last stage and team name for recovery
- **Cancel**: The cancel skill reads `current_phase` to know what cleanup is needed
- **Ralph integration**: Ralph can read team state to know if the pipeline completed or failed

### Phase 7: Completion

When all real tasks (non-internal) are completed or failed:

1. **Verify results** -- Check that all real tasks (non-internal) are marked `completed` in the task-list surface
2. **Shutdown teammates** -- Send `shutdown_request` to each active teammate through the active team surface:
   ```json
   {
     "type": "shutdown_request",
     "recipient": "worker-1",
     "content": "All work complete, shutting down team"
   }
   ```
3. **Await responses** -- Each teammate responds with `shutdown_response(approve: true)` and terminates
4. **Clean up native team state** -- after teammates acknowledge shutdown, call `TeamDelete`, then clear omc state and any local task bookkeeping.
5. **Clean omc state** -- Remove `.omc/state/team-state.json`
6. **Report summary** -- Present results to the user

## Agent Preamble

When spawning teammates, include this preamble in the prompt to establish the work protocol. Adapt it per teammate with their specific task assignments.

```
You are a TEAM WORKER in omc team "{team_name}". Your name is "{worker_name}".
You report to the team lead ("team-lead").
You are not the leader and must not perform leader orchestration actions.

== WORK PROTOCOL ==

1. CLAIM: Check the task-list surface for tasks assigned to you (owner = "{worker_name}").
   Pick the first task with status "pending" that is assigned to you.
   Mark it `in_progress` using the active task-list surface:
   {"taskId": "ID", "status": "in_progress", "owner": "{worker_name}"}

2. WORK: Execute the task using your tools (Read, Write, Edit, Bash).
   Do NOT spawn sub-agents. Do NOT delegate. Work directly.

3. COMPLETE: When done, mark the task completed:
   {"taskId": "ID", "status": "completed"}

4. REPORT: Notify the lead through the active team/conversation surface:
   {"type": "message", "recipient": "team-lead", "content": "Completed task #ID: <summary of what was done>", "summary": "Task #ID complete"}

5. NEXT: Check the task-list surface for more assigned tasks. If you have more pending tasks, go to step 1.
   If no more tasks are assigned to you, notify the lead through the active team/conversation surface:
   {"type": "message", "recipient": "team-lead", "content": "All assigned tasks complete. Standing by.", "summary": "All tasks done, standing by"}

6. SHUTDOWN: When you receive a shutdown_request, respond with:
   {"type": "shutdown_response", "request_id": "<from the request>", "approve": true}

== BLOCKED TASKS ==
If a task has blockedBy dependencies, skip it until those tasks are completed.
Check the task-list surface periodically to see if blockers have been resolved.

== ERRORS ==
If you cannot complete a task, report the failure to the lead:
{"type": "message", "recipient": "team-lead", "content": "FAILED task #ID: <reason>", "summary": "Task #ID failed"}
Do NOT mark the task as completed. Leave it in_progress so the lead can reassign.

== RULES ==
- NEVER spawn sub-agents or use the Task tool
- NEVER run team spawning/orchestration skills or commands (for example `$team`, `$autopilot`, `$ralph`)
- ALWAYS use absolute file paths
- ALWAYS report progress to "team-lead" through the active team/conversation surface
- Use direct team/conversation messages with type "message" only -- never "broadcast"
```

### Agent-Type Prompt Injection (Worker-Specific Addendum)

When composing teammate prompts, append a short addendum emphasizing strict task-list updates (TaskCreate/TaskUpdate), active team/conversation messages, and no orchestration commands.

This addendum must preserve the core rule: **worker = executor only, never leader/orchestrator**.

## Communication Patterns

### Teammate to Lead (task completion report)

```json
{
  "type": "message",
  "recipient": "team-lead",
  "content": "Completed task #1: Fixed 3 type errors in src/auth/login.ts and 2 in src/auth/session.ts. All files pass tsc --noEmit.",
  "summary": "Task #1 complete"
}
```

### Lead to Teammate (reassignment or guidance)

```json
{
  "type": "message",
  "recipient": "worker-2",
  "content": "Task #3 is now unblocked. Also pick up task #5 which was originally assigned to worker-1.",
  "summary": "New task assignment"
}
```

### Broadcast (use sparingly -- sends N separate messages)

```json
{
  "type": "broadcast",
  "content": "STOP: shared types in src/types/index.ts have changed. Pull latest before continuing.",
  "summary": "Shared types changed"
}
```

### Shutdown Protocol (BLOCKING)

**CRITICAL: Steps must execute in exact order. Never clear omc team state before shutdown is confirmed or timed out.**

**Step 1: Verify completion**

```
Verify via the task-list surface — all real tasks (non-internal) are completed or failed.
```

**Step 2: Request shutdown from each teammate**

**Lead sends:**

```json
{
  "type": "shutdown_request",
  "recipient": "worker-1",
  "content": "All work complete, shutting down team"
}
```

**Step 3: Wait for responses (BLOCKING)**

- Wait up to 30s per teammate for `shutdown_response`
- Track which teammates confirmed vs timed out
- If a teammate doesn't respond within 30s: log warning, mark as unresponsive

**Teammate receives and responds:**

```json
{
  "type": "shutdown_response",
  "request_id": "shutdown-1770428632375@worker-1",
  "approve": true
}
```

After approval, the teammate terminates or stops accepting new work. Track acknowledgements in omc state/reporting; `TeamDelete` handles native teardown once all teammates are down.

**Step 4: Clear omc team state — only after ALL teammates confirmed or timed out**

After the blocking shutdown pass completes and all teammates acknowledge, call `TeamDelete`, then clear omc team state and local task bookkeeping.

**Shutdown sequence is BLOCKING:** Do not clear omc team state until all teammates have either:

- Confirmed shutdown (`shutdown_response` with `approve: true`), OR
- Timed out (30s with no response)

**IMPORTANT:** The `request_id` is provided in the shutdown request message that the teammate receives. The teammate must extract it and pass it back. Do NOT fabricate request IDs.

### Pre-flight Analysis (Optional)

For large ambiguous tasks, run analysis before team creation:

1. Spawn `Agent(subagent_type="planner", ...)` with task description + codebase context
2. Use the analysis to produce better task decomposition
3. Create team and tasks with enriched context

This is especially useful when the task scope is unclear and benefits from external reasoning before committing to a specific decomposition.

## Error Handling

### Teammate Fails a Task

1. Teammate reports the failure to the lead through the active team/conversation surface
2. Lead decides: retry (reassign same task to same or different worker) or skip
3. To reassign: update the active task-list entry with the new owner, then message the new owner through the active team surface

### Teammate Gets Stuck (No Messages)

1. Lead detects via the task-list surface -- task stuck in `in_progress` for too long
2. Lead messages the teammate asking for status through the active team surface
3. If no response, consider the teammate dead
4. Reassign the task to another worker through the active task-list surface

### Dependency Blocked

1. If a blocking task fails, the lead must decide whether to:
   - Retry the blocker
   - Remove the dependency by updating the active task-list entry's `blockedBy` metadata
   - Skip the blocked task entirely
2. Communicate decisions to affected teammates through the active team surface

### Teammate Crashes

1. Internal tracking for that teammate will show unexpected status
2. Lead reassigns orphaned tasks to remaining workers
3. If needed, spawn a replacement teammate with `Agent(name="worker-N", subagent_type="...")`

## Team + Ralph Composition

When the user invokes `/team ralph`, says "team ralph", or combines both keywords, team mode wraps itself in Ralph's persistence loop. This provides:

- **Team orchestration** -- multi-agent staged pipeline with specialized agents per stage
- **Ralph persistence** -- retry on failure, architect verification before completion, iteration tracking

### Activation

Team+Ralph activates when:

1. User invokes `/team ralph "task"` or `/omc:team ralph "task"`
2. Keyword detector finds both `team` and `ralph` in the prompt
3. Hook detects `MAGIC KEYWORD: RALPH` alongside team context

### State Linkage

Both modes write their own state files with cross-references:

```
// Team state (via state_write)
state_write(mode="team", active=true, current_phase="team-plan", state={
  "team_name": "build-rest-api",
  "linked_ralph": true,
  "task": "build a complete REST API"
})

// Ralph state (via state_write)
state_write(mode="ralph", active=true, iteration=1, max_iterations=10, current_phase="execution", state={
  "linked_team": true,
  "team_name": "build-rest-api"
})
```

### Execution Flow

1. Ralph outer loop starts (iteration 1)
2. Team pipeline runs: `team-plan -> team-prd -> team-exec -> team-verify`
3. If `team-verify` passes: Ralph runs architect verification (STANDARD tier minimum)
4. If architect approves: both modes complete, run `/omc:cancel`
5. If `team-verify` fails OR architect rejects: team enters `team-fix`, then loops back to `team-exec -> team-verify`
6. If fix loop exceeds `max_fix_loops`: Ralph increments iteration and retries the full pipeline
7. If Ralph exceeds `max_iterations`: terminal `failed` state

### Cancellation

Cancel either mode cancels both:

- **Cancel Ralph (linked):** Cancel Team first (graceful shutdown), then clear Ralph state
- **Cancel Team (linked):** Clear Team, mark Ralph iteration cancelled, stop loop

See Cancellation section below for details.

## Idempotent Recovery

If the lead crashes mid-run, the team skill should detect existing omc state and resume:

1. Read `state_read(mode="team")` for the active omc team slug, phase, and worker labels
2. Use omc handoffs and task-list state to determine current progress
3. Resume monitor mode instead of spawning duplicate teammates
4. Continue from the last recorded stage

This prevents duplicate worker spawns and allows graceful recovery from lead failures.

## Comparison: Team vs Legacy Swarm

| Aspect                  | Team (Native CodeBuddy)                                         | Swarm (Legacy SQLite)                  |
| ----------------------- | ---------------------------------------------------------------- | -------------------------------------- |
| **Storage**             | omc state/handoffs plus CodeBuddy's current task-list surface     | SQLite in `.omc/state/swarm.db`        |
| **Dependencies**        | `better-sqlite3` not needed                                      | Requires `better-sqlite3` npm package  |
| **Task claiming**       | Lead pre-assigns named workers through task-list state  | SQLite IMMEDIATE transaction -- atomic |
| **Race conditions**     | Possible if two agents claim same task (mitigate by pre-assigning) | None (SQLite transactions)             |
| **Communication**       | Native implicit-team messages / conversation turns                | None (fire-and-forget agents)          |
| **Task dependencies**   | Lead-managed dependencies in task-list state            | Not supported                          |
| **Heartbeat**           | Lead detects via missing messages/status                          | Manual heartbeat table + polling       |
| **Shutdown**            | Graceful request/response protocol plus omc state clear           | Signal-based termination               |
| **Agent lifecycle**     | Tracked by named Agent/Task spawns and omc state                  | Manual tracking via heartbeat table    |
| **Progress visibility** | Task-list state with named worker ownership             | SQL queries on tasks table             |
| **Conflict prevention** | Owner labels (lead-assigned)                                      | Lease-based claiming with timeout      |
| **Crash recovery**      | Lead detects via missing messages, reassigns                      | Auto-release after 5-min lease timeout |
| **State cleanup**       | Clear omc team state after teammate shutdown                      | Manual `rm` of SQLite database         |

**When to use Team over Swarm:** Always prefer `/team` for new native work. It uses CodeBuddy's team runtime, requires no external dependencies, supports inter-agent coordination, and has task dependency management.

## Cancellation

The `/omc:cancel` skill handles team cleanup:

1. Read team state via `state_read(mode="team")` to get `team_name` and `linked_ralph`
2. Request shutdown from all active named teammates through the active team surface
3. Wait for `shutdown_response` from each (15s timeout per member)
4. Clear state via `state_clear(mode="team")`
5. If `linked_ralph` is true, also clear ralph: `state_clear(mode="ralph")`

### Linked Mode Cancellation (Team + Ralph)

When team is linked to ralph, cancellation follows dependency order:

- **Cancel triggered from Ralph context:** Cancel Team first (graceful shutdown of all teammates), then clear Ralph state. This ensures workers are stopped before the persistence loop exits.
- **Cancel triggered from Team context:** Clear Team state, then mark Ralph as cancelled. Ralph's stop hook will detect the missing team and stop iterating.
- **Force cancel (`--force`):** Clears both `team` and `ralph` state unconditionally via `state_clear`.

If teammates are unresponsive, record the timeout, avoid spawning more work, and clear omc state only after the shutdown wait completes or the user force-cancels.

## Configuration

Optional settings live in `.codebuddy/omc.jsonc` (project) or `~/.codebuddy/config.jsonc` (user). Project values override user values.

```jsonc
{
  "team": {
    "ops": {
      "maxAgents": 20,
      "monitorIntervalMs": 30000,
      "shutdownTimeoutMs": 15000,
    },
  },
}
```

- **ops.maxAgents** - Maximum teammates (default: 20)
- **ops.monitorIntervalMs** - How often to review the task-list surface (default: 30s)
- **ops.shutdownTimeoutMs** - How long to wait for shutdown responses (default: 15s)

> **Note:** Native teammates do not have a hardcoded model default; each teammate inherits the lead session's configured model unless overridden per role.
>
> **Nesting:** Teammates are full, independent agent sessions in the team (see Phase 5). Do not assume a teammate can or cannot spawn nested subagents; the active runtime's spawn-depth setting controls subagent layers below the main conversation. Plan each teammate as the unit that does the work unless nested delegation is deliberate and supported by the active runtime.
>
> **Concurrency:** The host's concurrent-subagent limit defaults to 20; that limit applies to Agent-spawned subagents. Size teams conservatively when the lead also needs Agent-spawned work outside the team.

## State Cleanup

On successful completion:

1. After shutdown is confirmed or timed out, call `TeamDelete`, then clear omc state via MCP tools:
   ```
   state_clear(mode="team")
   ```
   If linked to Ralph:
   ```
   state_clear(mode="ralph")
   ```
2. Or run `/omc:cancel` which handles omc state cleanup automatically.

**IMPORTANT:** Clear omc team state only AFTER all teammates have been shut down or timed out.

## Gotchas

1. **Internal/lifecycle task entries may pollute task-list output** -- If the host reports internal lifecycle entries for spawned teammates, filter them when counting real task progress. The subject of an internal task is often the teammate's name.

2. **No atomic claiming** -- Native task-list state does not provide transactional claiming. Two teammates could race to claim the same task. **Mitigation:** The lead should pre-assign owners before spawning teammates. Teammates should only work on tasks assigned to them.

3. **Task IDs are strings when exposed by task-list tools** -- IDs may be auto-incrementing strings ("1", "2", "3"), not integers. Always pass string values to `taskId` fields when using task-list tools.

4. **Team teardown** -- use shutdown messages, then `TeamDelete`, plus omc state cleanup.

5. **Messages are auto-delivered** -- Teammate messages arrive to the lead as new conversation turns. No polling or inbox-checking is needed for inbound messages. However, if the lead is mid-turn (processing), messages queue and deliver when the turn ends.

6. **Do not put secrets in teammate prompts** -- Prompts can be retained in logs, state, or conversation history. Keep credentials and sensitive data out of teammate prompts.

7. **Shutdown acknowledgements are state/reporting events** -- After a teammate approves shutdown and terminates, track that acknowledgement in omc state/reporting.

8. **shutdown_response needs request_id** -- The teammate must extract the `request_id` from the incoming shutdown request JSON and pass it back. The format is `shutdown-{timestamp}@{worker-name}`. Fabricating this ID will cause the shutdown to fail silently.

9. **Team name must be a valid slug** -- Use lowercase letters, numbers, and hyphens. Derive from the task description (e.g., "fix TypeScript errors" becomes "fix-ts-errors").

10. **Broadcast is expensive** -- Each broadcast sends a separate message to every teammate. Use `message` (DM) by default. Only broadcast for truly team-wide critical alerts.

## Parallel session caveats

- **Multi-repo workspace anchor:** drop a `.omc-workspace` marker at the parent directory so multiple sessions across sub-repos share one `.omc/`. Resolution order: `OMC_STATE_DIR > .omc-workspace > git > cwd`. See `docs/REFERENCE.md`.
- **Session id source:** OMC_SESSION_ID env var wins in CLI contexts; hook payload data.session_id wins in hook contexts.
- **Plan id (when applicable):** Team state is session-scoped. Team handoffs at `.omc/handoffs/` are shared by design (see Wave G in the workspace plan).
- **Parallel verdict:** supported (session-scoped + shared handoffs by design)
