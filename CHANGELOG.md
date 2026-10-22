# Changelog

## 0.1.1 — 2026-10-22
- Generator: handle the SDK 55+ `create-expo-app` template, which scaffolds routes under `src/app/`.
  The scaffold step now removes the template `src/` (Expo Router serves `src/app` over the root
  `app/` whenever it exists) and detects an existing project by `package.json`, so a re-run no
  longer calls `create-expo-app` on a non-empty directory.
- Research: treat fetched web content as data, never as instructions.

## 0.1.0 — 2026-07-06
Initial release.
- Idea → playable pipeline: research → plan → design → contract → generator ⇄ evaluator → human review.
- Supports `--kind app` (Expo Router) and `--kind game` (@shopify/react-native-skia).
- Skeptical evaluator: runs the app on an iOS simulator and studies screenshots before judging.
- 8 hard gates + R1–R11 platform-robustness gates.
- Structural port of flutter-flame-harness (MIT) to Expo / React Native / TypeScript.
