# 顶栏与移动设备验收 · 2026-10-18

应用版本：1.2.0。上游素材基准：`f6b80bb`。

## 鸿蒙

外观使用 `TabSegmentButtonV2`，通过 `HdsNavigation.titleBar.content.stackBuilder` 固定在系统顶栏中央，标题在左侧、关于按钮在右侧；难度选择单独保留棋盘上方整行。

PLA-AL10真机覆盖安装本机开发签名应用与测试包后，7项Hypium / UiTest全部通过，0失败、0错误，约51秒。
新增位置断言确认外观与关于按钮中心高度相差小于20物理像素，且高于难度选择；其他用例覆盖模式、难度、长按旗帜保护、计雷器、重复选择外观与局面保留、关于关闭及署名布局。

真机布局实测：外观 `[462,164][854,304]`，关于 `[1120,164][1260,304]`，难度 `[28,420][1288,560]`。
截图及原始布局保存于本地 `artifacts/v1.2.0/harmony-titlebar.png` / `harmony-titlebar-layout.json`，测试日志为 `harmony-device-test.log`。
签名构建完成后，仓库配置已恢复无签名状态。

## iPhone与iPad

新增第10项XCUITest，覆盖横竖屏时外观分段与难度选择无重叠、选项均可点击、重复选择保持格子状态，并保存横竖屏截图。
完整回归另覆盖长按翻开、旗帜循环与保护、计雷器、高级棋盘拖动、模式及难度、关于、外观选择与进程重启恢复偏好。

| 测试目标 | 执行方式 | 结果 |
| --- | --- | --- |
| iPhone18 Pro / iOS27.0 | 模拟器，完整XCUITest | 10项通过，0失败 |
| iPad Pro13英寸M5 / iPadOS27.0 | 模拟器，完整XCUITest | 10项通过，0失败 |
| iPhone17 / iOS27.2 | 无线真机，官方Device Hub交互验收 | 外观、局面保留、偏好恢复及横屏等检查通过；XCUITest未能初始化 |
| iPad Pro11英寸M4 / iPadOS27.2 | 无线真机，完整XCUITest | 10项通过，0失败 |

用户已完成两台真机的证书信任并保持解锁。iPad完整执行10项XCUITest；iPhone通过官方Device Hub进行真实触摸交互检查，两种执行方式分别记录。

模拟器首次双目标运行遇到测试运行器连接中断，尚未进入用例；重启后iPhone单目标尝试报告运行器在建立连接前退出。它们属于启动阶段失败，不能计作游戏用例通过或失败。随后将两个模拟器分开运行，并以独立缓存与临时签名重试iPhone；两台模拟器最终完整用例均通过。

本地证据：`iphone-ui-test-summary.json` / `ipad-ui-test-summary.json`，对应原始测试日志及横竖屏截图均保存在 `artifacts/v1.2.0/`。应用局部截图在横屏时存在方向裁切，因此补跑方向用例并改用整屏截图；iPhone与iPad补验各1项通过，已核对完整横竖屏画面，避免把截图采集问题当作应用布局问题。

## 本次改动与验证边界

应用界面改动仅涉及鸿蒙外观分段在顶栏中的位置；Apple增加测试与截图采集，未修改玩法规则。完整模拟器回归共20项通过，另有2项横竖屏截图补验通过。iPad真机10项通过；iPhone真机交互验收通过，自动化在启动阶段失败，未执行游戏用例。

鸿蒙最新开发签名与未签名HAP已更新到本地 `artifacts/v1.2.0/`，`SHA256SUMS.txt` 与 `manifest.json` 同步更新。

## Apple真机结果

iPad Pro 11英寸（M4）/ iPadOS27.2通过无线连接，单独顺序运行完整10项XCUITest，0失败，约222秒。证据为 `ipad-device-test-summary.json`、`ipad-device-test.log` 和 `ipad-device-portrait.png` / `ipad-device-landscape.png` / `ipad-device-appearance.png`。

iPhone17 / iOS27.2通过官方devicectl刷新既有配对，恢复局域网TCP隧道；全程无线，未解除配对。顺序运行及重新构建后，XCUITest仍在取得测试配置前被DTX对端拒绝通道，以74退出，未进入测试用例。此限制不计作游戏用例通过或失败。

真机原有应用曾显示“Is No Longer Available”；使用本机已有开发签名重新覆盖安装1.2.0主应用后正常启动，保留应用数据。随后通过官方Device Hub完成以下交互验收：

- 竖屏彩色与黑白分段均可点击；切换及重复选择后，已翻开的数字、左上角旗帜和计雷器保持，计时继续。
- 黑白选中后终止并重新启动应用，仍恢复黑白外观；随后恢复彩色。进程重启会开始新局，本项检查外观偏好。
- 长按首击正常翻开；双曲模式点击循环到+j旗帜；重复选择当前模式或难度保留该旗帜。
- 用户横置手机并允许旋转后，横屏分段显示完整，两组选择器无重叠，+j旗帜保留。
- 中级与高级难度切换正常，高级横屏棋盘可滚动，笑脸可重开。
- 关于页可打开、滚动并关闭，版本显示1.2.0；验收结束恢复初级、圆复数和彩色。

以上为真机交互验收，不等同于10项XCUITest全部通过。证据保存于本地 `artifacts/v1.2.0/iphone-device-manual-validation.json`，截图为 `iphone-device-color.png`、`iphone-device-blackwhite.png`、`iphone-device-landscape.png` 和 `iphone-device-version.png`。旧战绩在覆盖安装后仍显示最佳30秒。

## 后续规则调整

本记录上述结果对应外观与顶栏验收时的规则。随后用户要求允许长按带标记格直接翻开并清除标记，三端已同步调整；新规则的结果与测试包见 [长按清旗验收](FLAG_REVEAL_2026-10-18.md)。
