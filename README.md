# ComplexSweeper · 复扫雷

> 扫雷，但雷是复数。

复扫雷是一款保留经典扫雷像素风格的逻辑游戏。棋盘上有四种雷：+1、−1、+i、−i。
格子上的数字是周围所有雷之和的模长，翻开全部非雷格子即可通关。
正负雷可以互相抵消，因此看见 0 不代表周围没有雷。

本仓库统一维护 **HarmonyOS、Android、iOS / iPadOS / macOS** 的原生移植。
三端共用原作的规则、随机数算法、图像和音效，各自使用平台原生界面与系统能力。

## 原作与移植说明

原作是[青月晓](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game)开发的
[Complexweeper Windows 版](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game)，使用 Zig / Win32。
本项目以原作 **v1.2.0** 为移植基准，由 **Ray Chen（Rayawa）**维护；先以鸿蒙版建立移动端实现，再对齐 Apple 和安卓版本。
感谢原作者与上游贡献者提供游戏设计、24 个可达显示值、展开判据、像素素材和六段音效。
三端应用「关于」中的原作者署名均可点击打开原仓库。

原作对外名称拼作 **Complexweeper**，本项目采用其内部窗口类名 **ComplexSweeper**；应用中文名称统一为「复扫雷」。
Windows 原作通过上面的链接访问，不包含在本仓库的三个平台工程中。

## 下载与安装

首个版本为 [v1.0.0](https://github.com/Rayawa/ComplexSweeper/releases/tag/v1.0.0)。安装包、校验文件与签名说明见 Release 页面；应用内版本显示为 `1.0`。

## 支持平台

| 平台 | 系统要求 | 实现 | 工程文档 |
| --- | --- | --- | --- |
| HarmonyOS | 工程最低兼容 6.1.0（API 23） | ArkTS / ArkUI / HDS | [HarmonyOS 移植与工程说明](HarmonyOS/README.md) |
| Android | Android 12+（API 31） | Kotlin / Jetpack Compose | [Android 移植与工程说明](Android/README.md) |
| iOS / iPadOS | 17+ | SwiftUI / UIKit | [Apple 平台移植与工程说明](Apple%20Platform/README.md) |
| macOS | 14+ | SwiftUI / AppKit | [Apple 平台移植与工程说明](Apple%20Platform/README.md) |

## 规则与玩法

四种雷分别是正实雷 +1、负实雷 −1、正虚雷 +i、负虚雷 −i，其中 i² = −1。
一个格子的数字由八邻域内所有雷相加，再取复数的模长得到。
例如周围有一颗 +1 和一颗 −i，和为 1−i，格子显示 √2。
八邻域最多有八颗雷，共有 24 种可达显示值。

**空白和 0 不同**：空白表示周围完全没有雷，会自动连片展开；0 表示周围有雷，但正负抵消，不会继续扩散。
插了旗的格子不能翻开，首击和连片展开也会绕开旗子；需要先撤旗。
首次翻开时才布雷，首击格及其八邻域安全（九宫格），四种雷的数量随机分配，开局后在顶部四个计雷器上公布。

| 难度 | 棋盘（列 × 行） | 雷数 |
| --- | --- | --- |
| 初级 | 9 × 9 | 10 |
| 中级 | 16 × 16 | 40 |
| 高级 | 30 × 16 | 99 |

高级棋盘在小屏幕上可以横向拖动，矮窗支持纵向滚动。
点人脸重开当前难度，切换到另一档难度会开启新局；重复选择当前难度保留当前局。
标题栏「关于」包含教程、版本、原作者和移植者信息。

| 操作 | HarmonyOS / Android / iOS / iPadOS | macOS |
| --- | --- | --- |
| 翻开未标记的格子 | 长按 400ms | 左键 |
| 标记未翻开的格子 | 轻点 | 右键 |
| 展开已翻开的数字格 | 轻点 | 右键 |
| 重开 | 点人脸按钮 | 点人脸按钮 |

标记按「空 → +1 → −1 → +i → −i → 空」循环。
展开要求周围旗数等于真实雷数，且实虚雷数比例与真实比例相同或互为倒数；条件不满足时给出提示。
翻开全部非雷格即获胜，踩雷则失败。结局会显示全部雷，并给旗帜标对错：雷上绿勾、非雷上红叉，判断位置而不评判旗帜类型。
各难度保存最快纪录，并提供计时、音效和平台触感反馈。

## 移植范围与进度

更新时间：2026-10-11。Windows 原作用于核对规则，鸿蒙版用于确定三端共同功能范围。

| 功能 | HarmonyOS | Apple | Android |
| --- | --- | --- | --- |
| 圆复数、四种雷、24 个显示值 | 已实现 | 已实现 | 已实现 |
| 三档难度、随机雷型、首击九宫格安全 | 已实现 | 已实现 | 已实现 |
| 空白连片展开、旗子保护、实虚比例展开判据 | 已实现 | 已实现 | 已实现 |
| 四计雷器、计时、人脸重开、教程、最快纪录 | 已实现 | 已实现 | 已实现 |
| 胜负复盘、像素贴图、六段音效 | 已实现 | 已实现 | 已实现 |
| 触屏轻点 / 长按、数字展开、棋盘滚动 | 已实现 | 已实现 | 已实现 |
| 双曲复数 / 闵可夫斯基模式 | 未移植 | 未移植 | 未移植 |
| 自定义雷区与指定四雷配比 | 未移植 | 未移植 | 未移植 |
| 音效开关、独立纪录窗口 | 未移植 | 未移植 | 未移植 |

当前移植范围是**圆复数模式及标准三档难度**。原作中的双曲复数模式等扩展功能仍待移植。

已对齐首击、结束判定、计雷器刷新、轻点与长按互斥、重开滚动复位和单调时钟计时。
安卓使用 ViewModel 保留旋转重建前的局面。三端启动图标保留原作像素画，统一主体比例和银灰背景；安卓使用矢量自适应图标，Apple 应用名称统一为「复扫雷」。
详细实现、修复原因和验证方式见各平台工程文档。

## 仓库结构与开发入口

```text
ComplexSweeper/
├── README.md              应用介绍、玩法、移植范围、原作署名
├── Android/               Android 原生工程与技术文档
├── Apple Platform/        iOS / iPadOS / macOS 共用 Xcode 工程与技术文档
└── HarmonyOS/             HarmonyOS 原生工程与技术文档
```

三个平台工程保留各自的源码、资源、依赖配置与构建工具；当前没有跨语言共享的运行时引擎。
修改规则时需要同步三份实现，并运行各平台的固定种子回归，检查相同输入下的棋盘和结算行为一致。

开发时用 Android Studio 打开 `Android/`，用 Xcode 打开 `Apple Platform/ComplexSweeper-Apple.xcodeproj`，
用 DevEco Studio 打开 `HarmonyOS/`。构建命令在对应平台目录内执行，签名使用开发者自己的配置。
APK / AAB、HAP、App / IPA 的输出路径和安装方式见各平台 README。

GitHub Actions 按新目录执行鸿蒙引擎自检、安卓单测 / lint / Debug 构建、Apple 引擎自检及 macOS / iOS 模拟器未签名构建。HarmonyOS HAP 与 Apple 真机签名产物在本机 SDK / 签名环境生成。首个 Release 的附件用途与签名边界见 [v1.0.0 发布说明](docs/releases/v1.0.0.md)。

产品介绍、共同玩法、整体范围与原作署名集中维护在本文件；各平台 README 维护架构、目录、平台适配、资源生成、构建与验证说明。

## 验证记录

以下为 2026-10-11 的验证记录，不表示已在所有目标设备上验收：

- 三端引擎通过各 360 局随机棋盘不变量检查和六组一致的固定种子指纹；77 张游戏 PNG 与六段 WAV 一致。
- Apple：七项 iOS 模拟器 XCUITest 通过，macOS / iOS 真机归档 / 模拟器构建通过；署名链接更新后再次通过「关于」弹层回归。
- Android：13 项 JVM 单测、应用与设备测试 APK 构建通过；最新 lint 为零错误。四项设备交互测试已编译，尚待连接设备执行。
- HarmonyOS：引擎自检与 HAP 构建通过，尚待本次真机交互验收。
- 图标主体像素对比、构建产物完整性及 Android / iOS 开发签名校验通过；桌面遮罩与外链跳转仍需实际设备确认。

## 授权与素材

移植代码按 [GPL-3.0](LICENSE) 发布，许可证文本也保留在各平台工程中：
[HarmonyOS](HarmonyOS/LICENSE)、[Android](Android/LICENSE)、[Apple](Apple%20Platform/LICENSE)。

原始扫雷图像版权属于 Microsoft，原版作者为 Robert Donner、Curt Johnson，这部分图像不属于 GPL-3.0 授权范围。
新增图像与音效由青月晓按 GPL-3.0 发布。
逐槽位素材清单、来源与生成说明见 [HarmonyOS 素材说明](HarmonyOS/docs/ASSETS.md)、
[Android 素材说明](Android/docs/ASSETS.md)与 [Apple 素材说明](Apple%20Platform/docs/ASSETS.md)。

本项目与 Microsoft 无隶属关系，也未获其授权或背书；相关商标属于各自权利人。
