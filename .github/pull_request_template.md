## Summary
What this PR changes and why.

## Animus/GML Review Checklist
- [ ] Naming/style matches repo rules (snake_case vars, PascalCase constructors, brace/spacing).
- [ ] No globals introduced; locals where possible.
- [ ] Planner call signature correct: `plan(agent, goals_to_check, last_goal, memory)`.
- [ ] No silent returns; explicit outcomes for strategies/executor paths.
- [ ] No legacy plan containers reintroduced; using canonical plan struct.
- [ ] Hot loops avoid per-step allocations; obvious caches applied.
- [ ] Tests/manual steps: how to repro & observe (e.g., `Animus_Debug.dump_plan`).
