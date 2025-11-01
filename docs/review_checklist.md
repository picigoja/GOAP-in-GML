# Review Checklist (Animus)
- Logic: unreachable branches; undefined access; mismatched return types.
- Contracts: Planner/Agent/Executor boundaries; assert plan shape; explicit outcomes.
- Performance: hot loops; allocations; repeated lookups; missing reuse via `meta.referenced_keys`.
- Architecture: sensors vs memory vs executor responsibilities.
- Style: naming/brace/spacing; struct method style; no globals.
- Tooling: add/update Codex tasks if refactors are non-trivial.
