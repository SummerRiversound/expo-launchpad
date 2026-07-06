# Contributing

## Scope

Current scope is **Phase A**: idea → playable app/game, ending at a human-review pause. Deploy
(EAS Build/Submit, store metadata, AdMob) is **Phase B** and out of scope for now — see the
Roadmap section in `README.md`.

## Dev loop

Before opening a PR, run the test harness from the repo root:

```
bash scripts/validate.sh
```

It must print `ALL CHECKS PASSED`. Among other checks, it verifies that all 9 skill
`SKILL.md` files (`expo-launchpad`, `expo-launchpad-research`, `expo-launchpad-plan`,
`expo-launchpad-design`, `expo-launchpad-contract`, `expo-launchpad-generator`,
`expo-launchpad-evaluator`, `expo-launchpad-resume`, `expo-launchpad-status`) have
frontmatter that parses as real YAML — quote any scalar value containing a colon.

## Skill-authoring conventions

- Cite `docs/harness-protocol.md` (state machine, file schemas, phase-transition table) and
  `docs/app-gotchas.md` (platform-robustness patterns, R1–R11) instead of restating their
  content. If a schema or pattern needs to change, edit it in one of those two docs, not in a
  skill.
- Do not introduce Flutter/Flame/Dart tokens (e.g. `pubspec`, `SharedPreferences`,
  `WidgetsBinding`, `.arb`, `cupertino`) into any skill or into `docs/harness-protocol.md` /
  `docs/app-gotchas.md` — those two docs and the skills are Expo/React Native/TypeScript only.
  `validate.sh` greps for this.

## Commits

- Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`,
  `refactor:`, `chore:`, `test:`).
- Do not add AI-authorship trailers (e.g. "Generated with ...", "Co-Authored-By: Claude ...") to
  commit messages or PR descriptions.
