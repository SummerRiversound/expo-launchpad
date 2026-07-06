# App Gotchas — required robustness patterns

Hard-won robustness fixes for the Expo/React Native stack, learned from shipped mobile apps. The
**generator must emit** these patterns, the **contract must require** them, and the **evaluator
must verify** them — so a generated app does not silently regress on problems already solved. Cite
this file (DRY); skills do not restate it.

Universal rule: **every native call (audio, haptics, storage, orientation) is wrapped in
try/catch, logs via `console.warn`, and never rethrows.** Missing assets/features degrade
gracefully (silent audio, no-op haptic, fallback UI) — the app stays usable.

---

## Audio (R1)

- **Frequent SFX → a small `Audio.Sound` pool, not a `new Sound()` per shot.** Creating a fresh
  `expo-audio` player per call allocates a native resource each time, causing stutter during bursts
  (taps, notifications, combo hits). Pre-load 1–3 `Audio.Sound` instances per frequent SFX up front
  and replay them from the pool. Rare one-offs (success, error) may still load on demand.
- **Throttle rapid repeats** (~70 ms): keep a `Map<string, number>` of last-played timestamps; skip
  a key if it fired within the window. Collapses a burst into a steady click.
- **Graceful fallback**: wrap every load and play call in try/catch; if an asset is missing, log via
  `console.warn` and skip playback. Never crash on a bad/typo'd audio path.
- **BGM lifecycle**: start background music only in the active/playing state (not on menus/splash).
  Stop it on `AppState` background and on unmount — music from a previous session must not leak
  into a menu or keep playing after the app is backgrounded.
- **Volume caps**: define per-channel caps (e.g. BGM ≤ 0.2, SFX ≤ 0.7); the user's volume slider is
  a fraction of the cap, so 100% is a safe level, not ear-splitting.

## Haptics (R2)

- **Provide a `haptics.ts` helper**; never call `Haptics.*` raw from feature code. The helper must:
  - **Platform-guard**: no-op unless `Platform.OS === 'ios' || Platform.OS === 'android'` (web has
    no haptics API and must not throw).
  - **Throttle** (~60 ms global minimum gap) — bursts otherwise machine-gun the vibration motor.
  - **`enabled` toggle**, persisted (via `AsyncStorage`), so users can turn it off.
  - **try/catch** every call (simulators / unsupported devices throw).

## App lifecycle (R3)

- **Background = pause**: subscribe to RN `AppState` (`AppState.addEventListener('change', ...)`);
  on `background`/`inactive` cancel the render loop (`cancelAnimationFrame` / pause the Skia clock)
  and pause audio; on `active` reverse both. Prevents battery drain, background audio, and missed
  pauses.
- **Teardown cleanup**: on unmount, stop audio and cancel all timers/listeners/subscriptions
  (including the `AppState` subscription itself). Never re-access loop/animation state after
  teardown has started.
- **Stale input on resume**: gate input on a `canInput` flag (false while backgrounded/paused) so a
  tap that lands during the background→active transition doesn't fire into the wrong screen.

## Input & UI

- **`react-native-gesture-handler` for input**, not the raw `PanResponder`/`onTouch*` APIs — lower
  latency and avoids gesture-recognition jank on frequent taps/drags.
- **`SafeAreaView` + responsive HUD**: wrap every screen/overlay in `SafeAreaView`; cap content and
  dialog width (max-width) so notches, tablets, and landscape don't clip or over-stretch the UI.
- **Block input during splash/transitions** so a stray tap doesn't fall through into the next screen.

## Accessibility & safety (R10)

- **No flashing faster than 3 flashes/second** (photosensitive-seizure safety — WCAG 2.3.1; app
  stores flag it). Keep any flash/strobe effect ≤3 Hz.
- **Respect OS "Reduce Motion"** — read `AccessibilityInfo.isReduceMotionEnabled()`. When true, damp
  or skip large motion effects (screen shake, big transitions, flashing). Route it through one flag
  so effects check it consistently.
- **Tap targets ≥44pt** (iOS/RN convention) for buttons and interactive controls.
- **`accessibilityLabel` / `accessibilityRole` on controls** so menus and overlays are
  screen-reader navigable — icon-only buttons especially.
- **Text contrast ≥4.5:1** against its background.

## Performance (R4)

- **No per-frame allocations in the Skia/`requestAnimationFrame` loop** — reuse objects and hoist
  `Skia.Paint` (and other reusable instances) outside the loop instead of constructing them per
  frame.
- **Run animation on the UI thread** via Reanimated shared values / Skia values, not React state —
  driving frame-by-frame motion through `setState` forces a full re-render every frame.
- **Memoize selectors; avoid unnecessary re-renders** with `React.memo` and stable callbacks
  (`useCallback`/`useMemo`) so a parent re-render doesn't cascade into static children.

## Build / platform (R6)

- **Bundle id identical across platforms** — `app.json` `ios.bundleIdentifier` must equal
  `android.package`, byte-for-byte (lowercase `[a-z0-9.]`, no `_`/`-`/uppercase). A default Expo
  project can leave these diverging; set both explicitly.
- **Lock one orientation** — decide portrait *or* landscape and set it via `app.json` `orientation`
  plus `expo-screen-orientation` at runtime, so the app can't open in or rotate into the wrong
  orientation.
- **`expo-doctor` clean** before shipping — resolve every warning it reports.
- **Asset paths lowercase**: Android is case-sensitive; keep asset file names lowercase.
- **Ship CI from day one**: `.github/workflows/ci.yml` running typecheck (`tsc --noEmit`), lint
  (`expo lint`), and `jest` on push/PR.

## Persistence (R9)

- **Durable save through a `saveRepository.ts`** that mirrors one JSON blob to both
  `expo-secure-store` and `AsyncStorage` — `AsyncStorage` alone is not enough (it can be cleared by
  the OS or lost across app reinstalls); reads go durable-first (`expo-secure-store`), writes go to
  both, every call wrapped in try/catch.
- **Version the save schema** (a `save_v1` key with per-field migration defaults) so new fields
  don't corrupt an existing save.
- **Write critical values synchronously at run-end** (score, currency, progress) rather than relying
  only on a later async flush, so a crash or kill mid-run doesn't lose progress.

## Store rejections

- **Icon and splash must be custom**, not the default Expo template art — a default icon/splash
  reads as an unfinished/template app to reviewers.
- **Icon must be opaque** — no alpha channel; a transparent iOS icon is rejected.
- **ATT via `expo-tracking-transparency`, only when ads/tracking exist** — omit it entirely
  (deferred) for an app with no ad SDK or third-party tracking.
- **Don't cold-prompt for notifications** before the user has a clear, understood reason.
- **Avoid clone silhouettes** — steer clear of visual designs/palettes that read as a copy of a
  well-known app (4.3 Design Spam / minimum functionality).
