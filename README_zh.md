# ComplexSweeper

[English](README.md) | 简体中文

支持圆复数与双曲复数雷值的原生移动端和桌面端扫雷变体。

## 项目概述

游戏将带符号实部和虚部雷值相加，不直接统计邻雷数量。圆复数与双曲复数模式均提供三档难度、首击保护、标记和记录；显示 0 可能源于抵消，不代表周围无雷。HarmonyOS、Android 和 Apple 工程分别实现规则。

## 技术栈与依赖

HarmonyOS 使用 ArkTS/ArkUI/HDS 与 DevEco Studio，最低 API 23；Android 使用 Kotlin/Compose 与 Gradle，最低 API 31；Apple 使用 SwiftUI 与平台界面接口，最低 iOS/iPadOS 17、macOS 14。各平台独立管理依赖与构建。

## 文件结构

- `HarmonyOS/` — HarmonyOS 原生工程
- `Android/` — Android 原生工程
- `Apple Platform/` — Apple 平台工程
- `docs/` — 规则、移植与发布说明
- `scripts/` — 公共验证与资源工具
- `LICENSE` — GPL-3.0 许可证

## 快速上手

按平台选择入口：

- 在 DevEco Studio 打开 `HarmonyOS/`，配置本地签名后运行。
- 在 Android Studio 打开 `Android/`，或在该目录执行 `./gradlew :app:assembleDebug`。
- 在 Xcode 打开 `Apple Platform/ComplexSweeper-Apple.xcodeproj`，选择运行目标并配置本地签名。

具体前提参见各平台说明：[HarmonyOS](HarmonyOS/README.md)、[Android](Android/README.md)、[Apple](Apple%20Platform/README.md)。规则及保留素材源于[上游 Windows 实现](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game)。移植代码采用 GPL-3.0，原始位图素材的独立权利以许可材料为准。
