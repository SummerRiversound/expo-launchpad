[English](README.md) · [한국어](README.ko.md) · **简体中文** · [日本語](README.ja.md)

<p align="center">
  <img src="assets/banner.svg" alt="Expo Launchpad" width="100%">
</p>
<p align="center">
  <b>从创意到可发布的 iOS + Android 应用或游戏 —— 基于 Expo（React Native + TypeScript）打造的严苛质检 AI 框架。</b>
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

## 这是什么

Expo Launchpad 是一个 Claude Code 插件，能把一个创意变成*可玩的* iOS + Android 应用**或**
游戏。它先在层层把关的阶段中完成规划与构建，再由一个严苛的 evaluator 在模拟器上启动应用、
仔细查看截图，确认无误后才会宣布"完成"。

<details><summary>目录</summary>

- [功能特性](#功能特性)
- [演示](#演示)
- [快速开始](#快速开始)
- [工作原理](#工作原理)
- [参数](#参数)
- [生成的技术栈](#生成的技术栈)
- [环境要求](#环境要求)
- [为什么选择 Expo Launchpad？](#为什么选择-expo-launchpad)
- [常见问题](#常见问题)
- [路线图](#路线图)
- [支持](#支持)
- [贡献指南](#贡献指南)
- [致谢与许可证](#致谢与许可证)
</details>

## 功能特性

- 💡 创意 → 可玩成品的流水线 —— 在生成第一行代码之前，先完成 research、plan、design 与 contract。
- 📱🎮 同一套框架既能做应用**又**能做游戏 (`--kind`)。
- 🕵️ 严苛质检 —— evaluator 会在真实模拟器上运行应用并查看截图；一旦发现桩代码（stub）就直接判定失败。
- ✅ 8 项 hard gate，外加 R1–R11 平台健壮性关卡（音频、生命周期、无障碍等）。
- 🔋 从第一次生成的提交开始，就内置了持久化存档、多语言（i18n）与无障碍支持。
- 🎨 两条渲染路径 —— 应用用 Expo Router，游戏用 Skia。

## 演示

> 🚧 录屏演示（从创意到模拟器中运行的应用）即将推出。目前请先参考[工作原理](#工作原理)。

## 快速开始

```text
# in Claude Code
/plugin marketplace add https://github.com/SummerRiversound/expo-launchpad
/plugin install expo-launchpad

/expo-launchpad --kind app  "a habit tracker with streaks"
/expo-launchpad --kind game "a one-tap endless runner"
```

## 工作原理

<p align="center"><img src="assets/pipeline.svg" alt="Pipeline" width="100%"></p>

| 阶段 | 作用 |
|---|---|
| research | 调研市场/品类，若已给出创意则检查是否有可参考的同类产品（clone-fallback）。 |
| plan | 撰写 PRD 并锁定身份信息（`app_name`、`app_slug`、`bundle_id`）。 |
| design | 产出设计 token 与视觉规范。 |
| contract | 就 hard gate 与 functional criteria 进行约定；在状态变为 `AGREED` 之前，generator 不会启动。 |
| generator | 分阶段把关地构建应用。 |
| evaluator | 在模拟器上运行应用、操作核心流程、查看截图后再做判定。 |
| human-review | 在本轮运行结束前，暂停等待人工复核 PASS 结果。 |

generator 会分 3 个把关的子阶段（`6a` → `6b` → `6c`）构建，每个子阶段都要通过
`tsc --noEmit` + `expo lint` + `jest` 的检查。一旦出现 FAIL，evaluator 会把本轮运行打回去重新来一轮。

## 参数

| 参数 | 默认值 | 含义 |
|---|---|---|
| `--kind app\|game` | `app` | 要构建的类型。 |
| `--engine skia` | `skia` | 渲染引擎（仅游戏适用）。 |
| `--strict` | off | 让 evaluator 额外做质量评分和边界情况扫描。 |
| `--rounds N` | `3` | 强制判定前，generator ⇄ evaluator 的最大轮数。 |
| `--skip-research` | off | 跳过 research；此时必须提供一个创意作为构建起点。 |
| `--auto-idea` | off | 自动选用 research 推荐的方案，而不是询问用户。 |
| `--auto-deploy` | off | 改变 evaluator 判定 PASS 之后的处理方式。 |
| `--resume` | — | 继续一个已暂停的运行。 |

配套的只读状态查询命令：`/expo-launchpad-status` —— 显示阶段、轮数、下一个角色、暂停原因。

## 生成的技术栈

| 工具 | 作用 |
|---|---|
| Expo Router | 应用导航 (`kind: app`) |
| TypeScript (strict) | 语言 |
| Jest (`jest-expo`) + `@testing-library/react-native` | 单元测试与组件测试 |
| Maestro | E2E 流程检查 |
| `@shopify/react-native-skia` | 游戏渲染 (`kind: game`) |
| `expo-audio` / `expo-haptics` / `expo-secure-store` / `expo-localization` / `expo-screen-orientation` | 音频、触感反馈、安全存储、多语言、屏幕方向 |

## 环境要求

- Claude Code
- macOS + Xcode iOS 模拟器 —— evaluator 通过 `npx expo run:ios` 来判定构建结果
- Node
- Maestro（可选）—— 用于支持 E2E 流程检查

## 为什么选择 Expo Launchpad？

| | `create-expo-app` | 手动实现 | **Expo Launchpad** |
|---|:---:|:---:|:---:|
| 项目脚手架 | ✅ | ➖ | ✅ |
| 市场/同类产品调研 | ➖ | ➖ | ✅ |
| 编码前的 PRD + 设计 + contract | ➖ | ➖ | ✅ |
| 运行应用并做判定（严苛质检） | ➖ | 手动 | ✅ |
| 健壮性关卡（音频、生命周期、无障碍、持久化存档） | ➖ | 手动 | ✅ |
| 应用**与**游戏 | 仅应用 | 均可 | ✅ |

## 常见问题

**现在真的能用了吗？**
说实话：目前还是 **alpha** 阶段。整套流水线已经搭建完成，也能自我校验，但还没有真正跑过一次
从创意到应用发布的完整 end-to-end 流程。欢迎试用并提交 issue —— 这正是现在最需要的反馈。

**为什么选择 Expo？**
一套 TypeScript 代码库即可覆盖 iOS + Android，还有一个 evaluator 能驱动的快速模拟器循环。

**做应用还是做游戏？**
两者都支持 —— `--kind app` 使用 Expo Router；`--kind game` 使用 Skia 渲染循环。

**Phase B 是什么？**
部署相关：EAS Build/Submit、商店截图/元数据、广告接入 —— 已规划，尚未实现。

**需要 Mac 吗？**
evaluator 的模拟器运行环节需要（`npx expo run:ios` 依赖 Xcode）。

## 路线图

- [x] Phase A —— 创意 → 可玩成品（本次发布）
- [ ] Phase B —— EAS build/submit、商店素材、广告
- [ ] 录屏演示 + 示例应用

## 支持

如果 Expo Launchpad 帮你节省了时间，欢迎[请我喝杯咖啡](https://ko-fi.com/riversound) ☕ —— 这能让项目持续前进。谢谢！

<a href="https://ko-fi.com/riversound"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi" height="36"></a>

## 贡献指南

欢迎贡献 —— 请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [SECURITY.md](SECURITY.md)。
提交 PR 前必须先通过 `bash scripts/validate.sh`。

## 致谢与许可证

MIT —— 详见 [LICENSE](LICENSE)。本项目是对
[`flutter-flame-harness`](https://github.com/tjdrhs90/flutter-flame-harness)（MIT，作者 tjdrhs90）
的结构化移植 —— 详见 [NOTICE](NOTICE)。

<p align="center">⭐ 如果这个项目对你有帮助，欢迎 <b>Star</b> 一下 —— 这能帮助更多人发现它。</p>
