# Apple 平台移植与工程说明

本目录是复扫雷的 iOS / iPadOS / macOS 原生工程，使用单一 SwiftUI target。
应用介绍、玩法、原作致谢与共同移植范围见[仓库总 README](../README.md)。以下命令均在 `Apple Platform/` 中执行。

## 工程配置

| 项目 | 配置 |
| --- | --- |
| 系统 | iOS / iPadOS 17+、macOS 14+ |
| 语言 / 界面 | Swift 5 语言模式、SwiftUI，UIKit / AppKit 输入适配 |
| Project / target / scheme | `ComplexSweeper-Apple` |
| 产品名 / 显示名 | `复扫雷.app` / 复扫雷 |
| Bundle identifier | `top.rayawa.complexsweeper.apple` |
| 状态管理 | Observation |
| 音效 / 触感 | AVAudioPlayer / 系统触感 |
| 存档 | UserDefaults |

Xcode 项目使用同步目录，将应用和测试目录下的源文件加入对应 target；资源与编译配置由 Xcode 工程管理。

## 目录结构

```text
Apple Platform/
├── ComplexSweeper-Apple.xcodeproj/   Xcode 项目、构建配置、共享 scheme
├── ComplexSweeper-Apple/
│   ├── ComplexSweeperApp.swift      SwiftUI 应用入口
│   ├── Model/                      复数、难度、战绩与存档
│   ├── Engine/
│   │   ├── BoardModel.swift         随机数、单格状态与引擎辅助类型
│   │   └── Board.swift              布雷、翻开、标记、展开与胜负判定
│   ├── View/                       控制器、棋盘、格子、计雷器、教程与反馈
│   └── Assets.xcassets/             游戏 imageset 与 AppIcon
├── ComplexSweeper-AppleUITests/     XCUITest 交互回归
├── assets/                         上游原始图集与槽位 JSON
├── Tools/
│   ├── slice-atlas.ts              图集转 Xcode imageset
│   ├── make-icon.ts                iOS / macOS 应用图标与难度标签图标
│   ├── png.ts                      PNG 编解码
│   └── engine-check/               Swift 命令行引擎回归
└── docs/ASSETS.md                   素材来源、清单与授权说明
```

六段 WAV 放在应用源码目录中，由 Xcode 打包进应用资源。

## 移植架构与平台适配

`Model` 使用整数实虚分量和模长平方表达规则，`Engine` 保持与其他两端相同的 mulberry32 随机数和固定种子行为。
UI 将操作交给 `GameController`，由控制器调用 `Board.reveal`、`cycleFlag`、`tryExpand`，并处理计时、战绩、音效及提示。
首击布雷由引擎完成，避免在界面重复执行开局逻辑。

`Board`、`Cell`、`GameController` 使用 Observation。计雷器直接读取可观察的雷型总数与旗数，插旗后即刻更新。
棋盘数组与行列尺寸读取同一快照，重开时通过 `gameId` 重建滚动容器，避免难度切换越界与旧滚动位置残留。
计时使用 `ContinuousClock`，结算前刷新用时，并取消重开 / 结束前遗留的提示任务。

iOS / iPadOS 的格子使用 UIKit `TouchCatcher`：轻点必须等待 400ms 长按识别器失败，抬手、取消和滚动都会清除按下态。
macOS 使用 AppKit `MouseButtonCatcher`，左键翻开未翻开的格子，右键标记或展开数字格。
共用布局把格子边长限制在 16–36pt，像素图片关闭插值。
原作者署名使用 SwiftUI `Link` 打开上游 GitHub。

## 素材与图标生成

使用支持直接运行 TypeScript 的 Node 24+，从本目录执行：

```bash
node --experimental-strip-types Tools/slice-atlas.ts \
  assets/atlas.json assets/atlas.png ComplexSweeper-Apple/Assets.xcassets
node --experimental-strip-types Tools/make-icon.ts \
  assets/atlas.json assets/atlas.png ComplexSweeper-Apple/Assets.xcassets
```

游戏贴图使用单份原始位图 imageset，由视图最近邻放大。
应用图标从原作 32×32 `icon` 槽位生成：1024px 母图中主体为 512px，居中、银灰底，iOS 与 macOS 主体比例一致。
iOS 输出一张 1024px 图标；macOS 输出 16–512pt 的 1x / 2x 尺寸。
难度标签使用相同的 128px 画布和 2× / 3× / 4× 图案。授权与素材细节见 [ASSETS.md](docs/ASSETS.md)。

## 构建与安装

Scheme / target 保持 `ComplexSweeper-Apple`，构建产物为 `复扫雷.app`。

用 Xcode 打开 `ComplexSweeper-Apple.xcodeproj`，选择同名 scheme 和目标设备。真机构建使用 `Signing & Capabilities` 中已有的 Team、证书和描述文件。

```bash
# iOS / iPadOS 真机 Release 归档（使用本机签名配置）
xcodebuild archive -project ComplexSweeper-Apple.xcodeproj -scheme ComplexSweeper-Apple \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .build/ios -archivePath .build/ios/ComplexSweeper.xcarchive

# iOS 模拟器 App
xcodebuild build -project ComplexSweeper-Apple.xcodeproj -scheme ComplexSweeper-Apple \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/ios-simulator CODE_SIGNING_ALLOWED=NO

# macOS Release App
xcodebuild build -project ComplexSweeper-Apple.xcodeproj -scheme ComplexSweeper-Apple \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath .build/macos CODE_SIGNING_ALLOWED=NO
```

真机 App 在归档的 `Products/Applications/` 下；模拟器 App 在 `.build/ios-simulator/Build/Products/Release-iphonesimulator/`；macOS App 在 `.build/macos/Build/Products/Release/`。
模拟器 App 只用于模拟器。IPA 需用归档执行 Export；安装范围取决于导出方式及签名描述文件。

## 测试与验证

```bash
./Tools/engine-check/run.sh
xcodebuild test -project ComplexSweeper-Apple.xcodeproj -scheme ComplexSweeper-Apple \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO
```

测试设备名称按 `xcrun simctl list devices available` 调整。受限环境若阻止 Swift 宏插件，可为本地构建添加 `OTHER_SWIFT_FLAGS=-disable-sandbox`。

合并目录前的验证（2026-10-11）：引擎自检通过，iPhone 18 Pro / iOS 27 模拟器上 7 项 XCUITest 全部通过，macOS 共用目标构建通过。
覆盖首击保护、轻点 / 长按、完整旗帜循环、计雷器刷新、高级拖动与重开复位、反复切难度及教程弹层。

## 三端同步与维护

修改引擎规则时同步另外两端，并检查固定种子结果、首击保护、展开判据与胜负结算一致。
游戏图集和音效变更需要同步三个平台，图标通过本平台脚本重新生成。
共同功能与进度在[总 README](../README.md#移植范围与进度)维护；本目录保留平台实现和工程说明。
详细历史回归见 [PORTING_STATUS.md](docs/PORTING_STATUS.md)，源码许可证见 [LICENSE](LICENSE)。
