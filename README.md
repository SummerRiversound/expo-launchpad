# expo-launchpad

An installable Claude Code plugin that drives an **idea → playable** pipeline for Expo (React
Native + TypeScript) apps and games. A faithful structural port of
[`flutter-flame-harness`](https://github.com/tjdrhs90/flutter-flame-harness) — same state machine,
same contract, same generator ⇄ evaluator skeptical-QA loop — retargeted to the Expo/RN/TS stack.

**Phase A only**: idea → playable, ending at a human-review pause. Deploy (EAS Build/Submit, store
listings, ads) is a future Phase B — not implemented here.

## Install

This repo ships its own local marketplace (`.claude-plugin/marketplace.json`):

```
/plugin marketplace add <path-to-expo-launchpad>
/plugin install expo-launchpad
```

## Usage

```
/expo-launchpad --kind app "todo app"
/expo-launchpad --kind game "turn-based puzzle"
```

| Flag | Default | Meaning |
|---|---|---|
| `[idea]` | — | one-line pitch; blank is valid — research generates and recommends concepts |
| `--kind app\|game` | `app` | what to build |
| `--engine skia` | `skia` | render engine, `kind: game` only |
| `--strict` | off | evaluator adds quality scoring + an edge-case sweep |
| `--rounds N` | `3` | max generator ⇄ evaluator rounds before a forced judgment |
| `--skip-research` | off | requires an idea (nothing to research from) |
| `--auto-idea` | off | auto-pick a research-recommended concept instead of asking |
| `--auto-deploy` | off | changes how an evaluator PASS resolves (see Pipeline) |
| `--resume` | — | continue a paused run |

Companion read-only reporter: `/expo-launchpad-status` — phase, round, next role, pause reason.

## Pipeline

```
research → plan → design → contract → generator ⇄ evaluator → paused (human review) → resume → completed
```

- **research** — market/genre scan, or a clone-fallback check when an idea is given.
- **plan** — PRD + identity (`app_name`, `app_slug`, `bundle_id`).
- **design** — tokens + visual spec.
- **contract** — negotiates the Mandatory Hard Gates + Functional Criteria; generator refuses to
  start until `## Status: AGREED`.
- **generator ⇄ evaluator** — generator builds in gated sub-phases (checkpoints `6a`/`6b`/`6c`);
  the evaluator is skeptical QA — it **runs the app on a simulator, drives the core flow, and
  studies screenshots before judging**. Code review alone never earns a PASS; a detected stub is
  an automatic FAIL. FAIL sends the next round back to the generator; PASS pauses for human
  review (or, with `--auto-deploy`, resolves differently — see `docs/harness-protocol.md` §7).
- **resume** — `/expo-launchpad --resume` after a pause; on the post-PASS human-review gate it marks
  the run `completed` (Phase A has no deploy phase to hand off to yet).

Full state machine, file schemas, and the phase-transition table: `docs/harness-protocol.md`.

## Generated stack

- **Expo Router**, TypeScript (strict)
- **Jest** (`jest-expo` preset) + `@testing-library/react-native` for component tests
- **Maestro** for E2E flows (`.maestro/core-loop.yaml` game / `.maestro/primary-journey.yaml` app)
- **`@shopify/react-native-skia`** for game rendering (`kind: game`, default engine)
- `expo-audio`, `expo-haptics`, `expo-secure-store` (+ AsyncStorage durable save),
  `expo-localization` (i18next), `expo-screen-orientation`

## Quality gates

- **8 Mandatory Hard Gates** — type/lint clean, tests pass, no stubs, tuning centralized in
  `config/gameConfig.ts`/`config/appConfig.ts`, content as data, complete localization, the core
  loop/primary journey works end to end, zero crashes/console errors on a simulator. Verbatim
  list: `docs/harness-protocol.md` §3.
- **Platform-Robustness Gates R1–R11** — audio, haptics, app lifecycle, input/UI, accessibility,
  performance, build/platform, persistence patterns hard-won from shipped RN apps. Full pattern
  set: `docs/app-gotchas.md`.

## Phase B roadmap (not implemented)

EAS Build/Submit, store screenshots and metadata, AdMob integration.

## Credit

Ported from [`flutter-flame-harness`](https://github.com/tjdrhs90/flutter-flame-harness).

## License

MIT — see [LICENSE](./LICENSE).
