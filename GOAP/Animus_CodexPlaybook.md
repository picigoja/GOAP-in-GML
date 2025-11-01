# Animus Codex Playbook

This playbook collects ready-to-run Codex prompts for every Animus task defined in `/GOAP/Animus_CodexHelper.yaml`. Use it inside the Animus (GOAP-in-GML) repository to execute tasks reproducibly.
_Helper updated at: 2025-11-01T18:21:06Z_

## How to run a prompt from this playbook
1. Select the first queued task whose dependencies are satisfied, honoring priority -> dependencies_cleared -> id.
2. Copy the corresponding prompt block and execute exactly one task in the repository.
3. Update `/GOAP/Animus_CodexHelper.yaml`, append a log entry, and commit using the unattended policy template.

## Table of Contents
- [T01 — Repo hygiene & resource correctness](#T01)
- [T02 — API freeze & compatibility contract](#T02)
- [T03 — Finalize Strategy templates (R1)](#T03)
- [T04 — Error surfaces (R2)](#T04)
- [T05 — Referenced-keys audit (S2)](#T05)
- [T06 — Partial-plan handoff (S1)](#T06)
- [T07 — Serialization & snapshot hardening (Q8)](#T07)
- [T08 — Memory contract: debounce & metadata clarity](#T08)
- [T09 — Tooling polish: one true debug story](#T09)
- [T10 — Samples & docs](#T10)
- [T11 — Performance & determinism checks](#T11)
- [T12 — Packaging & versioning](#T12)
- [T13 — Release v1.0.0](#T13)

## Global Operating Rules
- Running order: follow priority -> dependencies_cleared -> id (selection order: priority, dependencies_cleared, id).
- Dependency chain: T02->T01, T03->T02, T04->T03, T05->T03, T06->T05, T12->T01, T12->T02, T12->T03, T12->T04, T12->T05, T12->T06, T12->T07, T12->T08, T12->T09, T12->T10, T12->T11, T13->T12.
- Allowed status transitions: queued->in_progress, in_progress->done, queued->blocked, blocked->queued.
- Commit message template: chore(animus): {task_id} {title} \n  \n {summary} \n  \n Acceptance: \n {acceptance_verification_bullets}.
- Proof policy: mark tasks done only after every acceptance item passes; record blocked_reason when blocked and append a detailed log entry.
- Determinism rules: honor Animus conventions (no wall clock or OS RNG, keep Animus_Core.assert/is_callable guards, avoid silent undefined returns).

<a id="T01"></a>
## T01 — Repo hygiene & resource correctness
Status: queued | Priority: 1 | Dependencies: (none) | Labels: packaging, project
Anchors:
- GOAP/GOAP.yyp
- GOAP/GOAP.resource_order

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Repo hygiene & resource correctness

CONTEXT
- Helper ID: T01
- Priority: 1
- Current status in helper: queued
- Dependencies: []
- Labels: ["packaging", "project"]
- Anchors (files/paths to touch or review):
  GOAP/GOAP.yyp
  GOAP/GOAP.resource_order

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Regenerate/fix GOAP.yyp and GOAP.resource_order to reference actual Animus_* scripts. Ensure .yy -> .gml pairs exist and remove legacy GOAP_* orphans.

ACCEPTANCE (must all pass)
- Fresh import (IDE 2024.13.1.193 / Runtime 2024.13.1.242) yields no missing resource prompts.
- Clean build with zero warnings.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T01
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T01
     - title: Repo hygiene & resource correctness
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T02"></a>
## T02 — API freeze & compatibility contract
Status: queued | Priority: 1 | Dependencies: T01 | Labels: api, docs, safety
Anchors:
- GOAP/scripts/Animus_Core/Animus_Core.gml
- GOAP/scripts/Animus_StrategyTemplates/Animus_StrategyTemplates.gml
- README.md

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
API freeze & compatibility contract

CONTEXT
- Helper ID: T02
- Priority: 1
- Current status in helper: queued
- Dependencies: ["T01"]
- Labels: ["api", "docs", "safety"]
- Anchors (files/paths to touch or review):
  GOAP/scripts/Animus_Core/Animus_Core.gml
  GOAP/scripts/Animus_StrategyTemplates/Animus_StrategyTemplates.gml
  README.md

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Choose: implement full promised GOAP_* aliases (Action, Goal, Belief, Planner, Memory) OR edit README to narrow promise. Standardize on Animus_Core.is_callable(...) across repo. Add Animus_Core.assert guards for shape-sensitive returns (executor/planner).

ACCEPTANCE (must all pass)
- Either GOAP_* aliases compile in a shim test OR README clearly documents deprecation/scope.
- No stray is_callable(...) uses outside Animus_Core.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T02
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T02
     - title: API freeze & compatibility contract
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T03"></a>
## T03 — Finalize Strategy templates (R1)
Status: queued | Priority: 1 | Dependencies: T02 | Labels: executor, strategies
Anchors:
- GOAP/scripts/Animus_StrategyTemplates/Animus_StrategyTemplates.gml
- GOAP/scripts/Animus_ActionStrategy/Animus_ActionStrategy.gml

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Finalize Strategy templates (R1)

CONTEXT
- Helper ID: T03
- Priority: 1
- Current status in helper: queued
- Dependencies: ["T02"]
- Labels: ["executor", "strategies"]
- Anchors (files/paths to touch or review):
  GOAP/scripts/Animus_StrategyTemplates/Animus_StrategyTemplates.gml
  GOAP/scripts/Animus_ActionStrategy/Animus_ActionStrategy.gml

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Lock Instant, Timed, Move templates ensuring get_expected_duration(), get_reservation_keys(), optional get_last_invariant_key(). No executor-side special cases.

ACCEPTANCE (must all pass)
- Sample actions using each template run through Executor without custom glue.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T03
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T03
     - title: Finalize Strategy templates (R1)
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T04"></a>
## T04 — Error surfaces (R2)
Status: queued | Priority: 1 | Dependencies: T03 | Labels: safety, devx
Anchors:
- GOAP/scripts/Animus_Executor/Animus_Executor.gml
- GOAP/scripts/Animus_Core/Animus_Core.gml

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Error surfaces (R2)

CONTEXT
- Helper ID: T04
- Priority: 1
- Current status in helper: queued
- Dependencies: ["T03"]
- Labels: ["safety", "devx"]
- Anchors (files/paths to touch or review):
  GOAP/scripts/Animus_Executor/Animus_Executor.gml
  GOAP/scripts/Animus_Core/Animus_Core.gml

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Replace silent/undefined returns with explicit outcomes or DEBUG asserts. Missing strategy methods emit actionable errors including the action name.

ACCEPTANCE (must all pass)
- Malformed strategies produce clear DEBUG errors; no silent failures.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T04
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T04
     - title: Error surfaces (R2)
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T05"></a>
## T05 — Referenced-keys audit (S2)
Status: queued | Priority: 2 | Dependencies: T03 | Labels: planner, executor, performance
Anchors:
- GOAP/scripts/Animus_Planner/Animus_Planner.gml
- GOAP/scripts/Animus_Executor/Animus_Executor.gml

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Referenced-keys audit (S2)

CONTEXT
- Helper ID: T05
- Priority: 2
- Current status in helper: queued
- Dependencies: ["T03"]
- Labels: ["planner", "executor", "performance"]
- Anchors (files/paths to touch or review):
  GOAP/scripts/Animus_Planner/Animus_Planner.gml
  GOAP/scripts/Animus_Executor/Animus_Executor.gml

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Planner surfaces meta.referenced_keys as array and set-map. Executor memory listener filters to those keys; coalesce rapid writes per tick.

ACCEPTANCE (must all pass)
- Large-scene test shows no spurious invalidations from unrelated keys.
- Touching a referenced key invalidates within one tick.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T05
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T05
     - title: Referenced-keys audit (S2)
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T06"></a>
## T06 — Partial-plan handoff (S1)
Status: queued | Priority: 2 | Dependencies: T05 | Labels: planner, executor
Anchors:
- GOAP/scripts/Animus_Planner/Animus_Planner.gml
- GOAP/scripts/Animus_Executor/Animus_Executor.gml

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Partial-plan handoff (S1)

CONTEXT
- Helper ID: T06
- Priority: 2
- Current status in helper: queued
- Dependencies: ["T05"]
- Labels: ["planner", "executor"]
- Anchors (files/paths to touch or review):
  GOAP/scripts/Animus_Planner/Animus_Planner.gml
  GOAP/scripts/Animus_Executor/Animus_Executor.gml

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
On budget exhaustion, Planner returns best partial with meta.is_partial=true and reason. Executor invalidates at partial end and requests replanning.

ACCEPTANCE (must all pass)
- Unreachable-goal scene advances via partials; no stalls.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T06
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T06
     - title: Partial-plan handoff (S1)
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T07"></a>
## T07 — Serialization & snapshot hardening (Q8)
Status: queued | Priority: 2 | Dependencies: (none) | Labels: executor, persistence, testing
Anchors:
- GOAP/scripts/Animus_Executor/Animus_Executor.gml

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Serialization & snapshot hardening (Q8)

CONTEXT
- Helper ID: T07
- Priority: 2
- Current status in helper: queued
- Dependencies: []
- Labels: ["executor", "persistence", "testing"]
- Anchors (files/paths to touch or review):
  GOAP/scripts/Animus_Executor/Animus_Executor.gml

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Lock executor.snapshot()/restore() shape; document plan identity remap. Add round-trip tests at start, mid-run, mid-reservation.

ACCEPTANCE (must all pass)
- Three deterministic replay tests pass with identical traces.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T07
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T07
     - title: Serialization & snapshot hardening (Q8)
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T08"></a>
## T08 — Memory contract: debounce & metadata clarity
Status: queued | Priority: 3 | Dependencies: (none) | Labels: memory, belief, testing
Anchors:
- GOAP/scripts/Animus_Belief/Animus_Belief.gml
- GOAP/scripts/Animus_Memory/Animus_Memory.gml

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Memory contract: debounce & metadata clarity

CONTEXT
- Helper ID: T08
- Priority: 3
- Current status in helper: queued
- Dependencies: []
- Labels: ["memory", "belief", "testing"]
- Anchors (files/paths to touch or review):
  GOAP/scripts/Animus_Belief/Animus_Belief.gml
  GOAP/scripts/Animus_Memory/Animus_Memory.gml

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Ensure Belief debounce respects memory._now(); document auto-clean semantics. Snapshot(include_metadata) deep-clones nested arrays/structs; add regression tests.

ACCEPTANCE (must all pass)
- Debounce demo: stable truth under rapid writes.
- Snapshot/restore of nested state matches JSON equality.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T08
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T08
     - title: Memory contract: debounce & metadata clarity
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T09"></a>
## T09 — Tooling polish: one true debug story
Status: queued | Priority: 3 | Dependencies: (none) | Labels: debug, tooling
Anchors:
- GOAP/scripts/Animus_Debug/Animus_Debug.gml
- GOAP/scripts/Animus_Executor/Animus_Executor.gml

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Tooling polish: one true debug story

CONTEXT
- Helper ID: T09
- Priority: 3
- Current status in helper: queued
- Dependencies: []
- Labels: ["debug", "tooling"]
- Anchors (files/paths to touch or review):
  GOAP/scripts/Animus_Debug/Animus_Debug.gml
  GOAP/scripts/Animus_Executor/Animus_Executor.gml

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Pick trace exposure: add executor.debug_trace_snapshot() OR refactor Animus_Debug to use executor.debug_json(). Unify playback/dump functions.

ACCEPTANCE (must all pass)
- Single call prints readable plan+playback without API mismatch.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T09
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T09
     - title: Tooling polish: one true debug story
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T10"></a>
## T10 — Samples & docs
Status: queued | Priority: 3 | Dependencies: (none) | Labels: docs, samples
Anchors:
- README.md
- samples/minimal/*
- samples/move/*

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Samples & docs

CONTEXT
- Helper ID: T10
- Priority: 3
- Current status in helper: queued
- Dependencies: []
- Labels: ["docs", "samples"]
- Anchors (files/paths to touch or review):
  README.md
  samples/minimal/*
  samples/move/*

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Provide Minimal (hunger → get food → eat) and Move-style navigation samples using templates. Update README Quickstart and add Migration Guide (GOAP_* → Animus_*).

ACCEPTANCE (must all pass)
- Paste-into-room samples run.
- Migration guide closes alias/contract gap.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T10
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T10
     - title: Samples & docs
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T11"></a>
## T11 — Performance & determinism checks
Status: queued | Priority: 4 | Dependencies: (none) | Labels: performance, determinism, testing
Anchors:
- bench/*.gml

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Performance & determinism checks

CONTEXT
- Helper ID: T11
- Priority: 4
- Current status in helper: queued
- Dependencies: []
- Labels: ["performance", "determinism", "testing"]
- Anchors (files/paths to touch or review):
  bench/*.gml

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Microbench (10 agents x 20 actions x 5 goals) with planner time budgets (1-5ms). Determinism: seed, run twice, byte-compare traces.

ACCEPTANCE (must all pass)
- Planner respects time budgets.
- Traces are identical across runs.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T11
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T11
     - title: Performance & determinism checks
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T12"></a>
## T12 — Packaging & versioning
Status: queued | Priority: 4 | Dependencies: T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11 | Labels: release
Anchors:
- CHANGELOG.md
- LICENSE

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Packaging & versioning

CONTEXT
- Helper ID: T12
- Priority: 4
- Current status in helper: queued
- Dependencies: ["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08", "T09", "T10", "T11"]
- Labels: ["release"]
- Anchors (files/paths to touch or review):
  CHANGELOG.md
  LICENSE

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Add CHANGELOG.md, LICENSE, semantic version tags. Tag v0.9.0 (Feature-Complete Beta).

ACCEPTANCE (must all pass)
- v0.9.0 installs cleanly; only minor issues remain.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T12
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T12
     - title: Packaging & versioning
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

<a id="T13"></a>
## T13 — Release v1.0.0
Status: queued | Priority: 5 | Dependencies: T12 | Labels: release
Anchors: (none listed)

```text
You are Codex working in the Animus (GOAP-in-GML) repository.

TASK
Release v1.0.0

CONTEXT
- Helper ID: T13
- Priority: 5
- Current status in helper: queued
- Dependencies: ["T12"]
- Labels: ["release"]
- Anchors (files/paths to touch or review): (none listed)

PROJECT CONVENTIONS (GML & Animus)
- IDE/Runtime: GameMaker IDE 2024.13.1.193, Runtime 2024.13.1.242
- GML coding conventions:
  - Variables snake_case; locals _snake_case
  - Constructors/functions PascalCase
  - Methods inside structs/classes: snake_case = function() { ... }
  - Brace style: same-line open; newline close
  - Minimize globals
- Animus contracts:
  - Primary APIs: Animus_*; GOAP_* only where shims exist
  - Determinism: no wall clock/OS RNG in strategies; executor PRNG + logical_time
  - Debug: #macro ANIMUS_DEBUG 1; Animus_Core.assert, Animus_Core.is_callable
  - Planner: A* with admissible heuristic; meta.referenced_keys (array + set)
  - Executor: start/update/stop; invariants; timeouts; reservations; snapshot/restore

OBJECTIVE
Freeze public contracts, fix blockers only, expand docs where questions repeat. Tag v1.0.0 with guarantees (determinism, reuse, partials, snapshot stability).

ACCEPTANCE (must all pass)
- No API churn since v0.9.0; projects built on v0.9.0 run without edits.

IMPLEMENTATION PLAN
1) Parse and load helper: /GOAP/Animus_CodexHelper.yaml
2) Set this task's status=in_progress; write meta.updated_at
3) Code changes:
   - For each anchor path above, enumerate surgical edits.
   - Follow GML conventions and Animus contracts strictly.
4) Build & lint:
   - Open in IDE 2024.13.1.193 / Runtime 2024.13.1.242
   - Compile with zero warnings; run any relevant unit or demo room
5) Verification:
   - Check each acceptance bullet and record evidence (brief)
   - If any fail, set status=blocked and set blocked_reason
6) Logging & commit:
   - Update /GOAP/Animus_CodexHelper.yaml:
     - status=done if all acceptance passed; else blocked with reason
     - Append log entry:
       - when: ISO8601 Z
       - task_id: T13
       - summary: one-line summary of changes
       - files_touched: list of paths
       - acceptance_verification: list of confirmations
   - Commit using commit_message_template from helper (if present), filling:
     - task_id: T13
     - title: Release v1.0.0
     - summary: one-paragraph summary
     - acceptance_verification_bullets: join from above

SAFETY & SCOPE GUARDRAILS
- Only change files listed in Anchors unless strictly necessary; if new files are created, add them to Anchors and rerun acceptance.
- Do not weaken runtime invariants or determinism guarantees.
- Prefer Animus_Core helpers over raw built-ins for callability or assertions.
- If the helper claims GOAP_* aliases that don't exist, either implement minimal shims or revise README as specified by this task's acceptance.

DELIVERABLE
- A list of concrete code edits (file, line anchor if feasible, before/after diff chunks).
- A short "post-change sanity checklist" tailored to this task.
```

## Appendix

### Glossary & References
- Animus modules: Planner, Executor, Memory, Belief, Action, Goal, Predicate, Sensor, SensorHub, StrategyTemplates, Debug
- Key file path patterns: `GOAP/scripts/Animus_*/Animus_*.gml`

### Running the unattended loop
1. Identify the next queued task with dependencies satisfied.
2. Execute the corresponding prompt and perform only scoped edits.
3. Verify acceptance, update helper status/log, and commit before proceeding to another task.
