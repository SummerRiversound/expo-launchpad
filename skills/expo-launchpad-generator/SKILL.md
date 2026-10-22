---
name: expo-launchpad-generator
description: Phase A, step 5 — build the Expo app/game in 3 gated sub-phases (scaffold+core → systems+features → UI+content+polish), branched by kind (app|game). Each sub-phase ends with a HARD GATE (tsc --noEmit + expo lint + jest) before advancing; round N>1 fixes only the listed evaluator failures.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep]
---

# expo-launchpad-generator

Phase A, step 5 of the expo-launchpad pipeline. Builds the Expo (React Native + TypeScript) app or
game in three gated sub-phases (6a → 6b → 6c), branching every step by `config.md`'s `kind`
(`app` | `game`). Each sub-phase ends with a HARD GATE (`npx tsc --noEmit && npx expo lint && npx
jest`, all green) before the next sub-phase begins. On round N > 1, reads the previous evaluator
feedback and fixes only the listed failures.

All file schemas (`config.md`, `state.md`, `contract.md`, `handoff/round-N-gen.md`,
`feedback/round-N-qa.md`, the log tables) and the phase transition table are defined in
`docs/harness-protocol.md` — that document is the single source of truth (§2 for `state.md`
schema; §4 for handoff layout; §6 for log tables; §7 for the `generator → evaluator` transition).
Do not redefine schemas here. Every platform-robustness pattern (audio, haptics, lifecycle,
performance, persistence, accessibility, build/platform) is defined once in
`docs/app-gotchas.md` (R1–R11) — cite it; do not restate the patterns.

---

## Round Handling and Feedback Intake

### Workspace root

`docs/harness/` is bootstrapped by the orchestrator in the directory the pipeline was invoked
from — call this the **workspace root**. It stays there for the **entire pipeline** and is never
moved or copied into the generated project. Before any other step (including the round-1/round-N
reads below), capture the workspace root once:

```bash
ROOT="$(pwd)"
```

From this point on, **every harness file** (`config.md`, `state.md`, `contract.md`, `plans/*`,
`handoff/*`, `feedback/*`, `pipeline-log.md`, `build-log.md`, `screenshots/*`) — whether read or
written via a Bash redirect, or read/written via the `Write`/`Edit` tools — uses the root-absolute
path `"$ROOT/docs/harness/..."`, never a path relative to whatever directory the shell happens to
be in at the time. `ROOT` is fixed once, the same way `<app_slug>` and `<N>` are: treat it as a
value substituted verbatim into every command below, not a live shell variable that needs to
survive between separate tool invocations. This is what keeps `--resume` and the status/resume
skills working: they read `docs/harness/state.md` at a fixed path relative to the invocation
directory, forever.

The generated Expo project lives in its own subdirectory, `"$ROOT/<app_slug>/"`, and is its own git
repository (6a.9). Sub-phase 6a.1 `cd`s into `<app_slug>/` so the build/test commands
(`create-expo-app`, `tsc --noEmit`, `expo lint`, `jest`, `expo run:ios`, and the app's own git
commits) run from inside it — that `cd` is scoped to those commands only and never carries over to
where harness files are written. Never write into `<app_slug>/docs/harness/`.

### Determine current round

Read `"$ROOT/docs/harness/state.md"`. Extract `current_round` (integer, ≥ 1).

### Round 1 — build from scratch

When `current_round` is 1:

1. Read `"$ROOT/docs/harness/config.md"` (extract `app_name`, `app_slug`, `bundle_id`, `kind`,
   `engine`, `default_language`, `orientation`).
2. Read the latest PRD (`"$ROOT/docs/harness/plans/*-prd.md"`, sort descending, take first).
3. Read the latest design doc (`"$ROOT/docs/harness/plans/*-design.md"`, sort descending, take
   first).
4. Read `"$ROOT/docs/harness/contract.md"`. Confirm `## Status: AGREED` is present; abort with
   `expo-launchpad-generator: contract not AGREED — run expo-launchpad-contract first` if missing.
5. Read `checkpoint` from `"$ROOT/docs/harness/state.md"` (`docs/harness-protocol.md` §2).
   **Re-entry:** if a prior run crashed/paused mid-phase, skip every sub-phase `≤ checkpoint` (its
   HARD GATE already passed and its output exists) and resume at the next one — e.g.
   `checkpoint: 6a` → start at 6b. If `checkpoint` is `""`, start at 6a. If `checkpoint` is already
   `6c`, the build is complete for this round; skip straight to **Self-evaluation and Handoff**.
   This makes the generator safe to re-run without redoing (or colliding with) completed work.

### Round N > 1 — fix only listed failures (feedback intake)

When `current_round` is greater than 1:

1. Read `"$ROOT/docs/harness/feedback/round-<N-1>-qa.md"` (per `docs/harness-protocol.md` §5
   layout).
2. Parse the `## Failed Criteria` section to extract each failing criterion and its prescribed fix.
3. Map each failure to the sub-phase that owns it (6a scaffold/core loop, 6b systems/data/features,
   6c UI/content/tests/polish) and edit the smallest set of files needed. Do NOT redesign or
   refactor areas that were not listed as failures.
4. If `"$ROOT/docs/harness/feedback/round-<N-1>-qa.md"` does not exist, abort with:
   `expo-launchpad-generator: feedback file for round <N-1> not found — cannot determine fixes`.
5. Apply each fix, then run the full HARD GATE (`npx tsc --noEmit && npx expo lint && npx jest`)
   before writing the handoff. `checkpoint` was reset to `""` by the evaluator on FAIL — after a
   successful round N>1 gate, write `checkpoint: 6c` again to `"$ROOT/docs/harness/state.md"` (the
   project is fully built, just patched) before writing the handoff.

---

## Sub-phase 6a — Scaffold + Core

### 6a.1 Create the Expo project (idempotency guard)

Run from the workspace root:

```bash
if [ -f "<app_slug>/package.json" ]; then
  echo "project already exists — reusing (skipping create-expo-app)"
else
  npx create-expo-app@latest <app_slug>
fi
cd <app_slug>
```

The current default template is TypeScript + Expo Router. Verify `tsconfig.json` and a root layout
exist after creation: `src/app/_layout.tsx` (SDK 55+ templates) or `app/_layout.tsx` (older
templates). If an older `create-expo-app` version produced a plain JavaScript or non-router
template instead, remove the directory and retry passing the Expo Router TypeScript template
explicitly (consult `npx create-expo-app@latest --help` for the current flag name — the template
name/flag has changed across Expo SDK releases). This harness keeps routes under a root `app/`
(`docs/harness-protocol.md`'s project layout); 6a.4 removes a template `src/`.

**Idempotency:** `create-expo-app` fails if the target directory is non-empty, which would break a
resume or a re-run of round 1. The guard above makes 6a.1 safe to re-enter — it reuses an existing
scaffold instead of hard-failing.

### 6a.2 Project identity — package.json and app.json

Set in `package.json`:

- `name`: `<app_slug>` (from `config.md`)
- `version`: `1.0.0`

Set in `app.json` (`expo` block):

- `name`: `<app_name>` (from `config.md`) — the display name, not the slug
- `slug`: `<app_slug>`
- `orientation`: `<orientation>` (from `config.md` — `portrait` or `landscape`)

### 6a.3 Bundle id — identical across platforms

**Set it explicitly and IDENTICALLY on both platforms** (per `docs/app-gotchas.md` R6). In
`app.json`:

```json
{
  "expo": {
    "ios": { "bundleIdentifier": "<bundle_id>" },
    "android": { "package": "<bundle_id>" }
  }
}
```

Verify `ios.bundleIdentifier` == `android.package` == `config.md`'s `bundle_id`, **byte-for-byte**
(lowercase `[a-z0-9.]` only, no `_`/`-`/uppercase). A default `create-expo-app` scaffold ships no
bundle id at all — this step adds both explicitly; never leave one platform unset while the other
is configured.

### 6a.4 Remove default template boilerplate

Delete the generated demo screens/tests so the project starts from a clean slate:

```bash
rm -rf app/(tabs) components/HelloWave.tsx components/ParallaxScrollView.tsx \
       components/Collapsible.tsx __tests__/
```

SDK 55+ templates scaffold the demo under `src/` instead (`src/app/`, `src/components/`, …).
Delete it as well: Expo Router serves `src/app` whenever that directory exists, so a leftover
`src/app` would hide every route this harness writes under the root `app/`.

```bash
rm -rf src/
```

(Adjust the exact list to whatever the installed template version actually scaffolded — the goal
is an empty `app/` route tree and no leftover demo components before 6a.6/6a.7 write the real
ones.) Keep `app/_layout.tsx` if the template created one — it is rewritten, not deleted.

### 6a.5 Copy shared config templates

Copy from this plugin's `templates/` directory (the plugin's own `templates/`, not a directory
inside the generated project):

```bash
cp <plugin-templates>/tsconfig.json.template tsconfig.json
cp <plugin-templates>/jest.config.js.template jest.config.js
mkdir -p .github/workflows && cp <plugin-templates>/ci.yml.template .github/workflows/ci.yml
mkdir -p config
```

Then, branching on `kind`:

- **`kind: game`**: `cp <plugin-templates>/gameConfig.ts.template config/gameConfig.ts`, replacing
  `<APP_NAME>` with `<app_name>`. Fill every constant from the PRD's mechanics/content sections
  (world size, player speed, scoring, difficulty ramp, audio volume caps). No magic numbers are
  permitted anywhere else in `game/` or `app/` — every tunable value must reference
  `GameConfig`.
- **`kind: app`**: `cp <plugin-templates>/appConfig.ts.template config/appConfig.ts`, replacing
  `<APP_NAME>` with `<app_name>`. Fill every constant from the PRD's feature list (pagination,
  network timeouts/retries, feature flags). No magic numbers are permitted anywhere else in `app/`
  or `components/`.

Install dependencies used from 6a onward (both kinds): `expo-secure-store`,
`@react-native-async-storage/async-storage`, `expo-screen-orientation`, `i18next`,
`react-i18next`, `expo-localization` — via `npx expo install <package>` (resolves to the SDK-
compatible version, unlike a bare `npm install`). Install kind-specific packages in the steps
below where they're first used.

### 6a.6 `kind: game` — Skia canvas, loop, state machine, input

1. **Dependencies**: `npx expo install @shopify/react-native-skia react-native-gesture-handler`.
2. **Game-state type**: create `game/scene/gameState.ts`:

   ```ts
   export type GameState = 'menu' | 'playing' | 'paused' | 'gameOver';
   // Add states as the PRD requires (e.g. 'levelComplete', 'shop').
   ```

3. **Root layout**: `react-native-gesture-handler` requires the app root wrapped in
   `GestureHandlerRootView` — do this once in `app/_layout.tsx`, wrapping the `<Stack>`/router
   outlet. Omitting this wrapper makes every gesture silently fail to register.
4. **Scene**: create `game/scene/GameCanvas.tsx`. It renders a `<Canvas>` (from
   `@shopify/react-native-skia`) sized to `GameConfig.world`, drives the loop via
   `useFrameCallback` (per `docs/app-gotchas.md` R4 — cite it; do not restate the
   no-per-frame-allocation rule), and exposes `startGame()` / `pauseGame()` / `resumeGame()` /
   `endGame()` transition functions that update the `GameState` (lifted `useState` or a small
   store) consumed by `app/game.tsx` to decide which overlay to render.
5. **Input**: wire the control method the PRD's §3.1 Controls table specifies using
   `react-native-gesture-handler`'s `Gesture.Tap()` / `Gesture.Pan()` / `Gesture.LongPress()`
   inside a `GestureDetector` wrapping the `<Canvas>` — never the raw `PanResponder`/`onTouch*`
   APIs (`docs/app-gotchas.md`, Input & UI).

### 6a.7 `kind: app` — Expo Router route tree, navigation, state layer

1. Create one route file under `app/` per row of the PRD's §6 Navigation Map (file-based routing —
   route path maps directly to the file path/name, e.g. `app/settings.tsx` → `/settings`).
2. Create `app/_layout.tsx` as the root `Stack`/`Tabs` navigator matching the PRD's navigation
   structure; every route from §6 must be reachable from the paths the map specifies.
3. Create a `state/` directory holding the app's shared state layer (React Context, or a small
   store if the PRD's state complexity warrants one) — feature logic never lives inline in `app/`
   route files; routes only read from `state/`/`services/` and render.
4. Each route implements the Loading/Empty/Error states its PRD §5 States row specifies (even as a
   minimal placeholder at this stage — full implementations land in 6b/6c).

### 6a.8 Minimal passing test

Branching on `kind`:

- **`kind: game`**: create `config/gameConfig.test.ts` asserting `GameConfig`'s core constants are
  positive / within range (world dimensions > 0, volume caps in `[0, 1]`, etc.).
- **`kind: app`**: create `config/appConfig.test.ts` asserting `AppConfig`'s core constants are
  positive / within range (page size > 0, timeout > 0, etc.).

### 6a.9 Initialize version control

The generated project is its own git repository — initialize it and commit as the build
progresses, so the work has atomic history from the start (and the user can diff/revert per
sub-phase). `create-expo-app` already writes a suitable `.gitignore` (`node_modules/`, `.expo/`,
`dist/`, etc.) — do not overwrite it; Phase A collects no signing credentials or secrets to
additionally exclude (per `config.md`'s `credentials_dir` placeholder note in
`docs/harness-protocol.md` §1), so no extra excludes are needed here.

```bash
git init -q
git add -A && git commit -q -m "chore: scaffold <app_name> (expo-launchpad 6a)"
```

Use **Conventional Commits** and **never add AI-authorship trailers** (no `Co-Authored-By`, no
"Generated with…" line). Make one atomic commit at each sub-phase gate (6a/6b/6c) and one per
discrete fix on round N > 1.

### 6a HARD GATE

After completing steps 6a.1–6a.9, run and confirm all three exit 0 before proceeding to
Sub-phase 6b:

```bash
npx tsc --noEmit
npx expo lint
npx jest
```

`tsc --noEmit` must report **zero errors**. `expo lint` must report **zero errors**. `jest` must
report **zero failures**. When green, commit:
`git add -A && git commit -q -m "feat: scaffold and core loop pass tsc+lint+jest (6a)"`, then write
`checkpoint: 6a` to `"$ROOT/docs/harness/state.md"` (atomically) so a later re-entry skips 6a.

**If any command fails, fix all reported issues before proceeding. Do not start 6b until this
gate is green.**

---

## Sub-phase 6b — Systems and Features

Sub-phase 6b implements all game entities/systems (or app feature logic/data/services) as specified
in the PRD. Start only after the 6a HARD GATE passes.

### `kind: game`

#### 6b.1 Entities

Create one file per entity under `game/entities/` (e.g. `Player.ts`, `Enemy.ts`, `Obstacle.ts` —
name them after the PRD's actual content). Each entity:

- Holds its own position/velocity/size state and a `draw(canvas, paint)` method using Skia
  primitives (or a shared drawing helper) styled from `ui/designTokens.ts` colours (added in 6c;
  reference the token names now, fill values are already known from the design doc).
- Reads every tunable value (speed, size, score value) from `GameConfig` — no hardcoded numbers.
- Exposes a hitbox/bounds check if the PRD requires collision detection.

#### 6b.2 Systems — spawn / collision / score / difficulty

Create one file per system under `game/systems/`:

- `spawnSystem.ts` — reads spawn intervals and difficulty parameters from `GameConfig`; draws
  entity definitions from the data catalog (6b.3), never inline literals.
- `collisionSystem.ts` — player-vs-enemy/obstacle (game-over or health reduction, per the PRD) and
  player-vs-collectible (score increment + SFX trigger) checks, run once per frame from the scene's
  `useFrameCallback`.
- `scoreSystem.ts` — maintains the current score (`addScore(points)`, `score` getter), notifies the
  HUD (added in 6c) on change, and persists the high score through `saveRepository.ts` (added in
  6c — do not call `AsyncStorage`/`SecureStore` directly from here; that lands once the durable
  save module exists).
- `difficultySystem.ts` — tracks elapsed play time and ramps spawn interval / entity speed using
  `GameConfig.difficulty`, never dropping below `GameConfig.difficulty.minSpawnInterval`.

#### 6b.3 Data catalogs

Create one file per data-driven element the PRD's §4 Content Metrics defines (enemies, levels,
waves, collectibles) under `data/` (e.g. `data/enemies.ts`, `data/levels.ts`). Each catalog exports
a typed array of plain data objects. No enemy/level/wave values may be hardcoded in
`game/entities/` or `game/systems/` — all such values must come from a catalog here. This satisfies
Hard Gate 5 (`docs/harness-protocol.md` §3).

#### 6b.4 Audio pool

**R1 — Audio safe (cite `docs/app-gotchas.md`; do not restate).** `expo-audio`'s API is
`createAudioPlayer(source)` (or the `useAudioPlayer(source)` hook), returning an `AudioPlayer`
(`.play()`, `.pause()`, `.seekTo()`, `.volume`, `.remove()`) — there is **no built-in pool**.
Never reach for the legacy `expo-av` sound-object API — this project only uses `expo-audio`.

1. `npx expo install expo-audio`.
2. Create `game/systems/audioSystem.ts`. For each **frequent** SFX, pre-load 1–3 `AudioPlayer`
   instances via `createAudioPlayer` up front (in a setup effect, not per-trigger) and cycle
   through them on each `playSfx(name)` call. Rare one-offs may load on demand.
3. Throttle repeated SFX (~70 ms per key) using a `Map<string, number>` of last-played timestamps.
4. Wrap every load/play/BGM call in try/catch, logging via `console.warn` on failure — a
   missing/bad audio asset must never crash; playback is skipped silently.
5. Start BGM only in the `'playing'` state; stop it on game-over, on `AppState` background (see
   6b.6/R3), and on unmount.
6. Apply per-channel volume caps from `GameConfig.audio` (`bgmVolume`, `sfxVolume` as safe caps —
   a user volume slider, if any, is a fraction of the cap).

#### 6b.5 Haptics helper

**R2 — Haptics safe (cite `docs/app-gotchas.md`; do not restate).**

1. `npx expo install expo-haptics`.
2. Create `game/systems/haptics.ts`. Gameplay code never calls `Haptics.*` directly — only through
   this helper, which:
   - No-ops unless `Platform.OS === 'ios' || Platform.OS === 'android'`.
   - Enforces a global throttle (~60 ms minimum gap).
   - Exposes a persisted `enabled` toggle (via `AsyncStorage`) and intent methods (`light()`,
     `medium()`, `heavy()`) over `expo-haptics`.
   - Wraps every call in try/catch (simulators/unsupported devices throw).

#### 6b.6 App lifecycle wiring

**R3 — App lifecycle safe (cite `docs/app-gotchas.md`; do not restate).** Subscribe to
`AppState.addEventListener('change', ...)` in the scene (`game/scene/GameCanvas.tsx`) or its root
route: on `background`/`inactive`, cancel the frame loop and pause BGM; on `active`, reverse both.
Gate input behind a `canInput` flag during the transition. Clean up the subscription (and all
timers) on unmount.

#### 6b.7 Tests for systems

Write **at least 3** focused unit tests covering the game's actual systems, e.g.:

- `scoreSystem.addScore` increments correctly (and a `reset` zeroes it).
- `difficultySystem` increases spawn rate over time but never below
  `GameConfig.difficulty.minSpawnInterval`.
- Data catalog entries are non-empty and every numeric field is positive.

These are the minimum — add one per non-trivial system the PRD defines. Contract gate R11 requires
≥3 system unit tests.

### `kind: app`

#### 6b.1 Feature logic and typed data models

Create one typed model per PRD §4 Data Model entity under `data/` (e.g. `data/order.ts`) — no
untyped `any` payloads. Implement the feature logic each PRD §3 Feature List (MVP) row requires.

#### 6b.2 Service/data layer

Create the API/data-fetching layer under `services/` (e.g. `services/orderService.ts`) —
per the PRD §4, either a mock in-memory/local dataset or a real API client. Every network call has
an explicit timeout/retry from `AppConfig.network` (no magic numbers). No feature logic or
network/storage calls live inline in `app/` route files — only in `services/`/`state/`.

#### 6b.3 Hooks

Create a `hooks/` directory (a natural addition to the PRD §9 map, wrapping `state/`/`services/`
into screen-consumable hooks — analogous to how design added `ui/designTokens.ts` as a single-file
addition). E.g. `hooks/useOrders.ts` composing `services/orderService.ts` + `state/` for a route to
consume with one call.

#### 6b.4 Tests for features

Write **at least 3** focused unit tests covering real logic, e.g.:

- A service function returns the expected shape/error for both success and failure paths.
- A typed data model's parsing/validation rejects malformed input.
- A hook's derived state (e.g. a computed total, a filtered list) is correct for a given input.

Contract gate R11 requires ≥3 unit tests.

### 6b HARD GATE

After completing the `kind`-appropriate steps above, run:

```bash
npx tsc --noEmit
npx expo lint
npx jest
```

All three must report **zero errors/failures**. When green, commit:
`git add -A && git commit -q -m "feat: systems and features pass tsc+lint+jest (6b)"`, then write
`checkpoint: 6b` to `"$ROOT/docs/harness/state.md"`.

**If any command fails, fix all reported issues before proceeding. Do not start 6c until this
gate is green.**

---

## Sub-phase 6c — UI, Content, and Polish

Sub-phase 6c wires up all screens/overlays, applies design tokens, adds localization, completes
durable-save persistence, and applies accessibility/branding/native-config polish. Start only
after the 6b HARD GATE passes.

### 6c.1 Design tokens

Create `ui/designTokens.ts` from the design doc's `## Design tokens` section, using the exact file
template it specifies (`Colors`/`Spacing`/`Radius`/`Typography`, each `as const`). Every colour,
spacing, radius, and font value used anywhere in `app/`, `components/`, `game/`, or `ui/` must
come from this file — no raw hex strings or bare numeric literals in UI code.

### 6c.2 Screens and overlays

**`kind: game`** — for each screen/overlay the PRD requires, create a file. A typical set (add or
remove per the PRD):

| File | Rendered | Trigger |
|---|---|---|
| `app/index.tsx` | main-menu route | app launch |
| `app/game.tsx` | hosts `game/scene/GameCanvas.tsx` | Play tapped |
| `ui/hud.tsx` | overlay inside `app/game.tsx` | `gameState === 'playing'` |
| `ui/pauseOverlay.tsx` | overlay inside `app/game.tsx` | pause button tapped |
| `ui/gameOverOverlay.tsx` | overlay inside `app/game.tsx` | player loses |
| `app/settings.tsx` | settings route | settings button tapped |

`ui/hud.tsx` shows the current score, health/lives (if the PRD defines them), and a pause button.
The game-over overlay shows the final score, best score (with a new-record indicator), a restart
control, and a main-menu control. All sizes/colours use `ui/designTokens.ts`.

**`kind: app`** — for each screen the PRD's §2 Primary Journeys / §6 Navigation Map defines, fill
in the full implementation (the route files created in 6a.7 held placeholders): Loading/Empty/Error
states per PRD §5, styled exclusively from `ui/designTokens.ts`, using shared building blocks
under `components/` (buttons, cards, lists, form fields) so no screen duplicates the same markup.

**Accessibility baseline (gate R10 — cite `docs/app-gotchas.md`; do not restate).** Every tappable
control on these screens/overlays must be **≥44×44 pt** and carry an `accessibilityLabel` /
`accessibilityRole` — especially icon-only buttons (pause, settings, restart). Read
`AccessibilityInfo.isReduceMotionEnabled()` and route it through one flag so gameplay/transition
effects (screen shake, big transitions, flashing) can damp or skip themselves when it's `true`;
never flash faster than 3×/second.

### 6c.3 Localization (i18n)

1. `cp <plugin-templates>/i18n.ts.template i18n/i18n.ts`.
2. For every locale `config.md`'s `default_language` requires (plus `en` as the template's
   fallback, if `default_language` isn't already `en`), add a `resources` entry with every
   user-visible string used across every screen/overlay/component — no string literals in UI
   code, only `t('key')` calls (`react-i18next`'s `useTranslation`).
3. Verify completeness: every locale's key set must exactly match every other configured locale's
   key set (no missing/extra keys) — write or run a small script comparing the `resources` objects
   and fail loudly if any key is missing in any locale. This satisfies Hard Gate 6
   (`docs/harness-protocol.md` §3).

### 6c.4 Durable save — persistence (default ON)

**R9 — Persistence safe (cite `docs/app-gotchas.md`; do not restate).**

1. `cp <plugin-templates>/saveRepository.ts.template data/saveRepository.ts`, replacing
   `__SAVE_KEY__` with `<app_slug>_save_v1`. It mirrors one JSON blob across **`expo-secure-store`**
   (durable-first read) and **`AsyncStorage`** (cache), every call wrapped in try/catch.
2. Keep the blob small — `expo-secure-store` caps values at ~2 KB per key on iOS/Android. Persist
   only essential fields (high score/progress, economy totals, settings, a `save_v1` version key).
   If more must be stored, split across additional `saveRepository` keys or keep bulk data in
   `AsyncStorage` only, with just a pointer/critical subset going through `saveRepository`.
3. Route every persisted read/write through `saveRepository.ts` — no direct `AsyncStorage`/
   `expo-secure-store` calls anywhere else. `kind: game`'s `scoreSystem.ts` (6b.2) wires through it;
   `kind: app`'s `state/` layer loads it once at startup into an in-memory shape and writes through
   it on every mutation.
4. Migrate the audio/haptics `enabled` toggles from the direct `AsyncStorage` stopgap (6b.4/6b.5) to
   route through `saveRepository.ts` — replace the direct `AsyncStorage` calls in
   `game/systems/haptics.ts` and `game/systems/audioSystem.ts` with calls into `saveRepository.ts`,
   and verify no direct `AsyncStorage` calls remain outside `saveRepository.ts`.
5. Write critical values synchronously at run-end (final score, currency, progress) rather than
   relying only on a later async flush.

### 6c.5 App branding — icon, splash, display name

**R5 — Branding safe (cite `docs/app-gotchas.md`'s Store rejections section; do not restate).** A
shipped app must not have the default Expo icon, default splash, or a slug-ish display name.

1. **Icon + splash art.** Default: code-drawn, from the design doc's Asset plan (palette + a
   monogram/mark) — no external art dependency. Add `sharp` as a dev dependency
   (`npm install --save-dev sharp`) and create `scripts/gen-icon.js`: build a small inline SVG
   string per asset (a solid `Colors.primary`-filled 1024×1024 square with a centred monogram — the
   first letter of `app_name` — in `Colors.onBackground` for the icon; a `Colors.background`-filled
   square with a smaller centred mark for the splash) and rasterize each with
   `sharp(Buffer.from(svg)).png().toFile(...)`. Run it once (`node scripts/gen-icon.js`) to write:
   - `assets/images/icon.png` (1024×1024, **opaque — flatten any alpha with `.flatten({ background:
     ... })`**; a transparent iOS icon is rejected)
   - `assets/images/adaptive-icon.png` (Android foreground layer, same mark)
   - `assets/images/splash-icon.png`

   If the design doc's Asset plan instead chose sourced/AI-generated art, use those images at the
   same paths (still flattened opaque for the icon).
2. **Wire `app.json`** per the design doc's App icon and splash screen template: `expo.icon`,
   `expo.android.adaptiveIcon` (`foregroundImage` + `backgroundColor: <Colors.primary>`), and the
   `expo-splash-screen` plugin entry (`image`, `imageWidth: 200`, `resizeMode: "contain"`,
   `backgroundColor: <Colors.background>`).
3. **Display name** — `app.json`'s `expo.name` was already set to `<app_name>` in 6a.2; confirm it
   still reads as the human display name, not the slug (this is what both platforms show as the
   home-screen label in a managed Expo build).

### 6c.6 Native platform config — orientation lock

**R6 — Native config safe (cite `docs/app-gotchas.md`; do not restate).** `app.json`'s
`expo.orientation` was set in 6a.2; reinforce it at runtime so the app can't rotate into the unused
orientation even under a dev client or a config that doesn't fully honour `app.json`:

1. `npx expo install expo-screen-orientation`.
2. In the root layout (`app/_layout.tsx`), on mount call
   `ScreenOrientation.lockAsync(...)` with the lock constant matching `config.md`'s `orientation`
   (`PORTRAIT_UP` or `LANDSCAPE`), wrapped in try/catch (unsupported on web).

### 6c.7 Anti-stub verification

Before the final HARD GATE, run one directory-agnostic scan over every TypeScript source in the
project (covers `app/`, `game/`, `components/`, `config/`, `data/`, `services/`, `state/`, `hooks/`,
`ui/`, `i18n/` and any other source dir — no need to enumerate them, and nothing is missed if a
dir was added in 6b/6c that an enumerated list would omit). Run from inside `<app_slug>/` (the
working directory since 6a.1):

```bash
grep -rniE "TODO|stub|placeholder|미구현" . --include='*.ts' --include='*.tsx' | grep -vE 'node_modules|/\.expo/|/dist/'
```

If this command returns any output, fix or remove every match. The contract requires zero stubs in
app/game logic (`docs/harness-protocol.md` §3, Hard Gate 3).

### 6c.8 Full tests — component/RTL + Maestro flow

Contract gate R11 requires **≥1 component test + ≥1 Maestro flow**, beyond the ≥3 unit tests from
6b.

1. **Component test** — `npm install --save-dev @testing-library/react-native`. Create a test for
   one menu/overlay/screen (e.g. `ui/hud.test.tsx` or `app/index.test.tsx`) asserting it renders
   and that pressing its primary control (accessibility-labelled, ≥44pt per R10) fires the expected
   handler.
2. **Maestro flow** — create `.maestro/core-loop.yaml` (game: boot → play → win/lose → restart) or
   `.maestro/primary-journey.yaml` (app: the PRD's primary journey, screen by screen), each step
   keyed off the `accessibilityLabel`s set in 6c.2. `appId: <bundle_id>`. (Maestro itself is an
   external CLI, not an npm dependency — the evaluator phase runs `maestro test .maestro/<flow>.yaml`
   against the built app.)
3. Expand coverage per kind:
   - **`kind: game`**: game-over overlay shows the correct final/best score; `saveRepository`
     read/write round-trips (score, settings) using a mocked `expo-secure-store`/`AsyncStorage`.
   - **`kind: app`**: every screen's Loading/Empty/Error state renders correctly for a given input;
     `saveRepository` read/write round-trips using the same mocks.
   - Both: localization — every configured locale's `resources` key set matches (6c.3's check,
     turned into an actual `jest` test rather than a one-off script).

### 6c.9 README + LICENSE

A shipped project has a `README.md` and a `LICENSE`.

- **`README.md`** — `cp <plugin-templates>/README.md.template README.md`, then fill:
  `<APP_NAME>` → `app_name`; `<ONE_LINE_PITCH>` → the PRD's tagline; `<TECH_STACK>` → the actual
  stack used (**`kind: game`**: Skia `<Canvas>` + `useFrameCallback` game loop, `expo-audio`,
  `expo-haptics`, i18next, `expo-secure-store`+`AsyncStorage` durable save; **`kind: app`**: Expo
  Router navigation, the `state/`/`services/` layer, i18next, `expo-secure-store`+`AsyncStorage`
  durable save). Author it in `default_language` (add an English section too when it isn't `en`).
- **`LICENSE`** — `cp <plugin-templates>/LICENSE.template LICENSE`, filling `<YEAR>` with the
  current year and `<HOLDER>` with `<app_name>` (Phase A collects no developer/company identity —
  same placeholder rationale as the `bundle_id` `example` segment, `docs/harness-protocol.md` §1).

Commit them with the 6c gate commit below.

### 6c HARD GATE

After completing steps 6c.1–6c.9, run:

```bash
npx tsc --noEmit
npx expo lint
npx jest
```

All three must report **zero errors/failures**. Also confirm branding (6c.5): a **custom** icon +
splash were generated (not the default Expo art), the icon is **opaque (no alpha)**, and the
display name equals `app_name` (not the slug). And native config (6c.6): orientation locked to
`config.orientation` both statically (`app.json`) and at runtime (`expo-screen-orientation`). And
assets/CI (6a.9/6c.5): every asset referenced in code exists on disk (no dangling paths), and
`.github/workflows/ci.yml` is present.

**This is the final gate. Do not write the handoff until all three commands pass. If any fails,
fix all reported issues and re-run all three.** When green, commit:
`git add -A && git commit -q -m "feat: UI, content, branding and native config (6c)"`, then write
`checkpoint: 6c` to `"$ROOT/docs/harness/state.md"` before writing the handoff.

---

## Self-evaluation and Handoff

After the 6c HARD GATE passes, write the generator handoff and update pipeline state.

### Write handoff/round-N-gen.md

Create `"$ROOT/docs/harness/handoff/round-<N>-gen.md"`, following the layout defined in
`docs/harness-protocol.md` §4:

```markdown
# Round <N> — Generator Handoff

## What Was Built

<!-- Bullet list of features implemented (round 1) or bugs fixed (round N>1). -->

## Contract Self-Assessment

| Criterion | Status | Evidence |
|---|---|---|
| Hard Gate 1 (tsc --noEmit + expo lint) | ✅/❌ | <command output ref> |
| Hard Gate 2 (jest all pass) | ✅/❌ | <command output ref> |
| Hard Gate 3 (no TODO/stub/placeholder) | ✅/❌ | <grep output ref> |
| Hard Gate 4 (tuning centralized in config/) | ✅/❌ | <file ref> |
| Hard Gate 5 (content defined as data) | ✅/❌ | <file ref> |
| Hard Gate 6 (l10n complete, no missing keys) | ✅/❌ | <check ref> |
| Hard Gate 7 (core loop / primary journey end-to-end) | ✅/❌ | <test/flow ref> |
| Hard Gate 8 (zero crashes/console errors on simulator) | ✅/❌ | <deferred to evaluator's live run> |
| Platform-Robustness Gates R1–R11 | ✅/❌ | <brief per-gate note> |
| <PRD-specific criterion> | ✅/❌ | <evidence> |

## Test Results

- `tsc --noEmit`: <pass/fail summary>
- `expo lint`: <pass/fail summary>
- `jest`: <pass/fail summary, test count>

## Environment

- `node`: <output of `node --version`>
- `expo`: <the `expo` version pinned in package.json>
- `npx expo --version`: <output of that command>

## Known Issues

<!-- List any known issues or deferred items. State "none" if clean. -->
```

Fill every section with actual output and real assessments. Do not leave placeholder text.

### Update state.md

Update `"$ROOT/docs/harness/state.md"` per `docs/harness-protocol.md` §2 and the
`generator → evaluator` transition in §7. Per §7 rule 2, a successful phase completion sets
`status: running` in the same atomic write:

```yaml
status: running
current_phase: generator
next_role: evaluator
updated_at: "<ISO-8601 UTC now>"
```

Leave `current_round`, `created_at`, `resume_attempts`, and all other keys unchanged (`checkpoint`
was already written as `6c` at the end of the 6c HARD GATE, above). Use `Edit` for a targeted
update.

> **Note:** `current_round` is incremented by the evaluator when it returns FAIL; the generator
> reads it but does not write it.

### Append to build-log.md

Append one row to `"$ROOT/docs/harness/build-log.md"` per `docs/harness-protocol.md` §6:

```
| <N> | generator | <ISO-8601 UTC now> | handoff | round <N> built; tsc 0; lint 0; jest 0 failures |
```

### Append to pipeline-log.md

Append one row to `"$ROOT/docs/harness/pipeline-log.md"` per `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | generator | handoff | evaluator |
```

---

## Error handling

- If `contract.md` is missing or does not contain `## Status: AGREED`, abort immediately.
- If any HARD GATE fails (non-zero `tsc --noEmit`/`expo lint` errors, or failing `jest` tests),
  stop at that sub-phase, fix the failures, and re-run the gate. Do not advance to the next
  sub-phase.
- If the feedback file for round N-1 is missing on a round > 1 run, abort with a clear message and
  set `"$ROOT/docs/harness/state.md"` to `status: paused`, `pause_reason: manual_action`.
- If `create-expo-app` fails, abort immediately and do not proceed to 6a.2.
- If a dependency install fails, check for SDK version conflicts (`npx expo install --check`) and
  resolve before continuing.
