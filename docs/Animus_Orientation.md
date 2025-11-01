# Quick orientation for AI coding agents (Animus / GOAP in GML)

**Runtime**: open `GOAP/GOAP.yyp` in GameMaker (IDE/Runtime versions pinned in `GOAP/Animus_CodexPlaybook.md`).

**Core modules** (see `GOAP/scripts/*`):
- **Planner** — `Animus_Planner/Animus_Planner.gml` (A*; plan reuse; `meta.referenced_keys`)
- **Memory** — `Animus_Memory/Animus_Memory.gml` (read/write/snapshot; dirty tracking)
- **Agent** — `Animus_Agent/Animus_Agent.gml` (binds planner+memory+executor; tick loop)
- **Executor & Strategies** — `Animus_Executor/Animus_Executor.gml`, `Animus_ActionStrategy/Animus_ActionStrategy.gml`, `Animus_StrategyTemplates.gml`
- **Domain** — `Animus_Action`, `Animus_Goal`, `Animus_Belief`, `Animus_Predicate`

**Data flow**
Sensors → Memory (`memory.write(...)`) → Agent.tick(dt) → (schedule) Planner.plan(snapshot) → Executor runs plan.
Planner returns canonical **plan struct**; no legacy `GOAP_Node` at runtime.

**Editing rules**
- Prefer `Animus_*` APIs; `GOAP_*` shims live in `Animus_Core/` for compatibility only.
- Determinism: no wall-clock, no OS RNG; use executor PRNG / logical_time.
- Guard checks: `Animus_Core.assert(...)`, `Animus_Core.is_callable(...)`, `Animus_Core.assert_plan_shape(...)`.
- Planner contract: `planner.plan(agent, goals_to_check, last_goal, memory)` → **plan struct** or **undefined**.

**Strategy interface**
Required: `start(ctx)`, `update(ctx, dt)`, `stop(ctx, reason)`, `invariant_check(ctx)`.  
Optional: `get_expected_duration`, `get_reservation_keys`, `get_last_invariant_key`.  
See `Animus_StrategyTemplates.gml` for instant/timed/move templates.

**Performance levers**
`config.max_expansions`, `config.time_budget_ms`, `config.max_depth`.  
Planner emits `meta.referenced_keys`; executor/memory use them for invalidation/reuse.

**Debugging**
`Animus_Debug.dump_plan(plan)`, `executor.debug_json()`, `executor.playback_to_string(plan)`.  
Enable structured logs by setting the `ANIMUS_DEBUG` macro in GML source (see `Animus_CodexPlaybook.md`) and `Animus_Core.log()`.

**Conventions (enforced by CI & reviewers)**
- Variables: `snake_case`; Constructors/Top-level: `PascalCase`; Struct methods: `snake_case = function(){...}`.
- Bracing/spacing: `if (a + b == c) { return; }`.
- Avoid globals; explicit return outcomes; single canonical plan shape.
