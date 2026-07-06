---
name: expo-harness-resume
description: Resume a paused expo-harness run — finalize the post-evaluator-PASS human-review gate as completed, or restore status: running and redispatch the orchestrator.
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, Skill]
---

# expo-harness-resume

Resume handler for the expo-harness pipeline. Reads `docs/harness/state.md`, decides whether the
paused run is the Phase A terminal human-review gate or an ordinary pause, and either finalizes the
run as `completed` or restores `status: running` and re-enters the orchestrator's dispatch loop.

All file schemas (`state.md`, `pipeline-log.md`) and the state transition rules are defined in
`docs/harness-protocol.md` — refer to §2 (`state.md` schema) and §7 (Phase Transition Table,
including the Phase B seam note) as the single source of truth. Do not redefine schemas here.

`docs/harness/` lives at the **workspace root** — the directory the pipeline was invoked from —
for the entire pipeline, never inside the generated `<app_slug>/` project. This skill reads and
writes `docs/harness/state.md` and `docs/harness/pipeline-log.md` relative to the current working
directory (the invocation dir), the same convention used by every other phase skill.

---

## Input

Read `docs/harness/state.md`. If it does not exist, abort with:

```
Nothing to resume — no state.md found. Run without --resume to start a new pipeline.
```

Extract per the schema in `docs/harness-protocol.md` §2: `status`, `current_phase`,
`current_round`, `next_role`, `pause_reason`, `resume_attempts`, `checkpoint`, `created_at`,
`updated_at`.

- If `status: running` — print `expo-harness-resume: pipeline is already running (next_role:
  <next_role>). No resume needed.` and exit.
- If `status: completed` — print `expo-harness-resume: pipeline is already completed. Nothing to
  resume.` and exit.
- If `status` is anything other than `paused`/`running`/`completed`, abort with:
  `expo-harness-resume: unexpected status "<value>" in state.md — inspect docs/harness/state.md
  manually.`

Otherwise (`status: paused`), continue below.

---

## Which pause is this?

Per `docs/harness-protocol.md` §7, `evaluator | PASS | paused (manual_action) unless auto_deploy`
is the **only** transition in Phase A that pauses the pipeline for a human to approve finished
work — `expo-harness-evaluator` writes this exact combination on a PASS:
`current_phase: evaluator`, `next_role: evaluator`, `pause_reason: manual_action`. Every other
`pause_reason: manual_action` write in this pipeline (research's unresolved clone-avoidance check,
plan's unresolved clone signal, design's missing PRD, contract's missing PRD/design doc,
generator's missing prior-round feedback) leaves `current_phase` at that skill's own phase, never
`evaluator`, so the two cases never collide.

- **Terminal case** — `current_phase: evaluator` AND `pause_reason: manual_action` AND
  `next_role: evaluator`: the post-evaluator-PASS human-review gate. Handle per **Terminal case**
  below.
- **Otherwise** — any other paused state (a manual_action pause recorded by research/plan/design/
  contract/generator, or the `rate_limit`/`error` values reserved by the §2 schema): the pipeline
  just needs to pick back up where it left off. Handle per **Otherwise** below.

---

## Terminal case: finalize as completed

Phase A ends at idea → playable build; it has no deploy skills (no admob/build/store submission)
yet, per `docs/harness-protocol.md` §7's Phase B seam note. So a resume of the post-PASS
human-review gate does not dispatch a next phase — it finalizes the run.

This skill's `allowed-tools` does not include `AskUserQuestion`, so it does not re-prompt for
approval. `expo-harness-evaluator` already told the user, at pause time, to inspect
`docs/harness/screenshots/` and `docs/harness/feedback/round-<N>-qa.md` and only run
`--resume`/`expo-harness-resume` "when satisfied" — the user's explicit invocation of this skill
**is** that approval. Print:

```
expo-harness-resume: treating this --resume invocation as your approval of the build reviewed at
the evaluator PASS gate (per the prompt printed when it paused). Finalizing the run as completed.
```

### 1. Update state.md

Use a single **Edit** call:

```yaml
status: completed
next_role: ""
pause_reason: ""
resume_attempts: <previous_value + 1>
updated_at: "<ISO-8601 UTC now>"
```

Leave `current_phase`, `current_round`, `created_at`, and `checkpoint` unchanged. `next_role` is
cleared for the same reason the evaluator clears it on its `auto_deploy` completion path:
`completed` is terminal regardless of what `next_role` holds.

### 2. Append to pipeline-log.md

Append one row per the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | evaluator | complete | resume_attempts=<new_value>; finalized via --resume (post-PASS human review) |
```

### 3. Print a completion summary

```
expo-harness pipeline complete.
The build passed QA and has been approved. See docs/harness/feedback/ for the full QA record.
```

Do not dispatch any skill in this branch — there is nothing left to run.

---

## Otherwise: restore running and redispatch

### 1. Update state.md

Use a single **Edit** call:

```yaml
status: running
pause_reason: ""
resume_attempts: <previous_value + 1>
updated_at: "<ISO-8601 UTC now>"
```

Leave `current_phase`, `current_round`, `next_role`, `created_at`, and `checkpoint` unchanged —
`next_role` still points at whichever phase skill needs to (re)run; that skill is responsible for
picking up from wherever it left off.

Both `status: running` and `pause_reason: ""` must be written in the same `Edit` call.

### 2. Append to pipeline-log.md

Append one row per the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | <current_phase> | resume | resume_attempts=<new_value>; was paused (pause_reason=<value>) |
```

### 3. Redispatch

Delegate back to the orchestrator so it re-reads `next_role` and continues the dispatch loop:

```
Skill("expo-harness")
```

Never dispatch before `state.md` has been successfully updated to `status: running` with
`pause_reason: ""` — dispatch is the last step.

---

## Error handling

- If `state.md` becomes unreadable mid-execution (e.g. concurrent write), abort immediately and do
  not write partial state changes.
- If the `Edit` call to `state.md` fails, abort and do not append to `pipeline-log.md` or dispatch
  anything.
- `expo-harness`'s own dispatch loop validates `next_role` against the known role set and reports
  an "unknown next_role" error if it is invalid — this skill does not duplicate that check.
