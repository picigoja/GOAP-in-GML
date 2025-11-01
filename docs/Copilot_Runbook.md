## Copilot Runbook for Animus

### Copilot PR Review
- Add **Copilot** as a reviewer on PRs. It will summarize diffs and flag issues.
- Reference `docs/review_checklist.md` from the PR body so Copilot picks up constraints.

### Copilot Chat (repo scope)
- In VS Code, build the workspace index, then use `@workspace` queries like:
  - `@workspace Audit for logic errors and undefined returns. Output file:line + minimal diffs. Respect Animus conventions.`
  - `@workspace Find hot loops in Step/Alarm handlers that allocate every frame; propose safe caching in GML with diffs.`
  - `@workspace Identify any planner calls missing the memory param. Show one-line fixes.`

### Guardrails
- Copilot proposes file renames? Confirm the `.yy` links and `GOAP.resource_order` impacts manually.
- Prefer minimal diffs; large refactors go through Codex tasks in `GOAP/Animus_CodexPlaybook.md`.
