---
name: expo-harness-contract
description: Phase A contract — propose the 8 Mandatory Hard Gates, the Platform-Robustness Gates (R1–R11), and 5–10 Functional Criteria derived from the PRD; mark the contract AGREED (1-pass default, rigorous self-review in --strict) and advance the pipeline to generator.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---

# expo-harness-contract

Phase A, step 4 of the expo-harness pipeline. Reads the PRD, the design doc, and `config.md`,
proposes verifiable completion criteria (Mandatory Hard Gates + Platform-Robustness Gates +
Functional Criteria), and marks the contract AGREED before handing off to the generator.

All file schemas (`config.md`, `state.md`, `contract.md`) are defined in
`docs/harness-protocol.md` — refer to that document as the single source of truth. Do not redefine
schemas here.

---

## Input

### 1. Read `docs/harness/config.md`

Extract:

| Key | Use |
|---|---|
| `app_name` | Contract title header |
| `app_slug` | Used to identify the app/game |
| `kind` | `app` or `game` — selects which project directories the anti-stub grep and Hard Gate 4 target |
| `strict_mode` | If `true`, run `--strict` negotiation; if `false` (or absent), run default 1-pass |

If `config.md` does not exist, abort with:
`expo-harness-contract: docs/harness/config.md not found — run the orchestrator to bootstrap first.`

### 2. Read the latest PRD

Find the most recent file matching `docs/harness/plans/*-prd.md` (sort by filename descending,
take the first). Abort with a clear message if none exists.

### 3. Read the latest design doc

Find the most recent file matching `docs/harness/plans/*-design.md` (sort by filename descending,
take the first). Abort if none exists.

---

## Mandatory Hard Gates

These 8 criteria are non-negotiable and must appear verbatim in every `contract.md`. A FAIL on
any one results in an immediate FAIL verdict, regardless of other passing criteria.

> **Source:** `docs/harness-protocol.md` §3 — Mandatory Hard Gates block. Always cite; never
> restate differently.

1. `tsc --noEmit` and `expo lint` return zero errors.
2. `jest` — all tests pass.
3. No TODO, stub, or placeholder in app/game logic (grep-checkable).
4. All tuning constants centralized in `config/gameConfig.ts` (game) / `config/appConfig.ts` (app) — no magic numbers in feature code.
5. Content (levels/enemies/screen data) is defined as data, not hardcoded.
6. Localization complete for all configured locales — no missing i18n keys.
7. Core loop/flow works end to end (game: start→play→win/lose→restart; app: the primary journey).
8. Runs on a simulator with zero crashes and zero console errors.

Copy these 8 lines verbatim into the `## Mandatory Hard Gates` section of `contract.md`. Do not
paraphrase, reorder, or omit any gate.

## Platform-Robustness Gates

In addition to the 8 core gates above, every contract includes a `## Platform-Robustness Gates`
section requiring the patterns in `docs/app-gotchas.md` (cite it generally — this skill defines the
numbered gate wording below). These are mandatory:

- **R1 Audio safe**: every audio call is wrapped in try/catch (a missing asset never crashes);
  frequent SFX cycle through a small pool of pre-loaded `AudioPlayer` instances (not a new
  `createAudioPlayer` call per trigger); BGM stops on game-over, `AppState` background, and unmount.
- **R2 Haptics safe** (if haptics are used): a `haptics.ts` helper with a platform guard
  (`Platform.OS === 'ios' || 'android'`), a throttle, an `enabled` toggle persisted via
  `AsyncStorage`, and try/catch on every call — feature code never calls `Haptics.*` raw.
- **R3 Lifecycle (AppState)**: an `AppState.addEventListener('change', ...)` subscription pauses the
  render loop and audio on background/inactive and reverses on active; teardown cancels all
  timers/listeners including the `AppState` subscription itself; input is gated behind a `canInput`
  flag during the background→active transition.
- **R4 Performance**: no per-frame allocations in the Skia/`useFrameCallback` loop — `Skia.Paint`
  and other reusable instances are hoisted outside the loop, not recreated per frame.
- **R5 App branding**: a custom app icon + splash screen are generated (never the default Expo
  template art), the icon is opaque (no alpha channel), and the app display name is set to
  `app_name`.
- **R6 Native config**: the bundle id is byte-identical across `app.json` `ios.bundleIdentifier` and
  `android.package`; the orientation is locked natively to `config.orientation` via `app.json`
  `orientation` plus `expo-screen-orientation` (the unused orientation is removed, no launch
  rotate).
- **R7 Assets & CI**: the app ships every asset it references (no dangling asset paths — a missing
  asset is a runtime error / blank render); a `.github/workflows/ci.yml` running typecheck
  (`tsc --noEmit`), lint (`expo lint`), and `jest` on push/PR is present.
- **R8 Store graphics** — **deferred to Phase B** (Android hi-res icon/feature graphic, iOS
  localized screenshots are store-listing assets, out of scope for Phase A's playable-build gate).
- **R9 Durable save**: persistence goes through a `saveRepository.ts` that mirrors one JSON blob to
  both `expo-secure-store` (durable-first read) and `AsyncStorage` (cache), every call wrapped in
  try/catch — `AsyncStorage` alone is insufficient (it can be cleared by the OS).
- **R10 Accessibility & safety**: no effect flashes faster than 3×/second; OS Reduce Motion
  (`AccessibilityInfo.isReduceMotionEnabled()`) is read and damps shake/particle/flash effects;
  interactive controls are ≥44×44 pt with `accessibilityLabel`/`accessibilityRole` set (icon-only
  buttons especially).
- **R11 Test depth**: beyond `jest` merely passing, the app/game ships **≥3 unit tests** (real
  logic — score/spawn/difficulty/economy for a game, a service/state-layer function for an app),
  **≥1 component test** (`@testing-library/react-native` — a menu/overlay/screen renders and a
  button press fires its handler), and **≥1 Maestro flow** (the core loop / primary journey, boot
  to end).

---

## Functional Criteria

Per-app/game acceptance criteria derived from the PRD. Each criterion must be verifiable by one of:

- **Command** — a shell command whose exit code or output proves the criterion (e.g.,
  `grep -rn "TODO" app/ game/` returns no matches).
- **Screenshot** — a labelled screenshot that visually confirms the criterion.
- **Code path** — a named file + function/component that implements the behaviour, plus a test that
  exercises it.

### Writing Functional Criteria

Read the PRD sections carefully, branching on `kind`:

| PRD section (`kind: game`) | What to extract |
|---|---|
| §2 Core Loop | One criterion per loop step (each step must be observable) |
| §3 Mechanics | One criterion per mechanic; specify a measurable threshold |
| §6 Win/Lose Conditions | Explicit pass/fail states |
| §4 Content Metrics | Count targets (e.g. "≥ 3 enemy types defined in `data/`") |
| §5 Progression & Economy | Score increments, reward triggers |

| PRD section (`kind: app`) | What to extract |
|---|---|
| §2 Primary Journeys | One criterion per journey step (each step must be observable) |
| §3 Feature List | One criterion per MVP feature; specify a measurable threshold |
| §5 States | Loading/empty/error coverage per screen |
| §4 Data Model | Shape/type checks for persisted or fetched entities |
| §6 Navigation Map | Route reachability checks |

Criteria that are NOT verifiable (e.g. "the app feels polished") must be rewritten as observable
checks or removed. Every criterion that references a timing threshold must cite a concrete number
(e.g. "responds within 100 ms" not "responds quickly").

Aim for 5–10 Functional Criteria. More is not better — specificity is.

### Anti-stub rule

Before marking AGREED, run the grep scoped to the project directories this `kind` actually uses
(per the PRD §9 Project Structure):

```bash
# kind: game
grep -rniE "TODO|stub|placeholder" app/ game/ config/ data/ ui/ 2>/dev/null

# kind: app
grep -rniE "TODO|stub|placeholder" app/ components/ config/ data/ services/ state/ 2>/dev/null
```

If either command returns any output, the contract must NOT be marked AGREED. Remove or resolve
every stub before proceeding. At the point this skill runs (contract phase, before the generator has
written any code), an empty result is expected — the grep is re-run by the generator/evaluator at
the end of every round to guard against regressions.

---

## Negotiation

### Default mode (1-pass)

When `strict_mode` is `false` or absent:

1. Read the PRD and design doc.
2. Write `docs/harness/contract.md` with:
   - The 8 Mandatory Hard Gates verbatim (from `docs/harness-protocol.md` §3).
   - The Platform-Robustness Gates R1–R11 (R8 marked deferred to Phase B).
   - 5–10 Functional Criteria derived from the PRD.
3. Self-review each Functional Criterion for verifiability.
4. Mark the contract `## Status: AGREED` in the same pass.
5. Update `state.md` and hand off to the generator phase.

### --strict mode (rigorous self-review)

When `strict_mode: true` in `config.md`, or when the skill is invoked with `--strict`:

1. Write the initial `contract.md` (same as default, steps 1–3 above).
2. Perform a **second self-review pass** over every Functional Criterion, checking each one
   against all three of the following gates:
   - **Concrete verification method** — does the criterion name a specific shell command (with
     expected exit code or output), a labelled screenshot, or a named file + function/component +
     test? Vague language like "works correctly" or "looks good" must be rewritten with a
     measurable check.
   - **Concrete numbers** — every timing, count, or threshold must cite a real value (e.g.
     "responds within 100 ms", "≥ 3 enemy types", "score increments by 10 per obstacle"). Relative
     terms ("quickly", "several", "enough") must be replaced.
   - **Full PRD coverage** — confirm that every core loop step / primary journey step, mechanic /
     feature, win/lose condition / state, and content metric / data model entity from the PRD has
     at least one corresponding Functional Criterion.
3. If any criterion fails the second-pass check, revise it in-place before proceeding.
4. Self-mark `## Status: AGREED` and proceed (same `state.md` write as default mode).

> **Phase B note:** Phase B may reintroduce evaluator-side contract negotiation with a
> generator↔evaluator round-trip; Phase A uses rigorous self-review only.

In both modes the contract file must contain `## Status: AGREED` before the generator phase begins
coding.

---

## Output

### 1. Write `docs/harness/contract.md`

Use the layout defined in `docs/harness-protocol.md` §3:

```markdown
# Contract — <app_name>

## Mandatory Hard Gates

These criteria are non-negotiable. A FAIL on any one of these results in an immediate FAIL verdict,
regardless of other passing criteria.

1. `tsc --noEmit` and `expo lint` return zero errors.
2. `jest` — all tests pass.
3. No TODO, stub, or placeholder in app/game logic (grep-checkable).
4. All tuning constants centralized in `config/gameConfig.ts` (game) / `config/appConfig.ts` (app) — no magic numbers in feature code.
5. Content (levels/enemies/screen data) is defined as data, not hardcoded.
6. Localization complete for all configured locales — no missing i18n keys.
7. Core loop/flow works end to end (game: start→play→win/lose→restart; app: the primary journey).
8. Runs on a simulator with zero crashes and zero console errors.

## Platform-Robustness Gates

R1 Audio safe · R2 Haptics safe · R3 Lifecycle (AppState) · R4 Performance · R5 App branding ·
R6 Native config · R7 Assets & CI · R8 Store graphics (deferred to Phase B) · R9 Durable save ·
R10 Accessibility & safety · R11 Test depth — full definitions above; see `docs/app-gotchas.md` for
the underlying patterns.

## Functional Criteria

<5–10 criteria derived from the PRD, each verifiable by a specific command, screenshot, or named
file+test.>

## Status: AGREED
```

If `docs/harness/` does not exist, create it before writing.

### 2. Update `state.md`

Update `docs/harness/state.md` per the schema in `docs/harness-protocol.md` §2:

```yaml
status: running
current_phase: contract
next_role: generator
current_round: 1
updated_at: "<ISO-8601 UTC now>"
```

Leave all other keys unchanged. Use `Edit` for a targeted update.

Per `docs/harness-protocol.md` §7 (Phase Transition Table): the `contract → AGREED` event sets
`next_role: generator` and `current_round: 1`.

### 3. Append to `pipeline-log.md`

Append one row to `docs/harness/pipeline-log.md` per the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | contract | AGREED | generator |
```

---

## Error handling

- If the PRD is missing, abort with a clear message and set `state.md` to `status: paused`,
  `pause_reason: manual_action`.
- If the design doc is missing, abort with a clear message and set `state.md` to
  `status: paused`, `pause_reason: manual_action`.
- If `config.md` cannot be read, abort immediately (do not write partial output).
- In `--strict` mode, this skill self-marks AGREED after the rigorous second-pass review; there is
  no multi-round evaluator loop in Phase A. `max_rounds` applies only to the generator→evaluator
  cycle, not to contract negotiation.
