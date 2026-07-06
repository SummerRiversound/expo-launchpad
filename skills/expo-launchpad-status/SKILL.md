---
name: expo-launchpad-status
description: Show the current expo-launchpad pipeline state — phase, round, next role, pause reason — read-only.
argument-hint: ""
allowed-tools: [Read, Bash]
---

# expo-launchpad-status

Read-only status reporter for the expo-launchpad pipeline. Reads `docs/harness/state.md` and
`docs/harness/pipeline-log.md` and prints a summary of the current pipeline state.

All file schemas are defined in `docs/harness-protocol.md` — refer to §2 (`state.md` schema) and
§6 (log table schemas) as the single source of truth. Do not redefine schemas here.

**This skill is strictly read-only. It must never modify `state.md`, `pipeline-log.md`, or any
other harness file, and takes no action beyond printing a report.**

---

## Input

`docs/harness/` lives at the **workspace root** — the directory the pipeline was invoked from —
for the entire pipeline, never inside the generated `<app_slug>/` project. Locate
`docs/harness/state.md` relative to the current working directory (the invocation dir), the same
convention every other phase skill uses.

If `docs/harness/state.md` does not exist, print:

```
No expo-launchpad run in this directory.
```

Then exit without error — do not create any file, do not treat this as a failure.

---

## Procedure

### 1. Read state.md

Read `docs/harness/state.md` and extract the following fields per the schema in
`docs/harness-protocol.md` §2:

- `status` — `running` | `paused` | `completed`
- `current_phase` — the currently executing (or last-active) phase
- `current_round` — integer round counter
- `next_role` — skill role that runs next
- `pause_reason` — `""` | `rate_limit` | `manual_action` | `error`
- `resume_attempts` — integer
- `checkpoint` — `""` | `6a` | `6b` | `6c`
- `updated_at` — ISO-8601 timestamp of last write

### 2. Read pipeline-log.md (if present)

If `docs/harness/pipeline-log.md` exists, read the last 5 rows (e.g. `tail -n 5
docs/harness/pipeline-log.md`) to give a recent event summary. If the file is absent or empty,
skip this section of the report.

### 3. Print status report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 expo-launchpad pipeline status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Status        : <status>
  Current phase : <current_phase>
  Round         : <current_round>
  Next role     : <next_role>
  Checkpoint    : <checkpoint, or "—" if blank>
  Resume attempts: <resume_attempts>
  Last updated  : <updated_at>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If `status` is `paused`, append:

```
  ⚠  Paused — reason: <pause_reason>
  Run /expo-launchpad --resume (or /expo-launchpad-resume) to continue.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If `status` is `completed`, append:

```
  Pipeline completed successfully.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If there are recent `pipeline-log.md` rows, append:

```
Recent events:
  <timestamp>  <phase>  <event>  <next_role/details>
  <timestamp>  <phase>  <event>  <next_role/details>
  <timestamp>  <phase>  <event>  <next_role/details>
```

---

## Constraints

- **Read-only**: this skill must never call `Write`, `Edit`, or any `Bash` command that modifies a
  file (`>`, `>>`, `rm`, `mv`, `sed -i`, etc.). It reads `state.md` and `pipeline-log.md` only.
- Do not modify `state.md` under any circumstances, including error paths.
- If `pipeline-log.md` is unreadable, skip it silently and note "(unavailable)" in the report
  instead of the recent-events section.
