# Copilot Instructions (Animus / GML)

You are reviewing a GameMaker GML codebase. Follow these rules:

## Repo awareness
- Planner files: `GOAP/scripts/**/Animus_Planner.gml`
- Agent files: `GOAP/scripts/**/Animus_Agent.gml`
- Executor/Strategies: `GOAP/scripts/**/Animus_Executor.gml`, `GOAP/scripts/**/Animus_*Strategy*.gml`, `Animus_StrategyTemplates.gml`

When proposing diffs:
- If editing `Animus_Planner.gml`, never introduce legacy plan containers or mutable globals.
- If editing `Animus_Agent.gml`, keep tick minimal; delegate to planner/executor.
- Always show planner signature: `plan(agent, goals_to_check, last_goal, memory)` and assert shape with `Animus_Core.assert_plan_shape(plan)`.


## Style & Naming
- Variables: `snake_case`. Constructors/top-level functions: `PascalCase`. Struct methods: `snake_case = function(){}`.
- Keep opening brace on same line; closing brace on its own line. Respect spacing: `if (a + b == c) { return; }`.

## Architecture
- **One** canonical plan shape: Planner returns a plan struct (with `meta.*`). Do **not** reintroduce `GOAP_Node`.
- Agent = sensing/planning/execution orchestration only; don’t hide logic inside the Agent tick.
- Strategies must implement `start/update/stop/invariant_check`. Prefer `Animus_StrategyTemplates`.

## Contracts & Safety
- Replace silent/implicit `return` with explicit outcomes. Do not swallow errors.
- Use `Animus_Core.assert(...)`, `Animus_Core.assert_plan_shape(...)`, `Animus_Core.is_callable(...)`.
- Determinism: no wall-clock, no OS RNG; use executor PRNG/logical_time.

## Performance
- Avoid per-step allocations in hot loops. Cache indices; short-circuit conditions.
- Use `meta.referenced_keys` to scope memory invalidation and executor subscriptions.

## Output format for reviews
- For each issue: `file:line`, one-sentence rationale, **minimal diff** fenced as ```gml.
- Never propose global renames without showing `.yy` updates or noting `GOAP.resource_order` impact.
