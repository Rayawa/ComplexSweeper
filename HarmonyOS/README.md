# HarmonyOS 移植与工程说明

**当前版本 1.2.0（versionCode 1002000）**。底部 HDS Tabs 切换圆复数 / 闵可夫斯基模式，棋盘上方使用 ArkUI 原生 `TabSegmentButtonV2` 选择难度。
1.2.0 下载与签名说明见 [v1.2.0 Release](https://github.com/Rayawa/ComplexSweeper/releases/tag/v1.2.0)。

本目录是复扫雷的 ArkTS / ArkUI 原生工程，也是三端共同移动功能的移植基准。
应用介绍、玩法、原作致谢与共同范围见[仓库总 README](../README.md)。以下命令均在 `HarmonyOS/` 中执行。

## 工程配置

| 项目 | 配置 |
| --- | --- |
| SDK | targetSdk 26.0.0，compatibleSdk 6.1.0（API 23） |
| 语言 / 界面 | ArkTS / ArkUI，系统 HDS 组件 |
| 导航 | `HdsNavigation` / `HdsTabs` |
| 模块 / product / target | `entry` / `default` / `default` |
| 构建 | DevEco Studio / Hvigor / ohpm |
| 状态管理 | 页面 `@State`、Cell `@Observed` / `@ObjectLink` |
| 音效 / 触感 / 存档 | SoundPool / VIBRATE / preferences |
| 测试依赖 | Hypium 1.0.25、Hamock 1.0.0 |

游戏运行时使用系统能力；测试依赖在 `oh-package.json5` 中单独声明。
SDK、模块和签名配置位于 `build-profile.json5`，本地 SDK 路径由开发者环境配置。

## 目录结构

```text
HarmonyOS/
├── AppScope/                         应用级配置、名称与分层图标
├── entry/
│   ├── build-profile.json5           模块构建配置
│   └── src/
│       ├── main/
│       │   ├── module.json5          模块、Ability、权限与设备类型
│       │   ├── ets/
│       │   │   ├── entryability/     Ability 与窗口生命周期
│       │   │   ├── entrybackupability/  备份扩展
│       │   │   ├── model/            复数、难度、战绩与存档
│       │   │   ├── engine/Board.ets   Cell、mulberry32 与棋盘引擎
│       │   │   ├── view/             格子、数码管、教程、声音与触感
│       │   │   └── pages/Index.ets   游戏控制、导航、布局与难度标签
│       │   └── resources/            贴图、音效、主题与页面配置
│       ├── test/                     本地测试入口
│       └── ohosTest/                 设备侧测试入口
├── assets/                           上游原始图集与槽位 JSON
├── scripts/
│   ├── atlas/                        图集切图、分层图标、PNG 编解码
│   ├── engine-check/                 当前引擎源码的 Node 回归
│   ├── strip-engine.sh               提取可在 Node 执行的引擎逻辑
│   └── ui-preview/                   HTML 布局预览与截图
├── hvigor/ / hvigorfile.ts            构建工具配置与入口
├── build-profile.json5 / oh-package.json5
└── docs/ASSETS.md                     素材来源、清单与授权说明
```

## 移植架构与平台适配

引擎使用整数实虚分量和 mulberry32，保持原作的固定种子行为。圆复数存储 a²+b²，闵可夫斯基存储有符号整数 a²−b²，雷格通过独立雷型字段判定。
双曲负显示值按 √|D|i 显示，展开采用原作默认严格判据；只有周围完全无雷的空白格自动扩散。
`Board` 管理布雷、翻开、标记、展开和通关判定；`Index.ets` 管理页面状态、计时、战绩、声音与提示。
首次翻开统一调用 `Board.reveal`，带旗首击不布雷，重复开局和越界输入由引擎防护。

Cell 使用 `@Observed`，格子通过 `@ObjectLink` 观察变化；开局与插旗后同步四个计雷器。
计时以 `systemDateTime.getUptime(STARTUP)` 计算真实用时，定时器仅触发刷新；结算前补齐最终用时，重开 / 结束清除旧提示任务。
界面由 HDS 导航与标签页组织，棋盘随可用空间调整为 16–36vp，图片采用最近邻缩放。
难度选择参照 Dashboard 的系统分段按钮写法，使用 `TabSegmentButtonV2` / `SegmentButtonV2Items`，包括双向选择状态、点击回调与动画；控制器对重复选择进行保护。
模式切换保留难度，难度切换保留模式；两者都重开，重复选择当前项保留局面。preferences 按两个模式 × 三档难度保存战绩，圆复数原有存档键保持不变。

「关于」右上角关闭按钮的叉号居中，底部原作 `Hyperlink` 在全宽行中居中，并可打开上游 GitHub。

音频与 2in1 状态栏配色在部分设备上缺少系统能力，现有实现会降级为静音或系统默认配色。
这些构建提示与具体设备能力有关，需要结合目标设备验证。

## 彩色与黑白外观（1.2.0）

顶部提供「彩色｜黑白」原生分段选择器，默认彩色，立即更新全部游戏贴图；切换保留局面与计时，重启恢复偏好。
两套资源分别使用 `cw_` / `cw_bw_` 前缀，均来自上游 `f6b80bb` 的专用图集；黑白图案包含上游绘制的符号与纹理。
从仓库根目录执行 `node scripts/sync-appearance-assets.ts` 可重建三端两套素材、静态映射和启动图标。
2026-10-17，PLA-AL10真机覆盖安装1.2.0，6项原生回归通过（0失败、0错误），含外观切换保留局面。外观使用 `TabSegmentButtonV2`，通过 `HdsNavigation.titleBar.content.stackBuilder` 固定在顶栏中央；难度选择单独保留在棋盘上方。
2026-10-18，顶栏版本在PLA-AL10真机7项回归通过（0失败、0错误），含外观与关于按钮同处顶栏的位置检查。
本次验证与设备测试边界见 [APPEARANCE_SYNC.md](../docs/APPEARANCE_SYNC.md)。

## 素材、图标与界面预览

使用 Node 24+，从本目录执行：

```bash
node --experimental-strip-types scripts/atlas/slice.ts \
  assets/atlas.json assets/atlas.png entry/src/main/resources/base/media cw_
node --experimental-strip-types scripts/atlas/make-icon.ts \
  entry/src/main/resources/base/media/cw_icon.png \
  AppScope/resources/base/media entry/src/main/resources/base/media

# 生成布局 HTML；本机安装了脚本指定路径的 Chrome 时同时截图
./scripts/ui-preview/run.sh
```

切图脚本导出全部 116 个上游槽位，含 j 雷 / 旗、双曲数字和 LED j 单位。
游戏贴图位于模块 `base/media`，WAV 位于 `rawfile/sounds`。
应用与 Ability 分层图标分别写入 `AppScope` 和模块 media，两处均为 1024px 前景 / 背景，512px 原作图案居中、银灰底。
启动窗口图标为 512px 透明 PNG；难度标签使用统一 128px 画布和 2× / 3× / 4× 图案。

预览脚本输出 `build/ui-preview/`，用于检查布局和观感，不验证 ArkUI 运行时手势或设备能力。
授权与素材细节见 [ASSETS.md](docs/ASSETS.md)。

## 构建与安装

用 DevEco Studio 打开工程，在 `File > Project Structure > Signing Configs` 配置本机签名，然后构建 / Run 到设备。
命令行使用 DevEco 随附的 Node 与 Hvigor；`DEVECO_HOME` 指向本机 DevEco Studio 应用目录：

```bash
"$DEVECO_HOME/Contents/tools/node/bin/node" \
  "$DEVECO_HOME/Contents/tools/hvigor/bin/hvigorw.js" \
  --mode module -p product=default -p module=entry@default \
  -p buildMode=release assembleHap --no-daemon
```

产物位于 `entry/build/default/outputs/default/`：

| 产物 | 用途 |
| --- | --- |
| `entry-default-signed.hap` | 使用本机工程配置的开发签名，安装范围受签名描述文件限制 |
| `entry-default-unsigned.hap` | 未签名 HAP，供后续签名使用 |

连接已授权设备后可执行 `hdc install entry/build/default/outputs/default/entry-default-signed.hap`。
仓库中的 `build-profile.json5` 不包含本机签名材料，默认可构建未签名 HAP。开发者在 DevEco Studio 配置自己的签名后，才能生成签名 HAP。原有本机配置保存在被 Git 忽略的 `build-profile.local.json5` 中，仅供本地参考；它不会自动覆盖工程配置。

## 测试与验证

```bash
# Node 24+，直接校验当前 ArkTS 引擎源码
./scripts/engine-check/run.sh
```

2026-10-12，1.1.0 验证：引擎通过各 360 局两种模式、39 个双曲显示值、178,200 次展开判据检查及固定种子回归；Release HAP 编译通过。

华为 Mate 70 Pro+（PLA-AL10）安装本机开发签名主 HAP 与测试 HAP 后，5 项 Hypium / UiTest 全部通过（0 失败、0 错误）：模式 / 难度切换、长按旗子保护与循环、计雷器与重开、连续切难度、关于关闭按钮和署名居中。
测试源码为 `entry/src/ohosTest/ets/test/Ability.test.ets`，使用组件标识、无障碍描述和空闲等待。

```bash
# 构建设备测试 HAP；需先配置本机签名
"$DEVECO_HOME/Contents/tools/node/bin/node" \
  "$DEVECO_HOME/Contents/tools/hvigor/bin/hvigorw.js" \
  --mode module -p product=default -p module=entry@ohosTest \
  -p buildMode=release assembleHap --no-daemon

hdc install entry/build/default/outputs/default/entry-default-signed.hap
hdc install entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
hdc shell aa test -b top.rayawa.complexsweeper -m entry_test \
  -s unittest OpenHarmonyTestRunner -s timeout 180000 -w 240
```

以输出中的 `OHOS_REPORT_RESULT` 判断测试结果，不能只看 shell 返回码。
构建保留原有音频 / 2in1 系统能力警告。真机测试后已恢复不含本机签名的可移植工程配置。
完整同步记录见 [MODE_SYNC.md](../docs/MODE_SYNC.md)。

## 三端同步与维护

修改引擎规则时同步另外两端，并检查固定种子结果、首击保护、展开判据与胜负结算一致。
游戏图集和音效变更需要同步三个平台，图标通过本平台脚本重新生成。
共同功能与进度在[总 README](../README.md#移植范围与进度)维护；本目录保留平台实现和工程说明。
详细历史回归见 [PORTING_STATUS.md](docs/PORTING_STATUS.md)，源码许可证见 [LICENSE](LICENSE)。

2026-10-18追加：长按带标记格会清除标记并翻开，计雷器同步更新；其他格的标记仍受连片展开保护。验证与设备边界见 [长按清旗验收](../docs/FLAG_REVEAL_2026-10-18.md)。
