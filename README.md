# ComplexSweeper · 复扫雷

English | [简体中文](README_zh.md)


> Minesweeper, with complex-valued mines.

ComplexSweeper is a logic game retaining the classic pixel-art Minesweeper style, with circular-complex and Minkowski modes.
There are four mine types: +1, −1, +i and −i in circular-complex mode, and +1, −1, +j and −j in Minkowski mode.
A cell's value is computed from the sum of surrounding mines under the selected mode. Reveal every non-mine cell to win.
In both modes, a displayed 0 does not mean that no mines are nearby.

This repository maintains native ports for **HarmonyOS, Android, iOS / iPadOS / macOS**.
The three platform projects share the original rules, random-number algorithm, images and sound effects, while using native platform UI and system capabilities.

## Original Game and Ports

The original is the [upstream project's](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game)
[Complexweeper for Windows](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game), implemented in Zig / Win32.
This project follows upstream main commit **`f6b80bb` (source version 1.3.0)** and is maintained by the project maintainer. The HarmonyOS port established the mobile implementation, followed by the Apple and Android versions.
Thanks to the original project and upstream contributors for the game design, 24 reachable circular-complex values, 39 split-complex values, expansion criteria, pixel assets and six sound effects.
The upstream credit in each platform's About screen opens the original repository.

The original public name is **Complexweeper**; this project uses its internal window-class name, **ComplexSweeper**. The Chinese application name is consistently “复扫雷”.
The Windows original is accessible through the links above and is not included in the three platform projects here.

## Downloads and Installation

Current version: **1.2.0**, adding color/monochrome appearance switching and long-press flag removal with reveal. See [v1.2.0 Release](https://github.com/Rayawa/ComplexSweeper/releases/tag/v1.2.0) and the [release notes](docs/releases/v1.2.0.md).

- Android: download `ComplexSweeper-v1.2.0-android.apk`. It uses the same development/test certificate as the first release and can be installed directly.
- macOS: download `ComplexSweeper-v1.2.0-macos.zip` and extract `复扫雷.app`. It supports Apple Silicon and Intel, without Developer ID distribution signing or notarization.
- HarmonyOS: download `ComplexSweeper-v1.2.0-harmonyos-unsigned.hap` and sign it with your own certificate and profile before installation.
- iOS / iPadOS: separate ZIPs contain an unsigned physical-device app and a simulator app. Sign the device app yourself; simulator packages run only in a simulator.

The release also provides unsigned Android APK / AAB files, `SHA256SUMS.txt` and `manifest.json`. See the release notes for artifact purposes, signing scope and verification.

## Supported Platforms

| Platform | System Requirement | Implementation | Project Documentation |
| --- | --- | --- | --- |
| HarmonyOS | Minimum project compatibility: 6.1.0 (API 23) | ArkTS / ArkUI / HDS | [HarmonyOS port and project guide](HarmonyOS/README.md) |
| Android | Android 12+ (API 31) | Kotlin / Jetpack Compose | [Android port and project guide](Android/README.md) |
| iOS / iPadOS | 17+ | SwiftUI / UIKit | [Apple platform guide](Apple%20Platform/README.md) |
| macOS | 14+ | SwiftUI / AppKit | [Apple platform guide](Apple%20Platform/README.md) |

## Rules and Play

**Circular-complex mode** uses positive real +1, negative real −1, positive imaginary +i and negative imaginary −i mines, where i² = −1.
A cell sums the mines in its eight-cell neighborhood and displays the magnitude of that complex sum.
For example, one +1 and one −i sum to 1−i, so the cell displays √2.
Up to eight neighboring mines produce 24 reachable display values.

**Blank and 0 are different**: blank means no adjacent mines and expands automatically; 0 means mines are present but cancel, and does not continue expanding.
Long-pressing a flagged cell removes its flag and reveals it, updating mine counters. Blank-region and numbered-cell expansion still skip other flagged cells.
Mines are placed only on the first reveal, protecting the clicked cell and its eight neighbors. Counts of the four types are randomized and announced in the four top counters once play begins.

| Difficulty | Board (Columns × Rows) | Mines |
| --- | --- | --- |
| Beginner | 9 × 9 | 10 |
| Intermediate | 16 × 16 | 40 |
| Expert | 30 × 16 | 99 |

The expert board scrolls horizontally on small screens; short windows support vertical scrolling.
Bottom tabs select circular-complex or Minkowski mode. The segment above the board selects Beginner / Intermediate / Expert.
Tap the face to restart the current mode/difficulty. Changing mode retains difficulty and restarts; changing difficulty retains mode and restarts. Selecting the current item again preserves the game.
The title-bar About screen contains the tutorial, version and original-project/port credits.

| Action | HarmonyOS / Android / iOS / iPadOS | macOS |
| --- | --- | --- |
| Reveal an unrevealed cell, clearing its flag if present | Long-press 400ms | Left click |
| Flag an unrevealed cell | Tap | Right click |
| Expand a revealed numbered cell | Tap | Right click |
| Restart | Tap the face | Click the face |

Flags cycle through blank → +1 → −1 → +i / +j → −i / −j → blank.
Circular-complex expansion requires the adjacent flag count to equal the actual mine count, and the real/imaginary mine ratio to match the actual ratio or its reciprocal. Split-complex criteria are described below. A hint appears when the conditions are not satisfied.
Reveal all non-mine cells to win; hitting a mine loses. At the end, all mines appear and flags receive a green check on mines or a red cross on safe cells. Positions are judged, not flag types.
Each mode stores fastest times for three difficulties and win/loss counts, with a timer, sound and platform haptics. Existing circular-complex save keys remain unchanged.

## Minkowski Mode

The split-complex imaginary unit satisfies j² = +1. Mines are +1, −1, +j and −j; the real component is spacelike and the j component timelike.
For a neighborhood sum a+bj, the cell stores integer D = a²−b² and displays √D. If D<0, it displays √|D|i; for example, −4 displays 2i.
The eight-cell neighborhood has 39 reachable values. +1 and +j can produce 0, so zero need not result from opposite-sign cancellation. Only a completely mine-free blank neighborhood expands automatically.

The original source's strict default expansion criterion requires the flag count to equal the actual mine count and the absolute real and imaginary components of the net flag and mine sums to match separately. Components may change sign, but real and j components cannot be exchanged. The alternative criterion based only on equal displayed values is not exposed as a game setting.
Mine, flag, explosion, correct-flag and counter textures use i / j according to mode. The i in negative display values denotes a displayed unit and differs from the j mine unit.

## Porting Scope and Progress

Updated 2026-10-18. All three ports follow upstream `f6b80bb` (source version 1.3.0), including color/monochrome atlases, appearance switching and long-press flag clearing/reveal. Port application version: 1.2.0.

| Feature | HarmonyOS | Apple | Android |
| --- | --- | --- | --- |
| Circular-complex mode, four mine types and 24 values | Implemented | Implemented | Implemented |
| Three difficulties, random mine types and first-click 3×3 protection | Implemented | Implemented | Implemented |
| Blank expansion, long-press flag clearing/reveal and real/imaginary-ratio expansion | Implemented | Implemented | Implemented |
| Four mine counters, timer, face restart, tutorial and fastest records | Implemented | Implemented | Implemented |
| Endgame review, pixel textures and six sounds | Implemented | Implemented | Implemented |
| Touch tap/long-press, numbered-cell expansion and board scrolling | Implemented | Implemented | Implemented |
| Split-complex/Minkowski mode, 39 values and strict expansion | Implemented | Implemented | Implemented |
| Bottom mode tabs, separate difficulty selection and per-mode records | Implemented | Implemented | Implemented |
| Custom boards and specified four-type mine ratios | Not ported | Not ported | Not ported |
| Color/monochrome switching and saved appearance preference | Implemented | Implemented | Implemented |
| Sound toggle and separate records window | Not ported | Not ported | Not ported |

Current ports cover **circular-complex and Minkowski modes with three standard difficulties**. Custom boards, specified mine-type ratios, sound toggles and a separate records window remain unported.

First-click behavior, end conditions, counter refresh, tap/long-press exclusivity, restart scroll reset and monotonic-clock timing are aligned.
Android retains game state across rotation through ViewModel. Launcher icons retain the original pixel art with consistent proportions and silver-gray backgrounds. Android uses adaptive vector icons; Apple display names are consistently “复扫雷”.
Platform project guides describe implementation details, fixes and validation.

## Repository Structure and Development Entry Points

```text
ComplexSweeper/
├── README.md              App overview, gameplay, port scope, upstream credits
├── Android/               Native Android project and technical documentation
├── Apple Platform/        Shared iOS / iPadOS / macOS Xcode project and technical documentation
└── HarmonyOS/             Native HarmonyOS project and technical documentation
```

Each platform retains its own source, resources, dependency configuration and build tools. There is currently no shared cross-language runtime engine.
Rule changes must update all three implementations and run each platform's fixed-seed regressions to confirm identical boards and outcomes for identical inputs.

Open `Android/` in Android Studio and `Apple Platform/ComplexSweeper-Apple.xcodeproj` in Xcode,
and open `HarmonyOS/` in DevEco Studio. Run build commands in the respective platform directories and use your own signing configuration.
See each platform README for APK / AAB, HAP and App / IPA outputs and installation.

GitHub Actions runs HarmonyOS engine self-checks, Android unit tests/lint/Debug builds, Apple engine self-checks and unsigned macOS/iOS simulator builds. HarmonyOS HAP and signed Apple device artifacts use the local SDK/signing environment. Current release artifact purposes and signing details are in the [v1.2.0 notes](docs/releases/v1.2.0.md).

This file centralizes the product introduction, shared rules, overall scope and upstream credits. Platform READMEs document architecture, layout, adaptation, asset generation, builds and verification.

## Validation Records

Version 1.2.0 asset sources, appearance settings, generation and verification are in the [appearance synchronization record](docs/APPEARANCE_SYNC.md).
See [device validation](docs/VALIDATION_2026-10-18.md) for the 2026-10-18 HarmonyOS top bar and iPhone/iPad checks.
The top Color / Monochrome selector can change at any time. Color is the default; the preference survives restart. Switching preserves the current board, flags and timer.


2026-10-12 validation for 1.1.0:

| Check | Result |
| --- | --- |
| Three platform engines | Each passed 360 circular-complex and 360 split-complex games; 39 split-complex values and 178,200 expansion checks passed; fixed-seed fingerprints matched in both modes |
| Resources | SHA-256 hashes matched for all 116 upstream atlas PNGs across platforms |
| Android | 15 JVM unit tests passed; lint had zero errors; app and device-test APKs built; device interaction tests were not run |
| Apple automation | 8 XCUITests passed on iPhone 18 Pro / iOS 27 Simulator; legacy-save compatibility and per-mode statistics isolation passed |
| iPhone 17 hardware | Modes/difficulties, flag cycling/protection, counters, restart and board dragging passed; titles were black in both light and dark modes |
| Local macOS | Left/right clicks, modes/difficulties, negative values, expansion hints, tutorial and black title passed |
| Huawei Mate 70 Pro+ hardware | All 5 Hypium / UiTest cases passed, covering native difficulty segments, flag protection, counters/restart, repeated difficulty changes, About dismissal and centered credits |

Wireless iPhone XCUITest runner connection did not succeed. Physical-device results came from direct interaction in the official device window; the 8 automated results above came from the simulator.
See [mode synchronization](docs/MODE_SYNC.md) for rule alignment and verification, and each platform's `docs/PORTING_STATUS.md` for history.

## Licensing and Assets

Port code is released under [GPL-3.0](LICENSE), with license texts also retained in each platform project:
[HarmonyOS](HarmonyOS/LICENSE)、[Android](Android/LICENSE)、[Apple](Apple%20Platform/LICENSE)。

Original Minesweeper image rights belong to Microsoft; those images are outside the GPL-3.0 grant.
Additional images and sounds are published by the upstream project under GPL-3.0.
For per-slot asset lists, sources and generation, see [HarmonyOS assets](HarmonyOS/docs/ASSETS.md),
[Android assets](Android/docs/ASSETS.md) and [Apple assets](Apple%20Platform/docs/ASSETS.md).

This project is not affiliated with Microsoft and is not authorized or endorsed by it. Trademarks belong to their respective rights holders.

Added 2026-10-18: long-pressing a flagged cell clears its flag and reveals it, refreshing counters; other flags remain protected during expansion. See [flag-reveal acceptance](docs/FLAG_REVEAL_2026-10-18.md) for validation and device limits.
