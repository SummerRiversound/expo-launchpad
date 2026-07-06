---
name: expo-harness
description: Orchestrator — bootstrap an Expo (RN+TS) app/game pipeline (idea→playable) and dispatch each phase skill. Use when starting or continuing an expo-harness run.
argument-hint: "[idea] [--kind app|game] [--engine skia] [--strict] [--rounds N] [--skip-research] [--auto-idea] [--auto-deploy] [--resume]"
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill]
---

# expo-harness Orchestrator

This skill bootstraps and drives the Expo (React Native + TypeScript) app/game pipeline —
Phase A: idea → playable build, ending at a human-review pause. All file schemas (`config.md`,
`state.md`, `contract.md`, log tables) and the phase transition table are defined in
`docs/harness-protocol.md` — refer to that document as the single source of truth. Do not redefine
schemas here. Platform-robustness requirements the generator/evaluator enforce live in
`docs/app-gotchas.md`.

---

## Argument Parsing

Parse the invocation arguments before doing anything else.

| Argument | Config key (in `config.md`) | Default |
|---|---|---|
| `[idea]` | `app_idea` | optional — blank if omitted; research generates & recommends concepts from scratch |
| `--kind app\|game` | `kind` | `app` |
| `--engine skia` | `engine` | `skia` — only meaningful when `kind: game` |
| `--strict` | `strict_mode: true` | `false` |
| `--rounds N` | `max_rounds: N` | `3` |
| `--skip-research` | `skip_research: true` | `false` |
| `--auto-idea` | `auto_idea: true` | `false` |
| `--auto-deploy` | `auto_deploy: true` | `false` |
| `--resume` | (delegates to resume handler; see Resume section) | — |

**Guard:** if `--skip-research` is set AND no idea is given, abort immediately with:
`expo-harness: --skip-research needs an idea (nothing to build without research or an idea).`

Key-to-file mapping follows the `config.md` schema in `docs/harness-protocol.md` §1.

- `--kind` → `kind: app` or `kind: game`
- `--engine` → `engine: skia` (or an alternative); ignored by later skills unless `kind: game`
- `--strict` → `strict_mode: true`
- `--rounds N` → `max_rounds: N`
- `--skip-research` → `skip_research: true` — the research skill still runs; it decides internally
  how to honor the flag
- `--auto-idea` → `auto_idea: true`. No effect combined with `--skip-research` (which already takes
  the idea verbatim — nothing to select).
- `--auto-deploy` → `auto_deploy: true`. Affects how an evaluator PASS is resolved per §7 — the
  dispatch loop itself does not special-case this; it only ever reacts to `status`/`next_role`.
- `--resume` → skip bootstrap and the dispatch loop entirely; delegate straight to
  `expo-harness-resume` (see Resume)

**Language detection:** determine `default_language` from the language the user is conversing in
(a Korean request → `ko`, an English request → `en`). If there is no conversational signal yet (a
bare `/expo-harness` with no idea), fall back to the OS locale — run
`defaults read -g AppleLanguages 2>/dev/null || echo $LANG` and map the first locale (`ko*` → `ko`,
otherwise `en`). Only default to `en` if even that is unavailable.

---

## Bootstrap (First Run)

Bootstrap runs only when `docs/harness/state.md` does not yet exist.

### 1. Create directory tree

```
docs/harness/
docs/harness/handoff/
docs/harness/feedback/
docs/harness/specs/
docs/harness/plans/
```

### 2. Write `docs/harness/config.md`

Write the full schema from `docs/harness-protocol.md` §1, populating it from the parsed arguments:

- `app_idea` — from the positional argument, or `""` if none was given (blank is valid — research
  generates and recommends concepts). Do NOT abort on an empty idea (only `--skip-research` with a
  blank idea aborts, per the guard above).
- `app_name`, `app_slug`, `bundle_id` — leave `""`. The plan phase decides these once research
  confirms the concept.
- `kind`, `engine` — from `--kind`/`--engine` (defaults `app`/`skia`).
- `default_language` — detected per Argument Parsing above.
- `orientation` — `portrait` (default; the plan phase may revise it).
- `strict_mode`, `max_rounds`, `skip_research`, `auto_idea`, `auto_deploy` — from flags (defaults
  per the table above).
- `credentials_dir` — leave `""`. Never hard-code a company, developer, or signing identity here —
  Phase A collects no signing credentials at all; that is a future Phase B concern.

### 3. Write `docs/harness/state.md`

Write `state.md` per the schema in `docs/harness-protocol.md` §2. Initial values: `status: running`,
`current_phase: (init)`, `current_round: 0`, `next_role: research` (always `research` on first run,
per the §7 transition table), `pause_reason: ""`, `resume_attempts: 0`, `checkpoint: ""`, and
`created_at`/`updated_at` set to the current ISO-8601 UTC timestamp.

### 4. Append INIT row to `docs/harness/pipeline-log.md`

Create `pipeline-log.md` if absent and append, following the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | (init) | bootstrap | research |
```

---

## Dispatch Loop

After bootstrap (or immediately, on a non-first run without `--resume`), enter the dispatch loop.

### Reading `next_role`

Read `docs/harness/state.md` and extract `status` and `next_role`.

- If `status: completed` — print a completion summary and exit.
- If `status: paused` — print `pause_reason` and any pending manual steps, then instruct the user to
  run with `--resume`. Do not continue automatically.

### Dispatch

Otherwise, invoke the phase skill for `next_role`:

```
Skill("expo-harness-<next_role>")
```

Valid `next_role` values and the skill each dispatches to, per the transition table in
`docs/harness-protocol.md` §7:

| next_role | Skill invoked |
|---|---|
| `research` | `expo-harness-research` |
| `plan` | `expo-harness-plan` |
| `design` | `expo-harness-design` |
| `contract` | `expo-harness-contract` |
| `generator` | `expo-harness-generator` |
| `evaluator` | `expo-harness-evaluator` |

Each phase skill is responsible for updating `state.md` (including advancing `next_role`) before
returning, following the transition rules in `docs/harness-protocol.md` §7.

After each skill returns, re-read `state.md` and verify that either `updated_at` changed or
`next_role` advanced compared to the values before dispatch. If neither changed, abort immediately
with: `expo-harness: phase skill \`<role>\` returned without updating state.md — halting to avoid a
redispatch loop.`

Then repeat the dispatch check. Continue until:
- `status: completed` — print a completion summary and exit.
- `status: paused` — print `pause_reason` and instruct the user to run with `--resume`, then exit.

---

## Resume

If `--resume` is passed as an argument, first verify that `docs/harness/state.md` exists. If it
does not exist, abort with: "Nothing to resume — no state.md found. Run without --resume to start
a new pipeline."

Otherwise, skip all bootstrap and dispatch logic and delegate immediately to the resume skill:

```
Skill("expo-harness-resume")
```

`expo-harness-resume` is responsible for reading `state.md`, incrementing `resume_attempts`,
restoring `status: running`, and re-entering the dispatch loop.

Do not attempt to read or modify `state.md` before delegating to the resume skill.

---

## Error Handling

- If `docs/harness/config.md` is missing on a non-first run (i.e. `state.md` exists but
  `config.md` does not), abort with a clear error message — do not attempt to reconstruct it.
- If an invoked phase skill exits with an error, or sets `status: paused` with
  `pause_reason: error`, stop the loop and report the failure to the user.
- If `next_role` holds a value outside the known set (`research`, `plan`, `design`, `contract`,
  `generator`, `evaluator`), abort with an "unknown next_role" error so the user can investigate
  `state.md`.
