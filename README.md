# ComplexSweeper

English | [简体中文](README_zh.md)

Native mobile and desktop Minesweeper variants with complex and split-complex mine values.

## Overview

The game sums signed real and imaginary mine values rather than counting adjacent mines. Circular-complex and split-complex modes share three standard difficulties, first-click protection, flags and records. A displayed zero can result from cancellation and does not imply an empty neighborhood. Native HarmonyOS, Android and Apple projects implement the rules separately.

## Technology and Dependencies

HarmonyOS: ArkTS/ArkUI/HDS and DevEco Studio, minimum API 23. Android: Kotlin/Compose and Gradle, minimum API 31. Apple: SwiftUI with platform UI integration, iOS/iPadOS 17+ and macOS 14+. Each platform keeps its own dependencies and build configuration.

## Repository Structure

- `HarmonyOS/` — HarmonyOS native project
- `Android/` — Android native project
- `Apple Platform/` — shared Apple-platform project
- `docs/` — rules, porting and release notes
- `scripts/` — shared validation and asset tools
- `LICENSE` — GPL-3.0 license

## Quick Start

Choose a platform:

- Open `HarmonyOS/` in DevEco Studio and configure local signing before running.
- Open `Android/` in Android Studio, or run `./gradlew :app:assembleDebug` from that directory.
- Open `Apple Platform/ComplexSweeper-Apple.xcodeproj` in Xcode and select the destination and local signing configuration.

See the platform READMEs for exact build prerequisites: [HarmonyOS](HarmonyOS/README.md), [Android](Android/README.md), [Apple](Apple%20Platform/README.md). The project derives its rules and retained assets from the [upstream Windows implementation](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game). Port code uses GPL-3.0; original bitmap assets have separate rights described in the licensing material.
