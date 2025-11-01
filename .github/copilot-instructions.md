## Quick orientation for AI coding agents

Animus is a GOAP (Goal-Oriented Action Planning) framework implemented in GameMaker Language (GML). This file gives the minimal, actionable knowledge an AI coding agent needs to be productive here.

Core idea: planning data (Beliefs, Actions, Goals) is declarative. The runtime (Planner, Memory, Executor, Strategies) performs deterministic planning and execution using those records.

Key files to inspect (start here):
- `GOAP/GOAP.yyp` — GameMaker project file (CI checks JSON integrity).
- `GOAP/scripts/Animus_Planner/Animus_Planner.gml` — A* planner, heuristics, plan reuse (`meta.referenced_keys`).
- `GOAP/scripts/Animus_Memory/Animus_Memory.gml` — authoritative state store with snapshot/dirty tracking.
- `GOAP/scripts/Animus_Executor/Animus_Executor.gml` — executor, reservation bus, deterministic RNG.
- `Animus_StrategyTemplates.gml` — ready-made strategy factories (Strategy_Instant, Strategy_Timed, etc.).

Essential developer workflows (run these during edits/PRs):
- Validate linter config (CI preflight):
  `python tools/gml_linter.py --validate-only`
- Run full GML lint rules locally:
  `python tools/gml_linter.py`
- Validate `.yy`/`.yyp` JSON integrity:
  `python tools/yy_integrity.py`
- Emit strategy suggestions (enforcer):
  `python tools/strategy_template_enforcer.py --verbose`  # writes `tools/.strategy_suggestions.json`

Project-specific conventions and contracts (do not change lightly):
- Prefer `Animus_*` APIs; legacy `GOAP_*` aliases exist for compatibility in the short term (`GOAP/scripts/Animus_Core/Animus_Core.gml`).
- Strategy contract (factory must produce a struct exposing):
  - Required: `start(context)`, `update(context, dt)`, `stop(context, reason)`, `invariant_check(context)`
  - Optional: `get_expected_duration`, `get_reservation_keys`, `get_last_invariant_key`
  See `Animus_StrategyTemplates.gml` for canonical implementations.
- Planner contract: `planner.plan(...)` → return plan struct or `undefined`. Call `Animus_Core.assert_plan_shape(plan)` after planner calls.
- Determinism rule: avoid wall-clock APIs and OS RNG in planner/strategies. Use executor `logical_time` and provided PRNG.
- GameMaker JSON rules: `.yy` and `.yyp` are strict JSON — avoid trailing commas. `yy_integrity.py` enforces this.

Integration points and CI behavior:
- CI workflow runs the linter, `yy_integrity`, and strategy enforcer (see `.github/workflows/animus-ci.yml`).
- `tools/.strategy_suggestions.json` is produced by `strategy_template_enforcer.py` and read by CI; PRs touching strategies may receive suggestions.
- Keep `GOAP/GOAP.resource_order` in sync when moving/renaming scripts to avoid missing-resource CI failures.

Quick examples / places to edit safely:
- To add a new action strategy, add a factory in `Animus_StrategyTemplates.gml` and ensure it returns the required methods.
- To change planner heuristics, edit `Animus_Planner.gml` and validate plan shapes via `Animus_Core.assert_plan_shape` in unit-like smoke runs.

Checklist for PRs (minimal):
1. Run `python tools/gml_linter.py --validate-only` and fix warnings.
2. Run `python tools/yy_integrity.py` if you touched resource/yy files.
3. Run `python tools/strategy_template_enforcer.py --verbose` if you changed strategies; include relevant suggestions in PR description if applicable.
4. Ensure you used `Animus_*` APIs instead of `GOAP_*` for new code.

If anything is missing or you want this expanded into a short edit recipe (e.g., "convert inline strategy → template"), tell me which recipe and I'll add it.
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
- GML truth source / manual for generative models: the repository `Git-Fg/GameMaker-Manual-Markdown_4GenerativeAI` is the canonical reference for GML language details and engine semantics. For any LM-driven edits, prefer examples and idioms from that manual and cite it in suggestions.

### Where to look for examples
- Strategy template examples: `Animus_StrategyTemplates.gml` and usages in `GOAP/scripts/Animus_Action/*`.
- Planner reuse/invalidation: `GOAP/scripts/Animus_Planner/Animus_Planner.gml` → `should_reuse_plan`, `meta.referenced_keys`.
- Executor invariants/reservations: `GOAP/scripts/Animus_Executor/Animus_Executor.gml` (search for `reservation_bus`, `invariant_check`).

If anything here is unclear or you want this expanded into a PR checklist or quick-edit recipes (e.g., "how to convert an inline strategy to template"), say which part and I'll iterate.
