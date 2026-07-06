---
name: expo-harness-evaluator
description: Phase A, step 6 — skeptical QA. Run the app, watch it, then judge against the contract. Default = functional check; --strict adds quality scoring and an edge-case sweep.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep]
---

# expo-harness-evaluator

Phase A, step 6 of the expo-harness pipeline. Skeptical QA gate that decides PASS or FAIL against
the negotiated contract. Default mode runs the functional check (6.1) only; `--strict` adds
quality scoring (6.2) and an agent-team edge-case sweep (6.3).

All file schemas (`config.md`, `state.md`, `contract.md`, `handoff/round-N-gen.md`,
`feedback/round-N-qa.md`, `build-log.md`/`pipeline-log.md`) and the phase transition table are
defined in `docs/harness-protocol.md` — that document is the single source of truth (§2 for
`state.md`; §3 for `contract.md`; §4 for handoff layout; §5 for feedback layout; §6 for log
schemas; §7 for the `evaluator → generator` / `evaluator → paused` transitions). Do not redefine
schemas here. Every platform-robustness pattern (R1–R11) is defined once in `docs/app-gotchas.md`
— cite it; do not restate the patterns.

---

## Critical Rule

**"Run the code, see the app, then judge." Never PASS on code review alone. Execute commands,
launch the app on a simulator, drive the core flow, capture and study screenshots. Stub detected
= automatic FAIL, no exceptions.**

---

## Setup — Read Inputs

### Workspace root vs. project directory

`docs/harness/` lives at the **workspace root** (the directory the pipeline was invoked from) for
the entire pipeline — it is never inside the generated project. Before any other step, capture the
workspace root once:

```bash
ROOT="$(pwd)"
```

From this point on, **every harness file** (`state.md`, `config.md`, `contract.md`, `handoff/*`,
`feedback/*`, `pipeline-log.md`, `build-log.md`, `screenshots/*`) is read/written at the
root-absolute path `"$ROOT/docs/harness/..."` — never a path relative to whatever directory the
shell happens to be in at the time. `ROOT` is fixed once, the same way `<app_slug>` and `<N>` are:
treat it as a value substituted verbatim into every command below, not a live shell variable that
needs to survive between separate tool invocations.

The generated Expo project lives in its own subdirectory, `"$ROOT/<app_slug>/"`. **Only**
build/test/run commands (`tsc --noEmit`, `expo lint`, `jest`, `expo run:ios`, Maestro) `cd` into
`<app_slug>/` — that `cd` is scoped to those commands only and never affects where harness files
are written. Never write into `<app_slug>/docs/harness/`.

Before any check, load:

1. `"$ROOT/docs/harness/state.md"` — extract `current_round` (integer ≥ 1) and confirm
   `next_role: evaluator`.
2. `"$ROOT/docs/harness/config.md"` — extract `app_slug`, `kind`, `strict_mode` (bool),
   `max_rounds` (int), `auto_deploy` (bool), `default_language`.
3. `"$ROOT/docs/harness/contract.md"` — parse `## Mandatory Hard Gates`,
   `## Platform-Robustness Gates`, and `## Functional Criteria`. Confirm `## Status: AGREED` is
   present; if missing, abort with:
   `expo-harness-evaluator: contract not AGREED — run expo-harness-contract first`.
4. `"$ROOT/docs/harness/handoff/round-<N>-gen.md"` (where N = `current_round`) per protocol §4. If
   the file is missing, abort with:
   `expo-harness-evaluator: handoff for round <N> not found — generator must run first`.

---

## 6.1 Functional Check (default — always runs)

Run every step in order, from `"$ROOT/<app_slug>/"` unless noted. A failure on any
**Mandatory Hard Gate** from `contract.md` is an immediate FAIL — do not skip remaining steps
(finish collecting evidence), but the verdict is already decided.

### Step 1 — Static analysis + lint

```bash
cd <app_slug>
npx tsc --noEmit
npx expo lint
```

Required result: **zero errors** from both. This is a Mandatory Hard Gate (contract gate 1).

### Step 2 — Tests

```bash
cd <app_slug>
npx jest
```

Required result: **zero failures**. Capture the full output, including test count. This is a
Mandatory Hard Gate (contract gate 2).

### Step 3 — Stub / TODO grep (dir-agnostic)

Run from the workspace root, scoped to the whole project tree so nothing added in a later
sub-phase is missed:

```bash
grep -rniE "TODO|stub|placeholder" <app_slug>/ --include='*.ts' --include='*.tsx' \
  | grep -vE 'node_modules|/\.expo/|/dist/'
```

Any match is an **automatic FAIL**. No exceptions (contract gate 3). Record each match with file
path, line number, and the matched text.

### Step 4 — Magic-number grep (outside `config/`)

```bash
grep -rnE "[0-9]{3,}\.?[0-9]*" <app_slug>/ --include='*.ts' --include='*.tsx' \
  | grep -vE 'node_modules|/\.expo/|/dist/|/config/'
```

Any tuning-shaped number (3+ digits) outside `config/gameConfig.ts` / `config/appConfig.ts` is a
Hard Gate failure (contract gate 4). Exclude clearly-justified non-tuning constants (e.g. HTTP
status codes) if commented; document any exclusion in the feedback file.

### Step 5 — Content-as-data check (Hard Gate 5)

Run from the workspace root, same scope as Steps 3/4. Confirm content catalogs exist under
`data/`, then scan the logic directories for inline literal content that should live in one of
those catalogs instead (generator 6b.3 / 6b.1 puts levels/enemies/waves and typed data models under
`data/` for exactly this reason — see `docs/harness-protocol.md` §3):

```bash
ls <app_slug>/data/*.ts >/dev/null 2>&1 || echo "FAIL: no content catalogs under data/ (Hard Gate 5)"
# kind: game — flag inline arrays of >=3 object-literal entries (entity/level/wave data) in game/ logic
grep -rlE "=\s*\[" <app_slug>/game/ 2>/dev/null | grep -v node_modules | while read -r f; do
  n=$(awk '/=[[:space:]]*\[/,/\];/' "$f" | grep -c "{")
  [ "${n:-0}" -ge 3 ] && echo "FAIL: $f — inline array with $n object-literal entries; level/enemy/wave data belongs in data/, not game/ logic"
done
# kind: app — flag inline arrays of >=3 object-literal entries in screen/feature code outside data/
grep -rlE "=\s*\[" <app_slug>/app/ <app_slug>/services/ <app_slug>/state/ 2>/dev/null | grep -v node_modules | while read -r f; do
  n=$(awk '/=[[:space:]]*\[/,/\];/' "$f" | grep -c "{")
  [ "${n:-0}" -ge 3 ] && echo "FAIL: $f — inline array with $n object-literal entries; screen/list data belongs in data/, not feature code"
done
```

A missing `data/` catalog, or a logic file with content hardcoded inline instead of pulled from a
`data/` catalog, is a Hard Gate failure (contract gate 5). The two checks are complementary — a
project can pass one and fail the other (e.g. an empty `data/` folder with all content still
hardcoded in `game/`).

### Step 6 — i18n key-parity check

The generator centralizes every locale's strings in a single `resources` object in
`i18n/i18n.ts` (`templates/i18n.ts.template`) — there are no per-locale files to diff. Compare
each locale's key set directly out of that object:

```bash
node -e "
const fs = require('fs');
const src = fs.readFileSync('i18n/i18n.ts', 'utf8');
const blocks = [...src.matchAll(/(\w+):\s*\{\s*translation:\s*\{([^}]*)\}\s*\}/gs)];
if (blocks.length === 0) { console.log('NO LOCALES FOUND'); process.exit(1); }
const keysets = {};
for (const [, locale, body] of blocks) keysets[locale] = new Set([...body.matchAll(/(\w+)\s*:/g)].map(m => m[1]));
const all = new Set([].concat(...Object.values(keysets).map(s => [...s])));
let bad = false;
for (const [locale, keys] of Object.entries(keysets)) {
  const missing = [...all].filter(k => !keys.has(k));
  if (missing.length) { console.log('MISSING in ' + locale + ':', missing); bad = true; }
}
process.exit(bad ? 1 : 0);
console.log('i18n OK', Object.keys(keysets));
"
```

Missing keys in any configured locale (`default_language` and `en` when different) is a Hard Gate
failure (contract gate 6).

### Step 7 — Platform-Robustness Gates (R1–R11)

Verify the `## Platform-Robustness Gates` from `contract.md` / `docs/app-gotchas.md`. Run from
inside `<app_slug>/`:

```bash
# R1 audio (kind:game, or any project using expo-audio): pooled + guarded
ls game/systems/audioSystem.ts 2>/dev/null && grep -c "createAudioPlayer" game/systems/audioSystem.ts
grep -n "try" game/systems/audioSystem.ts 2>/dev/null | grep -q . || echo "CHECK: audio calls not wrapped in try/catch"
grep -rn "AppState" game/systems/audioSystem.ts game/scene/*.tsx 2>/dev/null || echo "CHECK: BGM stop on background/unmount not found"
# R2 haptics (if a haptics helper exists)
ls game/systems/haptics.ts 2>/dev/null && grep -nE "Platform\.OS|enabled|try" game/systems/haptics.ts \
  || echo "CHECK: haptics helper missing or unguarded"
# R3 lifecycle
grep -rn "AppState.addEventListener" . --include='*.ts' --include='*.tsx' | grep -v node_modules || echo "FAIL: no AppState lifecycle subscription"
# R4 performance: flag construction inside the per-frame callback
grep -rl "useFrameCallback" game/ 2>/dev/null | while read -r f; do
  awk '/useFrameCallback/,/^\}\);/' "$f" | grep -nE "new [A-Z]|Skia\.Paint\(\)" \
    && echo "CHECK: $f — possible per-frame allocation inside useFrameCallback"
done
# R5 branding: custom icon, not the default Expo template art
ls scripts/gen-icon.js 2>/dev/null || echo "CHECK: no scripts/gen-icon.js — confirm icon/splash are sourced custom art, not defaults"
sips -g hasAlpha assets/images/icon.png 2>/dev/null | grep -qi "hasAlpha: no" || echo "FAIL: icon may have alpha (App Store rejects)"
jq -r '.expo.name' app.json | grep -qivE '^(app-slug|<app_slug>)$' || echo "FAIL: display name still reads as the slug"
# R6 bundle id identical across platforms + orientation lock
IOSID=$(jq -r '.expo.ios.bundleIdentifier' app.json)
ANDID=$(jq -r '.expo.android.package' app.json)
echo "iOS=$IOSID  Android=$ANDID  (must be byte-identical == config.bundle_id)"
{ [ -n "$IOSID" ] && [ "$IOSID" != "null" ] && [ "$IOSID" = "$ANDID" ]; } || echo "FAIL: iOS/Android bundle id differ or unset"
echo "$IOSID" | grep -qE '^[a-z0-9.]+$' || echo "FAIL: bundle id has uppercase/_/- (must be lowercase [a-z0-9.])"
grep -q "expo-screen-orientation" package.json || echo "FAIL: expo-screen-orientation not installed"
grep -rq "ScreenOrientation.lockAsync" app/_layout.tsx || echo "FAIL: orientation not locked at runtime"
# R7 assets & CI
node -e "
const fs = require('fs');
const e = JSON.parse(fs.readFileSync('app.json', 'utf8')).expo;
const p = [e.icon, e.android && e.android.adaptiveIcon && e.android.adaptiveIcon.foregroundImage, e.splash && e.splash.image].filter(Boolean);
const missing = p.filter(x => !fs.existsSync(x.replace(/^\.\//, '')));
console.log(missing.length ? 'MISSING ASSETS: ' + missing.join(', ') : 'assets OK');
process.exit(missing.length ? 1 : 0);
"
ls .github/workflows/ci.yml >/dev/null 2>&1 || echo "FAIL: no CI workflow"
# R8 store graphics — deferred to Phase B (contract.md marks it deferred); skip
# R9 durable save
grep -q "expo-secure-store" package.json && grep -q "@react-native-async-storage/async-storage" package.json \
  || echo "FAIL: durable-save deps missing"
ls data/saveRepository.ts 2>/dev/null || echo "FAIL: no data/saveRepository.ts (durable save layer)"
grep -q "SecureStore" data/saveRepository.ts 2>/dev/null && grep -q "AsyncStorage" data/saveRepository.ts 2>/dev/null \
  || echo "FAIL: saveRepository.ts missing a durable tier"
# R10 accessibility & safety
grep -rq "accessibilityLabel" app/ components/ ui/ 2>/dev/null || echo "FAIL: no accessibilityLabel on controls"
grep -rq "isReduceMotionEnabled" . --include='*.ts' --include='*.tsx' 2>/dev/null | grep -v node_modules || echo "CHECK: Reduce Motion not read"
# R11 test depth: >=3 unit + >=1 component (RTL) + >=1 Maestro flow
UNIT=$(find . -name "*.test.ts" -not -path "*/node_modules/*" | wc -l | tr -d ' ')
COMPONENT=$(find . -name "*.test.tsx" -not -path "*/node_modules/*" | wc -l | tr -d ' ')
[ "${UNIT:-0}" -ge 3 ] || echo "FAIL: fewer than 3 unit test files (R11 needs >=3)"
[ "${COMPONENT:-0}" -ge 1 ] || echo "FAIL: no component test (R11 needs >=1)"
grep -rlq "@testing-library/react-native" --include='*.test.tsx' . 2>/dev/null | grep -v node_modules >/dev/null \
  || echo "FAIL: component test does not use @testing-library/react-native"
ls .maestro/*.yaml >/dev/null 2>&1 || echo "FAIL: no Maestro flow file (R11 needs >=1)"
```

Judge results against `docs/app-gotchas.md`: missing `AppState` lifecycle handling (R3) or
unguarded native calls that can crash on a missing asset (R1/R2) is a FAIL. A per-frame allocation
in a hot `useFrameCallback` path is a FAIL when the app/game relies on it at any real entity count
— otherwise CHECK-level. **Branding (R5):** the default Expo icon/splash, an alpha-channel icon, or
a slug-ish display name is a FAIL. **Native config (R6):** bundle id must be byte-identical across
platforms and the orientation must be locked both statically (`app.json`) and at runtime
(`expo-screen-orientation`). **Assets & CI (R7):** any dangling asset path or missing CI workflow
is a FAIL. **Store graphics (R8):** deferred to Phase B per `contract.md` — skip, do not FAIL on
its absence. **Durable save (R9):** persistence on `AsyncStorage` alone is a FAIL — there must be a
`saveRepository.ts` mirroring to `expo-secure-store` (durable-first read) with try/catch on every
call. **Accessibility & safety (R10):** icon-only controls with no `accessibilityLabel` is a FAIL;
Reduce Motion not read is CHECK-level unless the app leans on heavy motion. **Test depth (R11):** a
passing `jest` run that only checks config constants is a FAIL — there must be ≥3 system unit
tests + ≥1 component/RTL test + ≥1 Maestro flow, and all must pass.

### Step 8 — Contract criteria evidence

For each criterion in `contract.md`'s `## Mandatory Hard Gates`, `## Platform-Robustness Gates`,
and `## Functional Criteria`, record a row in the feedback evidence table showing the command run,
the result, and any screenshot/log path. Do not mark a criterion DONE without a command that
directly verifies it.

### Step 9 — Launch on simulator and drive the core flow

**This step is mandatory. A PASS verdict is not valid without completing it.**

Boot the iOS simulator:

```bash
open -a Simulator
xcrun simctl boot "iPhone 16" 2>/dev/null || true
```

Build and launch the app (from `<app_slug>/`):

```bash
cd <app_slug>
npx expo run:ios
```

cwd is now inside `<app_slug>/` (from the `cd` above) and stays there for the rest of this step.
Every harness-file path below is root-absolute (`"$ROOT/docs/harness/..."`) precisely so it does
not matter that cwd is inside `<app_slug>/`.

While the app is running:

0. Create the screenshots directory if it does not already exist:
   ```bash
   mkdir -p "$ROOT/docs/harness/screenshots"
   ```
1. If a Maestro flow exists (`.maestro/core-loop.yaml` or `.maestro/primary-journey.yaml`, written
   by the generator per its 6c.8), run it against the booted simulator — this is the automated
   drive of the core loop/primary journey and doubles as evidence for R11's Maestro requirement.
   cwd is already inside `<app_slug>/`, so the flow path is relative to it:
   ```bash
   maestro test .maestro/*.yaml
   ```
   Any step failure is a Hard Gate failure (contract gate 7).
2. Regardless of the Maestro result, manually confirm the flow by capturing screenshots at key
   states — main screen/menu, mid-flow (gameplay or a primary journey step), and the end state
   (game-over/win, or the journey's final screen). Write each to the root-absolute screenshots
   path so it lands correctly regardless of cwd:
   ```bash
   xcrun simctl io booted screenshot "$ROOT/docs/harness/screenshots/round-<N>-ios-menu.png"
   xcrun simctl io booted screenshot "$ROOT/docs/harness/screenshots/round-<N>-ios-mid.png"
   xcrun simctl io booted screenshot "$ROOT/docs/harness/screenshots/round-<N>-ios-end.png"
   ```
3. **Study each screenshot carefully.** Check for: blank/white screens, visual glitches, missing
   assets, overlapping UI, wrong language, or any rendering error.
4. Confirm the app runs without crashes and without console errors (watch the `expo run:ios`
   terminal output/Metro logs throughout).

Any crash, blank screen, or console error is a Hard Gate failure (contract gate 8).

---

## 6.2 Quality Scoring (`--strict` only)

Run this section only when `strict_mode: true` in `config.md` or `--strict` is passed.

Score the app/game on four axes, each 0–10:

| Axis | What to assess |
|---|---|
| **Feel / polish** | Responsiveness, animation/transition quality, feedback on actions, audio cues (`kind: game`: game feel/juice; `kind: app`: interaction feel) |
| **Originality** | Freshness relative to competitors identified in the research phase |
| **Craft** | Code quality, absence of jank, visual polish, consistent use of `ui/designTokens.ts` |
| **Functionality** | All contract criteria met, no edge-case breakage observed |

Also assess:

- **Interaction states**: Does the app/game handle Loading, Empty, and Error states gracefully?
- **Responsiveness**: Does it render correctly across the target device sizes / safe areas?

Scoring threshold:

- Default (`strict_mode: false`): weighted average ≥ **7 / 10** to advise PASS (advisory only).
- Strict profile (`strict_mode: true`): weighted average ≥ **8 / 10** required for PASS.

Weight: Feel/polish 30 %, Originality 20 %, Craft 25 %, Functionality 25 %.

Record the score for each axis and the weighted total in the feedback file. If the weighted total
is below threshold, the verdict is FAIL regardless of 6.1 results, and each axis below 7 must have
at least one specific, reproducible fix listed.

---

## 6.3 Edge-Case Sweep (`--strict` only)

Run this section only when `strict_mode: true` in `config.md` or `--strict` is passed.

Spawn six specialist agents in parallel via the `Agent` tool. All six must report PASS for the
overall verdict to be PASS. A single FAIL from any agent is a FAIL verdict.

| Agent role | Brief |
|---|---|
| **edge-case** | `kind: game`: score overflow, negative health, unreachable states, off-screen entities, simultaneous collision resolution. `kind: app`: malformed/empty API responses, pagination boundaries, concurrent mutations, stale cache. |
| **balance** | `kind: game`: is the difficulty curve fair — winnable, not trivial in the first 30 s, ramps sensibly? `kind: app`: is the primary journey efficient — no dead ends, redundant steps, or confusing states? |
| **lifecycle/crash** | Simulate app backgrounding (home button), device rotation, an incoming-call-style interruption; confirm resume works and no crash. |
| **performance** | Drive the core flow while watching Metro/console output and simulator responsiveness; flag sustained jank or dropped frames (`kind: game`'s `useFrameCallback` loop especially). |
| **test-generator** | Identify the three highest-risk untested paths and write unit/component tests for them; confirm they pass. |
| **adversarial-reviewer** | Adversarially review the generated code for security issues, credential leaks, or App Store policy violations (see `docs/app-gotchas.md`'s Store rejections section). |

Each agent must return a structured PASS/FAIL verdict with evidence. Collect all six verdicts
before proceeding to Judgment.

---

## Judgment

After completing all applicable sections (6.1, and 6.2 + 6.3 if `--strict`), write the verdict.

### Determine verdict

- **PASS** if and only if:
  - All 6.1 Mandatory Hard Gates pass AND all 6.1 Functional Criteria verified with evidence.
  - If `--strict`: 6.2 weighted score ≥ threshold AND all six 6.3 agents report PASS.
- **FAIL** if any Hard Gate fails, any functional criterion lacks evidence, or (when `--strict`)
  6.2 score is below threshold or any 6.3 agent reports FAIL.

### max_rounds check

Before writing the verdict, check: if `current_round == max_rounds`, force the judgment. Do not
return FAIL regardless of results — write the verdict on the current state, record the
forced-advance note in the feedback file, and proceed with the same PASS-path transitions below.

### Write feedback/round-N-qa.md

Create `"$ROOT/docs/harness/feedback/round-<N>-qa.md"` following the layout in
`docs/harness-protocol.md` §5. Fill:

- `## Verdict` — **PASS** or **FAIL** (bold).
- `## Evidence` — one row per criterion checked; include screenshot paths for simulator checks.
- `## Failed Criteria` — for each FAIL, a specific reproducible fix. If PASS, write "none".

Never leave placeholder text. Every criterion must have a real command output or screenshot path
as evidence.

### Update state.md (PASS, or forced advance at max_rounds)

On PASS, the app/game has been built and passed QA. Read `auto_deploy` from
`"$ROOT/docs/harness/config.md"` — it decides whether Phase A stops at a **human-approval gate** or
terminates on its own, since Phase A has no admob/build/deploy skill yet (per
`docs/harness-protocol.md` §7's Phase B seam note) and there is nothing further to dispatch to
either way.

**Default (`auto_deploy: false`) — pause for human review.**

```yaml
status: paused
current_phase: evaluator
next_role: evaluator
pause_reason: manual_action
updated_at: "<ISO-8601 UTC now>"
```

Leave `current_round`, `created_at`, and `resume_attempts` unchanged. The evaluator's job ends at
recording the PASS; a future `expo-harness-resume` is responsible for recognizing this state
(current_phase `evaluator`, a PASS on record) and finalizing `status: completed` on `--resume`.

Print a review checklist for the user, in `default_language` (translate the following template;
an example Korean rendering follows):

> Build + QA passed. **Before anything else, check it yourself:** `cd <app_slug> && npx expo
> start`, then review the QA screenshots in `docs/harness/screenshots/` and
> `docs/harness/feedback/round-<N>-qa.md`. Run `/expo-harness --resume` when satisfied.

Korean rendering (when `default_language: ko`):

> 빌드 + QA 통과. **직접 확인하세요:** `cd <app_slug> && npx expo start` 로 실행하고,
> `docs/harness/screenshots/` 의 QA 스크린샷과 `docs/harness/feedback/round-<N>-qa.md` 를 확인하세요.
> 만족하면 `/expo-harness --resume` 를 실행하세요.

**`auto_deploy: true` — terminate, no pause.** `status: completed` is a real terminal state: the
orchestrator's dispatch loop (`skills/expo-harness/SKILL.md`) exits as soon as it sees
`status: completed` and never re-dispatches `next_role`. Do not leave `status: running` here —
`next_role: evaluator` unchanged plus a running status would make the dispatch loop invoke this
skill again on every pass (its anti-loop guard only aborts when *neither* `updated_at` nor
`next_role` changed, and `updated_at` always changes), rebuilding and re-booting the simulator
forever.

```yaml
status: completed
current_phase: evaluator
next_role: ""
updated_at: "<ISO-8601 UTC now>"
```

Leave `current_round`, `created_at`, `resume_attempts`, and `pause_reason` unchanged. `next_role`
is cleared because `completed` is terminal regardless — this is just for cleanliness, not because
anything reads it once the run is done.

Print a brief completion summary for the user, in `default_language` (translate the following
template; an example Korean rendering follows):

> Build + QA passed and `auto_deploy` is on — the pipeline is complete. See
> `docs/harness/screenshots/` and `docs/harness/feedback/round-<N>-qa.md` for the QA evidence.

Korean rendering (when `default_language: ko`):

> 빌드 + QA 통과, `auto_deploy` 설정으로 파이프라인이 완료되었습니다. QA 근거는
> `docs/harness/screenshots/` 와 `docs/harness/feedback/round-<N>-qa.md` 를 참고하세요.

### Update state.md (FAIL)

On FAIL (and `current_round < max_rounds`), update `"$ROOT/docs/harness/state.md"` per protocol §2
and the `evaluator → generator` transition in §7. Increment `current_round` and set
`status: running` atomically:

```yaml
status: running
current_phase: evaluator
next_role: generator
current_round: <N+1>
checkpoint: ""
updated_at: "<ISO-8601 UTC now>"
```

Leave `created_at`, `resume_attempts`, and `pause_reason` unchanged. **Reset `checkpoint: ""`** —
the next round is a fresh feedback-driven pass, so the generator must not skip sub-phases.

### Append to build-log.md

Append one row to `"$ROOT/docs/harness/build-log.md"` per protocol §6:

```
| <N> | evaluator | PASS/FAIL | <duration> | <one-line summary> |
```

### Append to pipeline-log.md

Append one row to `"$ROOT/docs/harness/pipeline-log.md"` per protocol §6:

```
| <ISO-8601 UTC now> | evaluator | PASS/FAIL | round <N>; next: evaluator (paused)/generator/completed |
```

When the PASS path pauses for the human-review gate (default, `auto_deploy: false`), additionally
append a `pause` event row:

```
| <ISO-8601 UTC now> | evaluator | pause | manual_action: run/approve the built app before finishing |
```

When the PASS path terminates instead (`auto_deploy: true`), additionally append a `complete`
event row:

```
| <ISO-8601 UTC now> | evaluator | complete | status: completed (auto_deploy) |
```

---

## Error Handling

- If `contract.md` is missing or has no `## Status: AGREED`, abort immediately.
- If `handoff/round-<N>-gen.md` is missing, abort with a clear message; do not set a FAIL
  verdict — the generator has not run yet.
- If the simulator cannot be booted (headless CI), document the failure, skip Step 9, and set the
  verdict to FAIL with fix: "boot a simulator and complete Step 9."
- If any agent in 6.3 returns an error (not FAIL, but a tool error), retry once, then count it as
  FAIL with note "agent error — retry required."
