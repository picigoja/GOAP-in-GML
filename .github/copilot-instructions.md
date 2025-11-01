## Quick orientation for AI coding agents

This repository implements Animus — a GOAP (Goal-Oriented Action Planning) framework written in GameMaker Language (GML). The guidance below focuses on codebase structure, developer workflows, and concrete examples to make edits safe and productive.

### Big picture
- Runtime: GameMaker project at `GOAP/GOAP.yyp` (open in GameMaker Studio matching the versions in `GOAP/Animus_CodexPlaybook.md`).
- Main pieces (see `GOAP/scripts/*`):
  - Planner: `GOAP/scripts/Animus_Planner/Animus_Planner.gml` (A* search, heuristics, plan reuse, meta.referenced_keys)
  - Memory: `GOAP/scripts/Animus_Memory/Animus_Memory.gml` (read/write/snapshot, dirty tracking)
  - Agent: `GOAP/scripts/Animus_Agent/Animus_Agent.gml` (binds planner, memory, executor; tick loop)
  - Executor & Strategies: `GOAP/scripts/Animus_Executor/Animus_Executor.gml`, `GOAP/scripts/Animus_ActionStrategy/Animus_ActionStrategy.gml`, and `Animus_StrategyTemplates.gml`
  - Domain models: `Animus_Action`, `Animus_Goal`, `Animus_Belief`, `Animus_Predicate`

### How data flows at runtime (short)
- Sensors -> Memory: `Animus_SensorHub` and sensors call `memory.write(...)`.
- Agent.tick(dt) calls sensors, triggers planner when scheduled, and uses `Animus_Executor` to run a plan.
- Planner builds a plan from the snapshot of `Animus_Memory`; plans include `meta.referenced_keys` used for reuse and invalidation.

### Concrete editing & implementation rules (do this in every change)
- Use `Animus_*` APIs. Legacy `GOAP_*` shims exist in `GOAP/scripts/Animus_Core/Animus_Core.gml` but prefer `Animus_*` names.
- Respect determinism: do not use wall-clock or OS RNG in strategies; use executor PRNG / logical_time.
- Use `Animus_Core.assert(...)` and `Animus_Core.is_callable(...)` for guard checks (see `Animus_Core.gml`).
- Planner contract: planner.plan(...) must either return a proper plan struct or undefined; use `Animus_Core.assert_plan_shape` to validate.

### Strategy interface (required methods & examples)
- Strategies returned by actions must implement: `start(context)`, `update(context, dt)`, `stop(context, reason)`, `invariant_check(context)`. Optional: `get_expected_duration`, `get_reservation_keys`, `get_last_invariant_key`.
- See templated factories: `GOAP/Animus_StrategyTemplates.gml` and example `action.build_strategy` in `README.md` quickstart for usage patterns.

### Planner specifics & performance hints
- Planner uses A* and collects `meta.referenced_keys` so that `Animus_Memory.is_dirty(key)` can invalidate/reuse plans. See `Animus_Planner.plan` and helpers (build_initial_state, should_reuse_plan).
- Config limits: `config.max_expansions`, `config.time_budget_ms`, and `config.max_depth` exist — changes here affect determinism and tick-performance.

### Build/run and debug workflows
- Open `GOAP/GOAP.yyp` in GameMaker Studio version indicated in `GOAP/Animus_CodexPlaybook.md` for full import/build.
- For unit/debugging in GML: use `Animus_Debug.dump_plan(plan)` and `executor.debug_json()` / `executor.playback_to_string(plan)` to inspect runtime traces.
- Use `#macro ANIMUS_DEBUG 1` (per repo conventions in the playbook) and `Animus_Core.log()` for structured logging.

### Editing patterns & conventions
- Naming conventions: variables snake_case, constructors PascalCase, methods in structs use snake_case function fields (see playbook).
- Each script folder pairs a `.gml` with a `.yy` meta file. Avoid renaming without updating `GOAP/GOAP.resource_order` and the `.yyp` project.
- Tests / Codex tasks: use `GOAP/Animus_CodexPlaybook.md` and `GOAP/Animus_CodexHelper.yaml` to discover repository tasks and allowed change patterns.

### Integration & cross-cutting concerns
- Reservation coordination: executor passes `reservation_bus` (a simple map) for resource reservations between agents — check `Animus_Executor` and `Animus_Agent` usage.
- Memory snapshots are used before planning: prefer `memory.snapshot(false)` for stable planner input.

### Quick code examples to reference
- Create + wire agent: see README quickstart near `agent.bind(planner, memory, executor)` and `agent.tick(_dt)`.
- Check planner reuse: `GOAP/scripts/Animus_Planner/Animus_Planner.gml` → `should_reuse_plan` and `meta.referenced_keys`.

If any section is unclear or you want more details (examples of mutations, tests to add, or a pull-request checklist), tell me which part to expand and I will iterate.
