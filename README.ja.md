[English](README.md) · [한국어](README.ko.md) · [简体中文](README.zh-CN.md) · **日本語**

<p align="center">
  <img src="assets/banner.svg" alt="Expo Launchpad" width="100%">
</p>
<p align="center">
  <b>アイデアから出荷可能な iOS + Android アプリ／ゲームまで —— Expo（React Native + TypeScript）上に構築された、懐疑的QAを備えたAIハーネス。</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-alpha-orange" alt="status: alpha">
  <img src="https://img.shields.io/badge/Claude%20Code-plugin-8A2BE2" alt="Claude Code plugin">
  <img src="https://img.shields.io/badge/Expo-000020?logo=expo&logoColor=white" alt="Expo">
  <img src="https://img.shields.io/badge/TypeScript-strict-3178C6?logo=typescript&logoColor=white" alt="TypeScript">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT">
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen" alt="PRs welcome">
  <a href="https://ko-fi.com/riversound"><img src="https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E5B?logo=ko-fi&logoColor=white" alt="Support on Ko-fi"></a>
</p>

## これは何か

Expo Launchpad は、アイデアを*プレイ可能な* iOS + Android アプリ **または**
ゲームへと仕上げる Claude Code プラグインです。ゲート付きのフェーズで計画・構築を行い、
最後に懐疑的な evaluator がシミュレーター上でアプリを起動してスクリーンショットを
じっくり検証してから、はじめて「完了」と判断します。

<details><summary>目次</summary>

- [特徴](#特徴)
- [デモ](#デモ)
- [クイックスタート](#クイックスタート)
- [仕組み](#仕組み)
- [フラグ](#フラグ)
- [生成されるスタック](#生成されるスタック)
- [必要環境](#必要環境)
- [なぜ Expo Launchpad なのか](#なぜ-expo-launchpad-なのか)
- [よくある質問](#よくある質問)
- [ロードマップ](#ロードマップ)
- [サポート](#サポート)
- [コントリビュート](#コントリビュート)
- [クレジットとライセンス](#クレジットとライセンス)
</details>

## 特徴

- 💡 アイデア → プレイ可能な成果物へのパイプライン —— コードが1行も生成される前に research、plan、design、contract を実施。
- 📱🎮 同じハーネスでアプリ**と**ゲームの両方を作れる (`--kind`)。
- 🕵️ 懐疑的なQA —— evaluator が実機同等のシミュレーターでアプリを実行してスクリーンショットを検証し、スタブ（stub）を検出すると自動的に失敗と判定。
- ✅ 8 個の hard gate に加え、R1–R11 のプラットフォーム堅牢性ゲート（オーディオ、ライフサイクル、アクセシビリティなど）。
- 🔋 永続保存、多言語対応（i18n）、アクセシビリティが最初の生成コミットから組み込み済み。
- 🎨 2つのレンダリング経路 —— アプリは Expo Router、ゲームは Skia。

## デモ

> 🚧 録画デモ（アイデア → シミュレーターで動くアプリ）は近日公開予定です。今のところは[仕組み](#仕組み)を参照してください。

## クイックスタート

```text
# in Claude Code
/plugin marketplace add https://github.com/SummerRiversound/expo-launchpad
/plugin install expo-launchpad

/expo-launchpad --kind app  "a habit tracker with streaks"
/expo-launchpad --kind game "a one-tap endless runner"
```

## 仕組み

<p align="center"><img src="assets/pipeline.svg" alt="Pipeline" width="100%"></p>

| フェーズ | 内容 |
|---|---|
| research | 市場・ジャンルを調査、またはアイデアが与えられている場合はクローン・フォールバックを確認。 |
| plan | PRD を作成し、アイデンティティ（`app_name`、`app_slug`、`bundle_id`）を確定。 |
| design | デザイントークンとビジュアル仕様を作成。 |
| contract | hard gate と functional criteria を協議。`AGREED` になるまで generator は開始しない。 |
| generator | ゲート付きのサブフェーズでアプリを構築。 |
| evaluator | シミュレーター上でアプリを実行し、コアフローを操作してスクリーンショットを検証してから判定。 |
| human-review | 実行完了前に、人による PASS のレビューを待って一時停止。 |

generator はゲート付きの3つのサブフェーズ（`6a` → `6b` → `6c`）で構築し、各フェーズは
`tsc --noEmit` + `expo lint` + `jest` によってゲートされます。FAIL になった場合、evaluator は
その回をもう一度やり直すために差し戻します。

## フラグ

| フラグ | デフォルト | 意味 |
|---|---|---|
| `--kind app\|game` | `app` | 何を作るか。 |
| `--engine skia` | `skia` | レンダーエンジン（ゲームのみ）。 |
| `--strict` | off | evaluator に品質スコアリングとエッジケースの洗い出しを追加する。 |
| `--rounds N` | `3` | 強制判定に至るまでの generator ⇄ evaluator の最大ラウンド数。 |
| `--skip-research` | off | research をスキップする。この場合、構築元となるアイデアが必須。 |
| `--auto-idea` | off | ユーザーに尋ねる代わりに、research が推奨したコンセプトを自動選択する。 |
| `--auto-deploy` | off | evaluator の PASS 後の処理方法が変わる。 |
| `--resume` | — | 一時停止した実行を再開する。 |

読み取り専用の付随レポーター：`/expo-launchpad-status` —— フェーズ、ラウンド、次の役割、一時停止の理由を表示。

## 生成されるスタック

| ツール | 役割 |
|---|---|
| Expo Router | アプリのナビゲーション (`kind: app`) |
| TypeScript (strict) | 言語 |
| Jest (`jest-expo`) + `@testing-library/react-native` | ユニットテスト・コンポーネントテスト |
| Maestro | E2E フローの検証 |
| `@shopify/react-native-skia` | ゲームレンダリング (`kind: game`) |
| `expo-audio` / `expo-haptics` / `expo-secure-store` / `expo-localization` / `expo-screen-orientation` | オーディオ、ハプティクス、セキュアストレージ、多言語対応、画面の向き |

## 必要環境

- Claude Code
- macOS + Xcode iOS シミュレーター —— evaluator が `npx expo run:ios` でビルドを判定
- Node
- Maestro（任意）—— E2E フローの検証に使用

## なぜ Expo Launchpad なのか

| | `create-expo-app` | 手動 | **Expo Launchpad** |
|---|:---:|:---:|:---:|
| プロジェクトのスキャフォールディング | ✅ | ➖ | ✅ |
| 市場・クローン調査 | ➖ | ➖ | ✅ |
| コード前の PRD + デザイン + contract | ➖ | ➖ | ✅ |
| アプリを実行して判定（懐疑的QA） | ➖ | 手動 | ✅ |
| 堅牢性ゲート（オーディオ、ライフサイクル、アクセシビリティ、永続保存） | ➖ | 手動 | ✅ |
| アプリ**と**ゲームの両方 | アプリのみ | どちらも可 | ✅ |

## よくある質問

**本当に今動くの？**
正直に言うと：まだ **alpha** 段階です。パイプライン全体は構築済みで自己検証も通りますが、
実際のアプリで end-to-end に一度通した実績はまだありません。ぜひ試して issue を送ってください
—— そのフィードバックこそ今いちばん必要なものです。

**なぜ Expo なのか？**
1つの TypeScript コードベースで iOS + Android の両方をカバーでき、evaluator が扱える
高速なシミュレーターループが得られます。

**アプリ、それともゲーム？**
どちらも対応 —— `--kind app` は Expo Router を、`--kind game` は Skia のレンダーループを使用します。

**Phase B とは？**
デプロイ関連：EAS Build/Submit、ストアのスクリーンショット・メタデータ、広告 —— 計画中で
まだ未実装です。

**Mac は必要？**
evaluator のシミュレーター実行には必要です（`npx expo run:ios` は Xcode が必要）。

## ロードマップ

- [x] Phase A —— アイデア → プレイ可能な成果物（今回のリリース）
- [ ] Phase B —— EAS build/submit、ストア用アセット、広告
- [ ] 録画デモ + サンプルアプリ

## サポート

Expo Launchpad が時間の節約に役立ったら、[コーヒーを一杯](https://ko-fi.com/riversound) ☕ おごっていただけると、プロジェクトの継続に大きな励みになります。ありがとうございます！

<a href="https://ko-fi.com/riversound"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi" height="36"></a>

## コントリビュート

コントリビュート歓迎です —— [CONTRIBUTING.md](CONTRIBUTING.md) と [SECURITY.md](SECURITY.md) を参照してください。
PR を開く前に `bash scripts/validate.sh` が通る必要があります。

## クレジットとライセンス

MIT —— 詳細は [LICENSE](LICENSE) を参照してください。本プロジェクトは
[`flutter-flame-harness`](https://github.com/tjdrhs90/flutter-flame-harness)（MIT、作者 tjdrhs90）の
構造的な移植版です —— 詳細は [NOTICE](NOTICE) を参照してください。

<p align="center">⭐ 役に立ったら <b>Star</b> をお願いします —— ほかの人がこのプロジェクトを見つける助けになります。</p>
