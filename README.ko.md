# expo-harness

Expo(React Native + TypeScript) 앱/게임을 위한 **아이디어 → 실행 가능한 빌드** 파이프라인을
구동하는 설치형 Claude Code 플러그인입니다.
[`flutter-flame-harness`](https://github.com/tjdrhs90/flutter-flame-harness)의 충실한 구조적
포팅판으로 — 동일한 상태 머신, 동일한 컨트랙트, 동일한 generator ⇄ evaluator 회의적 QA 루프를
Expo/RN/TS 스택에 맞게 재구성했습니다.

**Phase A만 구현**: 아이디어 → 실행 가능한 빌드까지이며, 사람의 리뷰 대기(pause)에서 끝납니다.
배포(EAS Build/Submit, 스토어 등록, 광고)는 미래의 Phase B이며 여기서는 구현되지 않았습니다.

## 설치

이 저장소는 자체 로컬 마켓플레이스(`.claude-plugin/marketplace.json`)를 포함합니다:

```
/plugin marketplace add <path-to-expo-harness>
/plugin install expo-harness
```

## 사용법

```
/expo-harness --kind app "todo app"
/expo-harness --kind game "turn-based puzzle"
```

| 플래그 | 기본값 | 의미 |
|---|---|---|
| `[idea]` | — | 한 줄 아이디어; 비워도 유효함 — research가 컨셉을 생성·추천 |
| `--kind app\|game` | `app` | 무엇을 만들지 |
| `--engine skia` | `skia` | 렌더 엔진, `kind: game`에서만 의미 있음 |
| `--strict` | 꺼짐 | evaluator가 품질 스코어링 + 엣지케이스 스윕을 추가 수행 |
| `--rounds N` | `3` | 강제 판정 전까지의 generator ⇄ evaluator 최대 라운드 수 |
| `--skip-research` | 꺼짐 | 아이디어가 필수(리서치할 대상이 없으면 안 됨) |
| `--auto-idea` | 꺼짐 | 사용자에게 묻는 대신 research가 추천한 컨셉을 자동 선택 |
| `--auto-deploy` | 꺼짐 | evaluator PASS 이후 처리 방식이 달라짐(Pipeline 참고) |
| `--resume` | — | 중단된 실행을 이어서 진행 |

읽기 전용 보조 리포터: `/expo-harness-status` — 단계, 라운드, 다음 역할, 중단 사유를 표시.

## 파이프라인

```
research → plan → design → contract → generator ⇄ evaluator → paused (human review) → resume → completed
```

- **research** — 시장/장르 조사, 또는 아이디어가 주어진 경우 클론-폴백 체크.
- **plan** — PRD + 아이덴티티(`app_name`, `app_slug`, `bundle_id`).
- **design** — 토큰 + 비주얼 스펙.
- **contract** — Mandatory Hard Gates + Functional Criteria를 협의; `## Status: AGREED`가 없으면
  generator는 시작하지 않음.
- **generator ⇄ evaluator** — generator는 게이트가 걸린 서브 페이즈(체크포인트 `6a`/`6b`/`6c`)로
  빌드; evaluator는 회의적 QA로서 **시뮬레이터에서 앱을 실제로 실행하고, 핵심 플로우를 조작하며,
  스크린샷을 살펴본 뒤에야 판정**합니다. 코드 리뷰만으로는 PASS를 받을 수 없고, 스텁이 발견되면
  자동 FAIL입니다. FAIL이면 다음 라운드가 generator로 돌아가고, PASS면 사람 리뷰를 위해
  대기(paused)합니다(또는 `--auto-deploy` 설정 시 처리 방식이 다름 — `docs/harness-protocol.md`
  §7 참고).
- **resume** — 중단 후 `/expo-harness --resume`; PASS 이후의 human-review 게이트에서는 실행을
  `completed`로 표시합니다(Phase A에는 아직 넘겨줄 배포 단계가 없음).

전체 상태 머신, 파일 스키마, 단계 전이 표는 `docs/harness-protocol.md`에 있습니다.

## 생성되는 스택

- **Expo Router**, TypeScript(strict)
- **Jest**(`jest-expo` 프리셋) + 컴포넌트 테스트용 `@testing-library/react-native`
- E2E 플로우용 **Maestro**(`.maestro/core-loop.yaml` 게임 / `.maestro/primary-journey.yaml` 앱)
- 게임 렌더링용 **`@shopify/react-native-skia`**(`kind: game`, 기본 엔진)
- `expo-audio`, `expo-haptics`, `expo-secure-store`(+ AsyncStorage 내구성 저장),
  `expo-localization`(i18next), `expo-screen-orientation`

## 품질 게이트

- **8개 Mandatory Hard Gates** — 타입/린트 클린, 테스트 통과, 스텁 없음, 튜닝값은
  `config/gameConfig.ts`/`config/appConfig.ts`에 중앙화, 콘텐츠는 데이터로, 완전한 로컬라이제이션,
  핵심 루프/주요 여정이 end-to-end로 동작, 시뮬레이터에서 크래시·콘솔 에러 0건. 원문 목록:
  `docs/harness-protocol.md` §3.
- **Platform-Robustness Gates R1–R11** — 출시된 RN 앱들에서 얻은 오디오, 햅틱, 앱 라이프사이클,
  입력/UI, 접근성, 성능, 빌드/플랫폼, 퍼시스턴스 패턴. 전체 패턴 세트: `docs/app-gotchas.md`.

## Phase B 로드맵 (미구현)

EAS Build/Submit, 스토어 스크린샷·메타데이터, AdMob 연동.

## 크레딧

[`flutter-flame-harness`](https://github.com/tjdrhs90/flutter-flame-harness)에서 포팅했습니다.

## License

MIT — [LICENSE](./LICENSE) 참고.
