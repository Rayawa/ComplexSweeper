# 彩色与黑白外观同步 · 1.2.0

日期：2026-10-17。移植应用版本：1.2.0；Android versionCode 3、Apple build 3、HarmonyOS versionCode 1002000。

## 上游范围

原版基准从 `80502e5e8b222362cbe86d57588f2c0fbbb11a3f` 更新到
[`f6b80bb35690ad4498e2e0179353bc8b369a2d70`](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game/commit/f6b80bb35690ad4498e2e0179353bc8b369a2d70)。
[四个新增提交](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game/compare/80502e5...f6b80bb)：

| 日期（北京时间） | 提交 | 内容 |
| --- | --- | --- |
| 10-14 | `b8b07b8` | 首次加入黑白图集 |
| 10-14 | `7069089` | 更新黑白素材 |
| 10-15 | `037c61e` | 颜色开关、偏好保存、黑白图集生成与 UI 回归，源码版本升至 1.3.0 |
| 10-15 | `f6b80bb` | 彩色图集微调 |

此次上游 `game.zig` 只改注释，规则与随机数算法不变。原版源码版本为1.3.0；查询时最新正式 Release 仍为1.2.0。

## 实现

- 三端保存上游原始 `atlas.png` 与专用 `atlas-bw.png`，共用原有116槽位 JSON。黑白图集使用作者绘制的符号及纹理。
- PNG 解码支持上游黑白图集的8位灰度加 alpha 格式；切图按上游 Rec.601 灰度公式计算，非图标的透明像素合成到192银灰底，图标保留透明度。
- 两套资源名称分别为 `cw_<槽位名>` 与 `cw_bw_<槽位名>`，每端共232张图集切图；应用启动图标从最新彩色 icon 槽位重新生成。
- 外观使用原生「彩色｜黑白」分段按钮，始终同时显示两个选项；重复选择当前项保留当前局面。默认彩色；游戏内全部贴图及教程示意图随之更新，保持最近邻缩放。
- Android 通过 CompositionLocal 在 PixelImage 中选择静态资源映射，使用独立 SharedPreferences `complexsweeper_settings` / `colorEnabled` 保存。
- Apple 的 PixelImage 与标题栏共用 `@AppStorage("colorEnabled")`，使用 UserDefaults 保存。
- HarmonyOS 的贴图组件通过 `@StorageLink('colorEnabled')` 同步，独立 preferences `complexsweeper_settings` 保存。初次读取完成后才启用切换，避免启动异步读取覆盖用户的新选择。
- 外观切换只更新显示与偏好，不调用重开；原有圆复数与双曲模式的战绩键和计时逻辑保持兼容。

## 复现与校验

在仓库根目录使用 Node24+：

```bash
node scripts/sync-appearance-assets.ts
node scripts/check-appearance-assets.ts
```

第一条命令重建三端切图、Android / HarmonyOS 静态映射与启动图标。第二条命令检查原图与槽位表、232个资源的逐文件 SHA-256、尺寸、非空和黑白灰度；已加入 GitHub Actions。

原始图集 SHA-256：

```text
atlas.png     192628c498e5fe3f665bad08789496fa90fae55dede67e92b18588ab7a0fa5c9
atlas-bw.png  447684ae77c32c13cf1650a953b73418384366024f86eefea6f0bb114450d24e
```

## 本次验证

| 检查 | 结果 |
| --- | --- |
| 三端素材 | 原图、槽位表一致；两套共232张切图的 SHA-256、尺寸、非空及灰度检查通过 |
| HarmonyOS 引擎 | 各360局圆复数与双曲回归，39显示值、178200次展开判据和固定种子回归通过 |
| Apple 引擎 | 同上；旧存档兼容与分模式战绩隔离通过 |
| Android | 15项 JVM 单测通过；lint 零错误；Debug 应用和新增设备测试 APK 编译通过；Release APK / AAB 构建通过 |
| HarmonyOS | Release 主 HAP 与 ohosTest HAP 构建通过；PLA-AL10真机覆盖安装1.2.0，6项 Hypium / UiTest 全部通过，0失败、0错误 |
| Apple | macOS Debug / Release（arm64 / x86_64）与 iOS 模拟器 Debug / Release 应用、测试运行器编译通过 |
| Apple交互 | 2026-10-18，iPhone / iPad模拟器各10项完整回归通过，横竖屏截图各1项补验通过；iPad真机无线XCUITest 10项通过；iPhone真机交互验收通过，无线XCUITest因DTX通道初始化失败未执行用例 |

新增 Android 设备用例覆盖两种模式×三档难度，检查切换后同一 Board、格子状态、旗帜、计时和偏好写入；HarmonyOS 新增保留旗帜、首击展开及计雷器的用例。Android当前未连接设备，设备交互测试未执行；鸿蒙已在PLA-AL10真机执行上述6项原生回归。

iOS 新增用例比较切换前后的全部格子状态，检查保留旗帜与进行中状态，并终止重启应用验证外观持久化，另检查双曲 j 旗帜。初版完整回归9项通过；最终分段布局4项相关回归通过，含切换及重复选择保留局面、重启恢复偏好。测试截图保存在本地 `artifacts/v1.2.0/iphone-blackwhite.png`。

本次鸿蒙最终顶栏布局来自2026-10-18的1.2.0开发签名构建，7项真机回归通过；下文保留早期6项回归记录。Apple两台真机的本轮验收及自动化边界见 [2026-10-18验收记录](VALIDATION_2026-10-18.md)。历史2026-10-12结果只适用于1.1.0。鸿蒙保留音频、2in1及原有分段按钮的非错误警告；iOS测试运行器提示原有 AVAudioSession 同步激活可能阻塞主线程，未造成已执行测试失败。

本地发布准备附件位于 `artifacts/v1.2.0/`，包含 Android 未签名 APK / AAB、macOS 通用应用 ZIP、鸿蒙未签名 HAP、iOS模拟器应用ZIP及 `SHA256SUMS.txt` / `manifest.json`。已核对包内应用版本与构建号。

外观验收时已更新应用版本并准备发布说明；正式v1.2.0附件与发布信息见[发布说明](releases/v1.2.0.md)。自定义棋盘、指定雷型配比、声音开关及独立纪录窗口仍属后续移植范围。

## 鸿蒙真机补充（2026-10-17）

- 手机型号PLA-AL10，以已有开发签名覆盖安装1.2.0主HAP和测试HAP，保留应用数据。
- 真机发现HDS标题栏默认按图标按钮绘制，缺少图标的颜色入口显示为空白；已设置 `TextStyleMode.NORMAL`，明确采用文字胶囊按钮，并添加 `appearance` / `about` 稳定组件标识。
- 模式切换重建棋盘时，UiTest查询到的旧组件可能在读取坐标前失效。测试帮助函数现只在注入触摸前重试 `NoCandidates` 定位错误，避免重复执行用户操作。
- 修复后的完整原生回归6项通过（0失败、0错误），运行约50秒：模式与难度、旗帜保护与循环、计雷器与重开、连续切难度、外观切换保留局面、关于关闭与署名布局。
- 仓库 `build-profile.json5` 已恢复无签名配置；签名材料继续保存在原有本机配置中。

日志：本地 `artifacts/v1.2.0/harmony-device-test.log`。开发签名HAP仅适用于签名描述文件授权的设备，不作为通用分发签名。

## 外观改为分段选择器（2026-10-17）

按用户要求，三端最终均使用「彩色｜黑白」原生分段按钮，两个选项始终可见且高亮当前项。
HarmonyOS使用 `TabSegmentButtonV2`，初版与难度选择并排放在棋盘上方，2026-10-18已移到系统顶栏；Android使用 `SingleChoiceSegmentedButtonRow` / `SegmentedButton`，位于标题栏；Apple使用 `.segmented` Picker，全平台在棋盘上方与难度选择并排。

明确选择指定外观；重复选择当前项不重开、不翻转、不重复写偏好。Android / iOS / HarmonyOS交互回归同步覆盖重复选择。外观偏好键及旧战绩保持兼容。

最终分段按钮的真机回归运行约50秒，6项全部通过；iOS将分段Picker移到普通内容区，避免系统工具栏隐藏该控件，4项相关回归通过。

鸿蒙分段版本的6项真机回归已通过。随后无线调试连接中断，额外进程重启复验未完成；此前切换按钮版本已完成停止进程与重启后的偏好恢复、恢复原外观检查，记录保存在本地 `artifacts/v1.2.0/harmony-before-segments-persistence.json`，旧截图为 `harmony-before-segments.png`。最终分段布局截图使用 `iphone-blackwhite.png`，来自最终4项iOS回归。

## 鸿蒙顶栏与Apple双设备验收（2026-10-18）

鸿蒙外观分段控件已通过 `HdsNavigation` 的 `stackBuilder` 放回系统顶栏中央，保留系统标题与关于按钮，难度选择恢复棋盘上方整行。顶栏自定义容器使用透明命中策略，让两侧的系统按钮保持可点击。
新增原生位置回归，检查外观与关于按钮中心在同一水平线上，且位于难度选择上方。其他外观、旗帜、模式和难度回归保持。

Apple新增横竖屏布局用例，分别检查两个外观选项及难度按钮可点击、两组选择器无重叠、重复选择不改变格子状态，并保存横竖屏截图。本轮分别面向iPhone 18 Pro与iPad Pro 13英寸（M5）模拟器；结果见 [2026-10-18验收记录](VALIDATION_2026-10-18.md)。

## 正式发布

v1.2.0统一提交三端实现、素材和验收文档；发布附件从包含长按清旗规则的最终代码重新以Release配置构建。公开附件与签名范围见[发布说明](releases/v1.2.0.md)。本文件提到的 `artifacts/v1.2.0/` 仍保留早期外观验收快照；本次正式发布包位于本地 `artifacts/v1.2.0-release-20261018/`。
