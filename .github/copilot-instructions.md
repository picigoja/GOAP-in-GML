## Quick orientation for AI coding agents

This repo contains Animus — a GOAP (Goal-Oriented Action Planning) framework written in GameMaker Language (GML) plus a small Python toolchain for repo checks.

### Big picture (essential files)
- GameMaker project: `GOAP/GOAP.yyp` (open in GameMaker Studio matching `GOAP/Animus_CodexPlaybook.md`).
- Core runtime (see `GOAP/scripts/*`):
  - Planner: `GOAP/scripts/Animus_Planner/Animus_Planner.gml` (A* search, heuristics, plan reuse via `meta.referenced_keys`).
  - Memory: `GOAP/scripts/Animus_Memory/Animus_Memory.gml` (read/write, snapshot, dirty tracking).
  - Agent: `GOAP/scripts/Animus_Agent/Animus_Agent.gml` (binds planner, memory, executor; tick loop).
  - Executor & strategies: `GOAP/scripts/Animus_Executor/Animus_Executor.gml`, `GOAP/scripts/Animus_ActionStrategy/Animus_ActionStrategy.gml`, `Animus_StrategyTemplates.gml` (strategy factories).
  - Domain models: `Animus_Action`, `Animus_Goal`, `Animus_Belief`, `Animus_Predicate` (each in `GOAP/scripts/*`).

### Key developer workflows / commands
- Validate linter config (CI preflight):
  ```powershell
  python tools/gml_linter.py --validate-only
  ```
- Run full GML lint rules:
  ```powershell
  python tools/gml_linter.py
  ```
- Validate GameMaker .yy/.yyp JSON integrity:
  ```powershell
  python tools/yy_integrity.py
  ```
- Generate strategy suggestions (enforcer):
  ```powershell
  python tools/strategy_template_enforcer.py --verbose
  # emits tools/.strategy_suggestions.json
  ```

### Project-specific conventions (do this on every change)
- Prefer `Animus_*` APIs over legacy `GOAP_*` shims (see `GOAP/scripts/Animus_Core/Animus_Core.gml`).
- Strategy contract: factories must produce a struct implementing required methods:
  - Required: `start(context)`, `update(context, dt)`, `stop(context, reason)`, `invariant_check(context)`
  - Optional: `get_expected_duration`, `get_reservation_keys`, `get_last_invariant_key`.
  See `GOAP/Animus_StrategyTemplates.gml` for canonical factories.
- Determinism rules: no wall-clock APIs or OS RNG in planner/strategies. Use executor logical_time / PRNG.
- Planner contract: `planner.plan(...)` must return a plan struct or `undefined`. Use `Animus_Core.assert_plan_shape(plan)` after planner calls.
- GameMaker metadata files (`*.yy`, `GOAP.yyp`) are strict JSON — avoid trailing commas. The CI `yy_integrity` checks these.

### Integration & tooling notes
- CI runs (see `.github/workflows/animus-ci.yml`) include:
  - `gml_linter.py --validate-only` preflight
  - `yy_integrity.py` for `.yy/.yyp` JSON
  - `strategy_template_enforcer.py` to emit suggestions (report-only by default)
- Suggestions are written to `tools/.strategy_suggestions.json` and the workflows post PR comments when present.
- Resource ordering: keep `GOAP/GOAP.resource_order` in sync when renaming/moving scripts; `yy_integrity` warns when entries are missing.

### Where to look for examples
- Strategy template examples: `Animus_StrategyTemplates.gml` and usages in `GOAP/scripts/Animus_Action/*`.
- Planner reuse/invalidation: `GOAP/scripts/Animus_Planner/Animus_Planner.gml` → `should_reuse_plan`, `meta.referenced_keys`.
- Executor invariants/reservations: `GOAP/scripts/Animus_Executor/Animus_Executor.gml` (search for `reservation_bus`, `invariant_check`).

If anything here is unclear or you want this expanded into a PR checklist or quick-edit recipes (e.g., "how to convert an inline strategy to template"), say which part and I'll iterate.
