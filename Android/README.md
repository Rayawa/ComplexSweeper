# Android 移植与工程说明

**当前版本 1.1.0（versionCode 2）**。底部 Tabs 切换圆复数 / 闵可夫斯基模式，棋盘上方使用 Material 3 `SingleChoiceSegmentedButtonRow` 选择难度。
下载与签名说明见 [v1.1.0 Release](https://github.com/Rayawa/ComplexSweeper/releases/tag/v1.1.0)。

本目录是复扫雷的 Kotlin / Jetpack Compose 原生工程。
应用介绍、玩法、原作致谢与共同移植范围见[仓库总 README](../README.md)。以下命令均在 `Android/` 中执行。

## 工程配置

| 项目 | 配置 |
| --- | --- |
| 系统 | Android 12+；minSdk 31，compileSdk / targetSdk 37 |
| 构建 | AGP 9.4.1、Gradle 9.6.0、Kotlin Compose 插件 2.2.10 |
| Compose | BOM 2026.02.01、Material 3 |
| Gradle JVM | `gradle-daemon-jvm.properties` 配置 toolchain 25 |
| Java 编译目标 | Java 11 |
| Namespace / applicationId | `top.rayawa.dashboard.complexsweeper.android` |
| 状态管理 | ViewModel / Compose 快照状态 |
| 音效 / 触感 / 存档 | SoundPool / Vibrator / SharedPreferences |

版本集中在 `gradle/libs.versions.toml`，SDK 与构建类型配置在 `app/build.gradle.kts`。
通过 Android Studio 配置 SDK，或在本机 `local.properties` 中设置 `sdk.dir`。
Gradle 运行时的 JDK 版本与应用字节码编译目标是两项不同配置。

## 目录结构

```text
Android/
├── app/
│   ├── build.gradle.kts                应用、SDK、依赖、构建类型
│   └── src/
│       ├── main/
│       │   ├── AndroidManifest.xml      应用声明
│       │   ├── java/top/rayawa/dashboard/complexsweeper/android/
│       │   │   ├── MainActivity.kt      Activity 入口与 ViewModel 创建
│       │   │   ├── model/              复数、难度、战绩与存档
│       │   │   ├── engine/Board.kt      单格、随机数与棋盘引擎
│       │   │   └── ui/                 控制器、棋盘、格子、教程与反馈
│       │   └── res/                    游戏贴图、图标、WAV、字符串与主题
│       ├── test/                       JVM 引擎回归
│       └── androidTest/                Compose 设备交互回归
├── gradle/                             版本目录、Wrapper、JVM 配置
├── assets/                             上游原始图集与槽位 JSON
├── tools/                              图集切图、图标生成、PNG 编解码
├── build.gradle.kts / settings.gradle.kts
├── gradlew / gradlew.bat                Gradle 入口
└── docs/ASSETS.md                       素材来源、清单与授权说明
```

## 移植架构与平台适配

`model` 与 `engine` 用 Kotlin 重写原作整数复数运算、mulberry32、布雷、连片展开与胜负判定。
圆复数存储 a²+b²，闵可夫斯基存储有符号整数 a²−b²；雷格由雷型字段单独判定，负显示值不会被误认为雷。
双曲模式按原作默认严格判据展开，只有周围无雷的空白格自动扩散；两种模式的完整规则见总 README。
Compose 将格子动作交给 `GameController`，首击统一经过 `Board.reveal`；界面不自行布雷。
棋盘数组与行列数使用同一快照，防止切难度时索引不一致。

`GameController` 是 ViewModel，由 Activity 的 `ViewModelProvider` 持有，旋转与窗口变化导致 Activity 重建时保留当前局。
这项保留仅覆盖 Activity 重建，进程被系统结束后不保证恢复正在进行的棋盘。
Compose 快照状态驱动格子和计雷器刷新，控制器销毁时释放音效。
页面仅在生命周期 STARTED 时轮询计时，实际时长通过 `SystemClock.elapsedRealtime()` 计算；结算刷新最终用时，重开 / 结束取消旧提示。

格子轻点与长按互斥，通过局部 `ViewConfiguration` 将长按阈值固定为 400ms。
棋盘滚动状态放在 `key(gameId)` 中，重开时复位。贴图缓存为 BitmapPainter，关闭插值，格子边长为 16–36dp。
模式 Tabs 提供选中语义，难度使用独立原生分段控件。模式切换保留难度，难度切换保留模式；两者都重开，重复选择当前项保留局面。
SharedPreferences 保存六个模式 / 难度槽位，圆复数沿用原有三个存档键。
测试通过格子、计雷器等语义标签定位控件。原作者署名用 Compose 可点击文本和 `LocalUriHandler` 打开上游 GitHub。

## 素材与图标生成

使用 Node 24+，从本目录执行：

```bash
node --experimental-strip-types tools/slice-atlas.ts \
  assets/atlas.json assets/atlas.png app/src/main/res/drawable-nodpi
node --experimental-strip-types tools/make-icon.ts \
  assets/atlas.json assets/atlas.png app/src/main/res
```

切图脚本导出全部 116 个上游槽位，含 j 雷 / 旗、双曲数字和 LED j 单位。
游戏贴图放在 `drawable-nodpi`，避免系统按资源密度再次缩放；音效位于 `res/raw`。
自适应启动图标在 `mipmap-anydpi` 声明，前景 / 背景为 `drawable` 中的 VectorDrawable。
前景从原作像素生成矩形路径，并合并同一行相邻同色像素；108dp 图层中主体宽 36dp，对应 72dp 可见窗口的一半。
旧式图标从 576px 母图按整数倍率导出 mdpi–xxxhdpi 五档尺寸（48 / 72 / 96 / 144 / 192px），圆形版本保留透明边角。
难度标签在同尺寸画布上生成 2× / 3× / 4× 图案。授权与素材细节见 [ASSETS.md](docs/ASSETS.md)。

## 构建与安装

用 Android Studio 打开本目录，或在本目录执行：

```bash
./gradlew :app:assembleDebug :app:assembleRelease :app:bundleRelease
```

| 产物 | 路径 | 用途 |
| --- | --- | --- |
| Debug APK | `app/build/outputs/apk/debug/app-debug.apk` | 使用开发签名，可安装测试 |
| Release APK | `app/build/outputs/apk/release/app-release-unsigned.apk` | 当前工程未配置发布签名，签名后才能安装 |
| Release AAB | `app/build/outputs/bundle/release/app-release.aab` | 发布用中间产物，当前未配置发布签名 |

连接设备后可执行 `adb install -r app/build/outputs/apk/debug/app-debug.apk`。

## 测试与验证

```bash
./gradlew :app:testDebugUnitTest :app:lintDebug :app:assembleDebugAndroidTest
# 需要连接 Android 12+ 设备或启动模拟器
./gradlew :app:connectedDebugAndroidTest
```

2026-10-12，1.1.0 验证：15 项 JVM 单测通过（0 失败、0 错误），lint 零错误，保留非错误提示；Debug 应用与设备测试 APK 构建通过。
引擎覆盖各 360 局两种模式、39 个双曲显示值、178,200 次展开判据检查及固定种子指纹。

`TouchInteractionTest.kt` 中 5 项设备交互测试覆盖首击旗子保护、长按与轻点互斥、计雷器更新、Activity 重建、棋盘拖动，以及模式 / 难度切换和重复选择。
当前没有连接 Android 设备，尚未执行这些设备测试；华为真机验收针对原生 HarmonyOS 工程。
完整同步记录见 [MODE_SYNC.md](../docs/MODE_SYNC.md)。

## 三端同步与维护

修改引擎规则时同步另外两端，并检查固定种子结果、首击保护、展开判据与胜负结算一致。
游戏图集和音效变更需要同步三个平台，图标通过本平台脚本重新生成。
共同功能与进度在[总 README](../README.md#移植范围与进度)维护；本目录保留平台实现和工程说明。
详细历史回归见 [PORTING_STATUS.md](docs/PORTING_STATUS.md)，源码许可证见 [LICENSE](LICENSE)。
