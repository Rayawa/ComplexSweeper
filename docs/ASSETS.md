# 素材说明 / Asset Notice

本仓库的图像与音效素材分三类，授权状态不同。转载、再发布或商用之前请读一遍这张表。

*The image and sound assets in this repository fall into three categories with different licensing.
Read this before redistributing, republishing, or using them commercially.*

素材来自上游 **复扫雷 v1.2.0**（[Yueqing-Chen/complexweeper-A-minesweeper-game](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game)）：

- 图集放在 `assets/atlas.png`（208×207 整图）+ `assets/atlas.json`（槽位表），
  从上游 `素材/图集.png` / `素材/图集.json` 原样拷贝而来。
  由 `scripts/atlas/slice.ts` 切成单张 PNG，输出到 `entry/src/main/resources/base/media/`，
  文件名统一加 `cw_` 前缀（HarmonyOS 的 media 资源名只接受小写字母、数字、下划线）。
  切图脚本是确定性的：拿仓库里的图集重跑一遍，切出来的 75 张与已提交的逐字节一致。
- 音效从上游 `正式版/src/sounds.bin` 提取，用的是上游自带的
  `node 正式版/tools/gen_sounds.js --extract <目录>`，输出到
  `entry/src/main/resources/rawfile/sounds/`。

下面用槽位名指认具体是哪几张。

*The assets come from upstream **Complexweeper v1.2.0**. The atlas is sliced into
individual PNGs by `scripts/atlas/slice.ts` into `entry/src/main/resources/base/media/`
(prefixed `cw_`, since HarmonyOS media resource names only allow lowercase letters,
digits and underscores). The sounds are extracted from upstream's `sounds.bin` with
upstream's own tool into `entry/src/main/resources/rawfile/sounds/`.*

---

## 一、扫雷原始图像素材 —— 权利属于 Microsoft

*Original Minesweeper graphics — © Microsoft*

| 槽位 Slot | 内容 Content |
| --- | --- |
| `closed` / `blank` | 经典立体按钮：未翻开格、已翻开的空白格 / classic raised button: covered cell and revealed blank cell |
| `flag_1`…`flag_4` | 四种旗帜（正实 / 负实 / 正虚 / 负虚），由原版旗帜按类型做色相调整 / four flag variants, hue-shifted from the original flag |
| `mine_1`…`mine_4` | 四种雷，同上 / four mine variants, same treatment |
| `boom_1`…`boom_4` | 踩中的四种雷（同色雷 + 红底）/ the four detonated mines (mine on red background) |
| `wrong_1`…`wrong_4` | 标错的雷（按真实雷型出图 + 红叉）/ incorrectly flagged mines, shown by their true type with a red cross |
| `right_1`…`right_4` | 标对的雷（按真实雷型出图 + 绿勾）/ correctly flagged mines, true type with a green check |
| `wrongflag_1`…`wrongflag_4` / `rightflag_1`…`rightflag_4` | 终局复盘的旗（旗 + 红叉 / 绿勾）/ end-of-game flag sprites (flag with cross / check) |
| `wrongblank` | 给一个根本不是雷的格子插了旗 / a flag placed on a cell that is not a mine |
| `face_normal` / `face_down` / `face_scan` / `face_dead` / `face_win` | 五张脸（风格取自原版笑脸，重绘）/ five faces (redrawn in the style of the original smiley) |

这些图形的版权归 Microsoft 所有，源自 Microsoft 扫雷（作者 Robert Donner、Curt Johnson），
**不适用本仓库的 GPL-3.0 授权**。把它们留在这里，是为了让这个复刻版在视觉上与经典扫雷一致，
只在"个人学习 / 兼容性展示"的意义上使用。

*These graphics are © Microsoft, from Microsoft Minesweeper (by Robert Donner and Curt Johnson),
and are **not** covered by this repository's GPL-3.0 license. They are kept here so the remake
visually matches the classic game, for personal study / compatibility demonstration only.*

`right_*` / `rightflag_*` / `wrongflag_*` / `wrongblank` 是上游新增或改绘的终局反馈图。
上游素材说明尚未逐槽更新；其中沿用经典格子、雷、旗的底层图形，继续保留上面的 Microsoft 权利声明。

**要商用或正式再发布**：请自行确认这部分素材的可用性，或者把它们换成你自己的图 ——
改 `assets/atlas.png` 里对应的那几个矩形（坐标见 `assets/atlas.json`），重跑一遍切图脚本即可：

```bash
node --experimental-strip-types scripts/atlas/slice.ts \
  assets/atlas.json assets/atlas.png entry/src/main/resources/base/media cw_
```

***For commercial or formal redistribution**: verify the usability of these assets yourself,
or replace them with your own art — edit the corresponding rectangles in the upstream atlas
and re-run the slicing script.*

---

## 二、原创与新增素材 —— 青月晓，随本仓库按 GPL-3.0 发布

*Original additions — by 青月晓, GPL-3.0*

| 槽位 Slot | 内容 Content |
| --- | --- |
| `num_0` … `num_64` | 24 个显示值的数字贴图，含 k√r 带系数的根式 / number sprites for the 24 display values, including the k√r radical forms |
| `led_0`…`led_9` / `led_minus` / `led_blank` / `led_i` | 计雷器与计时器的 LED 数字、负号、空格子与 i 单位 / LED digits, minus sign, blank slot, and the i unit |
| `icon` | 程序图标，32×32，带 alpha / app icon, 32×32 with alpha |

应用图标由 `scripts/atlas/make-icon.ts` 从 `icon` 槽位放大生成分层图标的两个图层
（1024×1024，前景图案 512×512 居中 + 同尺寸的纯色背景层），AppScope 与 entry 的
media 目录各写一份：前者是应用图标，后者是 ability 图标，桌面 Launcher 显示的是后者。
启动窗口图标 `startIcon.png`（512×512，透明底）也放大自同一个槽位。

标签页图标 `cw_tab_1.png`…`cw_tab_3.png` 也出自 `icon` 槽位：三档难度是同一个图案的
2×/3×/4× 三档大小，画在同样 128×128 的透明画布上 —— 画布必须一样大，系统把每张图
各自缩放到同一个显示尺寸后，才保得住「初级小、高级大」的递进。

*The app icon is generated from the `icon` slot by `scripts/atlas/make-icon.ts`:
layered icon layers (1024×1024) into both `AppScope/` (app icon) and the module's media
directory (ability icon — what the launcher shows), plus a transparent-background
`startIcon.png` (512×512) for the startup window. The tab icons `cw_tab_1..3` come from
the same slot — one motif at 2×/3×/4× on identically-sized 128×128 canvases, so the
difficulty progression survives the system scaling every icon to one display size.*

---

## 三、音效 —— 青月晓自制，随本仓库按 GPL-3.0 发布

*Sound effects — by 青月晓, GPL-3.0*

六段音效由青月晓通过 DSP 脚本合成，从上游 `sounds.bin` 原样提取：

| 文件 File | 内容 Content |
| --- | --- |
| `mine_1.wav` … `mine_4.wav` | 四类踩雷音，按踩中的那一颗的雷型播 / four detonation sounds, one per mine type |
| `win.wav` | 通关 / victory |
| `tick.wav` | 计时每秒一下 / one tick per second while playing |

格式为 22050 Hz、8 bit、单声道 WAV。

*Six DSP-synthesized sound effects, extracted unchanged from upstream's `sounds.bin`.
22050 Hz, 8-bit, mono WAV.*

---

## 未使用的上游素材

上游图集里 42 张双曲复数模式（闵可夫斯基模式，`j²=1`）的贴图 ——
`hnum_*`、`hflag_*`、`hmine_*`、`hboom_*`、`hwrong_*`、`hright_*`、`hwrongflag_*`、
`hrightflag_*`、`led_j` —— 本移植版没有实现该模式，切图脚本按名字前缀跳过，没有切进资源目录。
上游的**圆复数模式**（本版实现的模式）与它们无关。

---

## 商标 / Trademarks

本程序是独立复刻作品，与 Microsoft 公司无隶属关系，也未获得其授权或背书。
"Minesweeper"、"扫雷"及相关商标归各自权利人所有。

*This is an independent re-implementation, not affiliated with, endorsed, or sponsored by Microsoft.
"Minesweeper" and related trademarks belong to their respective owners.*
