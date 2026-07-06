# Harness Protocol

Single source of truth for the `expo-launchpad` state machine: the `config.md`/`state.md`/`contract.md`
schemas, the generator/evaluator handoff layouts, the log table schemas, and the phase transition
table. Every skill cites this document instead of restating any schema. This is the **Phase A**
slice only — idea → playable app/game, ending at a human-review pause. The Phase B seam (deploy) is
noted at the end of §7 but not implemented here.

All files below live under a generated project's `docs/harness/` directory:

```
docs/harness/
├─ config.md
├─ state.md
├─ contract.md
├─ build-log.md
├─ pipeline-log.md
├─ specs/          # research spec, PRD
├─ plans/          # design doc
├─ handoff/        # round-N-gen.md
├─ feedback/       # round-N-qa.md
└─ screenshots/    # round-N-*.png
```

## 1. config.md Schema

YAML front matter written by the orchestrator at bootstrap and updated by later skills as identity
keys are decided (`plan` fills in `app_name`/`app_slug`/`bundle_id`/`orientation`).

```yaml
app_idea: ""              # the user's one-line pitch, or "" if not yet supplied
app_name: ""              # human-readable name, set by plan
app_slug: ""              # kebab-case identifier, set by plan
bundle_id: ""             # com.<company>.<id>, set by plan
kind: app                 # app | game
engine: skia              # skia — the only supported Phase A value; game only, ignored when kind: app
                          # (rnge reserved for a future release — not implemented in Phase A)
default_language: en      # BCP-47-ish language code for generated content
orientation: portrait     # portrait | landscape
strict_mode: false
max_rounds: 3
skip_research: false
auto_idea: false
auto_deploy: false
credentials_dir: ""       # placeholder only — Phase A never writes signing/store credentials here
# Deploy keys (ios/android signing, store metadata) are added by the future Phase B; Phase A never writes them.
```

- `bundle_id` is `com.<company>.<id>`, where `<id>` is `app_slug` with hyphens/underscores stripped,
  lowercased to `[a-z0-9]`. It must be byte-identical across `app.json` `ios.bundleIdentifier` and
  `android.package`.
- `kind: game` is the only case where `engine` is meaningful; Phase A ships `skia` only.
- No `admob` block exists in Phase A — monetization config is out of scope until Phase B.

## 2. state.md Schema

YAML front matter, read and rewritten by every skill on entry/exit. This is the only file the
orchestrator's dispatch loop consults to decide the next action.

```yaml
status: running            # running | paused | completed
current_phase: research    # research | plan | design | contract | generator | evaluator
current_round: 0           # generator/evaluator round counter, starts at 1 once generator begins
next_role: research        # the skill the orchestrator dispatches next
pause_reason: ""           # "" | rate_limit | manual_action | error
created_at: ""             # ISO 8601, set once at bootstrap
updated_at: ""             # ISO 8601, rewritten by every skill
resume_attempts: 0
checkpoint: ""             # "" | 6a | 6b | 6c — generator sub-phase re-entry marker
```

- `checkpoint` sub-phase ids are `6a`/`6b`/`6c` (not `5a`/`5b`/`5c`) and are only meaningful while
  `current_phase: generator`; a fresh round resets it to `""`.
- `pause_reason: manual_action` is the human-review gate after an evaluator PASS; `--resume` clears it.

## 3. contract.md Layout

Written by the contract skill once the PRD and design doc exist; the generator refuses to start
until `## Status: AGREED` is present.

```markdown
# Contract

## Mandatory Hard Gates

1. `tsc --noEmit` and `expo lint` return zero errors.
2. `jest` — all tests pass.
3. No TODO, stub, or placeholder in app/game logic (grep-checkable).
4. All tuning constants centralized in `config/gameConfig.ts` (game) / `config/appConfig.ts` (app) — no
   magic numbers in feature code.
5. Content (levels/enemies/screen data) is defined as data, not hardcoded.
6. Localization complete for all configured locales — no missing i18n keys.
7. Core loop/flow works end to end (game: start→play→win/lose→restart; app: the primary journey).
8. Runs on a simulator with zero crashes and zero console errors.

## Platform-Robustness Gates

See `docs/app-gotchas.md` R1–R11 for the full pattern set (audio, haptics, lifecycle, performance,
persistence, accessibility, build/platform). Each robustness gate listed there applies here as a
contract obligation.

## Functional Criteria

<5–10 criteria derived from the PRD, each verifiable by a specific command, screenshot, or named
file+test.>

## Status: AGREED
```

The **8 Mandatory Hard Gates** above are the verbatim block every other skill (contract, generator,
evaluator) copies or cites — do not restate them with different wording elsewhere.

## 4. handoff/round-N-gen.md

Written by the generator at the end of every round, one file per round (`round-1-gen.md`,
`round-2-gen.md`, ...).

```markdown
# Round <N> — Generator Handoff

## What Was Built

<summary of scaffolding/features/UI added this round>

## Contract Self-Assessment

| Criterion | Status | Evidence |
|---|---|---|
| Hard Gate 1 (tsc/lint) | ✅/❌ | <command output ref> |
| ... | | |

## Test Results

- `tsc --noEmit`: <pass/fail summary>
- `expo lint`: <pass/fail summary>
- `jest`: <pass/fail summary, test count>

## Environment

- `node`: <version>
- `expo`: <version>
- `npx expo --version`: <version>

## Known Issues

<anything the generator flags as unresolved or deferred, if any>
```

## 5. feedback/round-N-qa.md

Written by the evaluator at the end of every round, one file per round (`round-1-qa.md`,
`round-2-qa.md`, ...).

```markdown
# Round <N> — QA Feedback

## Verdict

PASS | FAIL

## Evidence

| Check | Result | Screenshot |
|---|---|---|
| Core loop / primary journey | ✅/❌ | docs/harness/screenshots/round-<N>-<name>.png |
| ... | | |

## Failed Criteria

<only present when Verdict is FAIL — the exact list of contract criteria that failed, each with a
one-line reason, for the next generator round to fix.>
```

## 6. Log Table Schemas

Two append-only tables, both under `docs/harness/`.

**`build-log.md`** — one row per generator/evaluator round.

| round | phase | timestamp | result | notes |
|---|---|---|---|---|
| 1 | generator | <ISO 8601> | handoff | <short note> |
| 1 | evaluator | <ISO 8601> | PASS/FAIL | <short note> |

**`pipeline-log.md`** — one row per phase transition (every skill appends on exit).

| timestamp | phase | event | next_role |
|---|---|---|---|
| <ISO 8601> | research | complete | plan |
| <ISO 8601> | contract | AGREED | generator |

## 7. Phase Transition Table

Phase A slice — the full set of transitions the orchestrator's dispatch loop drives:

| current_phase | event | → next_role |
|---|---|---|
| (init) | bootstrap | research |
| research | complete | plan |
| plan | complete | design |
| design | complete | contract |
| contract | AGREED | generator (current_round=1) |
| generator | handoff | evaluator |
| evaluator | PASS | paused (manual_action) unless `auto_deploy` |
| evaluator | FAIL | generator (current_round+1) |
| evaluator | max_rounds | forced judgment → same human-review gate |
| any | rate_limit | paused (rate_limit) |

> Phase B seam: on the human-review resume, a future Phase B dispatches `build`; Phase A instead goes
> evaluator-PASS → paused → (resume) → **status=completed via a terminal note** (no retro skill). The
> resume after PASS simply marks the run `completed` in Phase A — there is no deploy phase to hand off
> to yet.
