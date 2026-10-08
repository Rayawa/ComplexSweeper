# ComplexSweeper-HarmonyOS

> 复扫雷 · 扫雷，但雷是复数

扫雷，但雷是复数：棋盘上有四种雷，格子上的数字是它周围所有雷之和的模长。

翻开所有非雷格子就胜利。结局会用勾和叉显示标对、标错的雷，并播放对应音效。

**HarmonyOS 应用**：ArkTS + ArkUI，纯原生无第三方依赖，界面用 `@kit.UIDesignKit` 的
`HdsNavigation` + `HdsTabs`（悬浮沉浸底栏），棋盘与数字全部是上游的像素贴图。

> 本仓库只实现上游的**圆复数模式**；双曲复数模式（闵可夫斯基模式）未移植，见「未实现的部分」。

## 出处与致谢

本仓库（ComplexSweeper-HarmonyOS）是
[Yueqing-Chen/complexweeper-A-minesweeper-game](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game)
的 **HarmonyOS 移植版**：原作为青月晓开发的 Zig + Win32 桌面程序，本仓库把它的
游戏规则、随机数算法、图像素材与音效移植到 HarmonyOS（ArkTS / ArkUI），
界面按经典扫雷的观感重做。本仓库专注于 HarmonyOS 版，由 Rayawa 维护；
桌面原版与 Web 版请见上游及相关仓库。

感谢原作者**青月晓**设计并开源了这个独特的复数扫雷 —— 规则、24 个可达值、展开判据、
四种雷的贴图与六段音效都出自他手；也感谢上游仓库的贡献者们。

> 英文名的拼写说明：上游对外一直写 **Complexweeper**（仓库名和程序窗口标题都是），
> 只有内部的 Win32 窗口类名用了正确的 **ComplexSweeper**。本仓库采用了后者，
> 所以搜上游请用 `Complexweeper`，别用这个名字找不到。

移植基准为上游 **v1.2.0**（`APP_VERSION`）。原作代码按 GPL-3.0 授权，
本仓库的移植同样以 GPL-3.0 发布（见 [`LICENSE`](LICENSE)）。
素材的授权分三类，**转载或商用前请先读 [`docs/ASSETS.md`](docs/ASSETS.md)**。

## 规则

**圆复数模式**有四种雷：正实雷、负实雷、正虚雷和负虚雷，也就是 +1、−1、+i 和 −i（i² = −1）。

一个格子显示的数是周围所有雷之和的模长。比如周围有一颗 +1 和一颗 −i，和是 1−i，
模长是 √2，格子上就显示 √2。

因为周围最多 8 格，实部虚部各自是「正雷数减负雷数」、两者绝对值之和不超过 8，
所以只可能出现 24 种数字：

0, 1, 2, 3, 4, 5, 6, 7, 8,
√2, √5, √10, √13, √17, √26, √29, √34, √37,
2√2, 2√5, 3√2, 4√2, 5√2, 2√10。

正负雷数量相等时会互相抵消，这种 1 正 1 负的正负对我们称为「抵消对」；
**0 和空白不是一回事**。空白格子表示周围完全没有雷；0 表示周围完全为抵消对。

当数字格子周围插上的旗帜数量等于真实雷数，且实虚比例符合真实比例或其倒数，则允许展开；
可以利用这一点试探周围是否有抵消对。
谨记扫雷的胜利判定是翻开所有的格子，而不是插对全部的旗帜。

## 操作

| 操作 | 手势 |
| --- | --- |
| 翻开格子 | 长按 |
| 插旗（正实 → 负实 → 正虚 → 负虚 → 撤旗） | 点按未翻开的格子 |
| 展开格子 | 点按已翻开的数字格 |
| 重开 | 点人脸按钮 |

插了旗的格子翻不开 —— 旗子保护格子，要先把旗循环回「空」；连片展开也绕开旗子。

浮动底栏三个标签依次是初级、中级、高级；**教程常驻在标题栏右上角**，三个难度页都能点开，
以底部弹层（`bindSheet`）的形式出现。切标签只有真的换了难度才重开，来回切不会把手上的局作废。

## 难度

- 初级 9×9 · 10 雷
- 中级 16×16 · 40 雷
- 高级 30×16 · 99 雷

四种雷的数量是**随机**的（不预先均分），开局之后才在顶部四个计雷器上公布。
负实雷和负虚雷显示成负数，每插一颗就朝零走。这条信息很有用 ——
它能帮你排除掉大量不可能的实虚组合。

> **高级有 30 列，手机一屏放不下，棋盘可以左右拖动。**
> 这是照搬上游的取舍：好处是格子保持贴图原始尺寸（16vp），代价是要拖。

## 界面

用 `@kit.UIDesignKit` 的 `HdsNavigation`（标题栏）+ `HdsTabs`（底栏）：

- **底栏是悬浮沉浸的** —— `.barOverlap(true)` 让内容从底栏底下穿过去，配
  `.barFloatingStyle()` 的系统浮动材质和上缘渐隐遮罩。所以游戏页底部留了一段空档，
  别让状态行被压住。
- **安全区与沉浸**：靠 `HdsNavigation` 上的
  `.ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [TOP, BOTTOM])` 铺满整屏 ——
  这是关键的一句，少了自己怎么补都不对。标题栏和悬浮底栏会各自避让状态栏与手势条，
  页面内容则靠上下留白让位（`TITLE_BAR_INSET` / `FLOATING_BAR_ROOM`，
  取值参考 Dashboard 工程实测过的 100 / 110）。
  几条走不通的路记在这里：`setWindowBackgroundColor` 对手机 / 平板 / 2in1 不可用；
  给内容层直接加 `expandSafeArea` 会把内容一起顶上去，压到状态栏底下。
- **标题栏是透明底 + 系统浮动材质**（`backgroundStyle.backgroundColor: Color.Transparent`
  配 `systemMaterialEffect`），内容从底下透上来才是沉浸感。刷成不透明色会变成一条实心色带，
  反而把表头压住。
- **标签页图标**得用 `$r('app.media.*')`，标题栏菜单才用 `$r('sys.symbol.*')`。
  系统资源名编译器不校验，写错了不报错、只是不显示。这里用的是仓库自带贴图
  （`cw_tab_1..3`，由 `make-icon.ts` 从旗帜贴图放大到 96×96）。
- **棋盘网格用 `Column` 套 `Row` 逐格摆，不用 `Flex` 的自动换行。**
  Flex 换行是拿容器宽度除格子宽度算出来的，除不尽就会把最后一格挤到下一行、
  或者让子项收缩，整片格子就会错位。固定列数的 `Row` 没有这个自由度。
- 左右居中是自己按余量算的（`boardPadLeft()`）。定宽的棋盘放进满宽的滚动区里默认贴左，
  右边留一条，看着也像没对齐。

## ArkUI 状态管理上踩过的坑

三条都很难从编译期发现，症状还都表现为「UI 显示不对」，记在这里免得再踩：

1. **子组件未加装饰器的成员变量不会跟着父组件更新。** 只在构造时赋值一次，
   之后父组件重绘也同步不过来。计时器永远停在 0、首屏格子永远停在最小尺寸，
   都是这个原因。凡是会变的入参一律用 `@Prop`（`LedReadout.value`、`CellView.edge`）。
2. **`@State` 观察不到类实例的深层字段。** `@State board: Board` 只观察 `this.board`
   被整体替换，`board.cells[i].flag` 这种改动它看不见 —— 放了旗，格子会靠
   `@ObjectLink` 自己重绘，但页面不重绘，计雷器就不动。凡是这种「外部读得到的深状态」，
   都要另存一份 `@State`（`flagMarks`）并显式同步。
3. **`ForEach` 的 key 决定组件是复用还是重建。** key 不变时组件被复用，构造函数不会重跑，
   于是第 1 条的变量更不会更新。棋盘用 `${gameId}-${row}-${col}` 做 key，
   换一局就整片重建。

## 代码结构

```
entry/src/main/ets/
├── model/
│   ├── Complex.ets         四种雷、24 个可达值、模长化简成 k√m
│   ├── Difficulty.ets      三档难度
│   └── Stats.ets           战绩存档（preferences）
├── engine/
│   └── Board.ets           Cell（@Observed）+ 棋盘引擎 + mulberry32 随机数
├── view/
│   ├── CellView.ets        单格：挑贴图 + 手势
│   ├── ClassicLed.ets      数码管读取器
│   ├── Sprites.ets         贴图查表
│   ├── Feedback.ets        轻振反馈
│   ├── Sound.ets           音效池（SoundPool）
│   └── TutorialContent.ets 教程内容
└── pages/
    └── Index.ets           游戏页 + 标签页骨架
```

引擎对外只暴露「翻开 / 标记 / 展开 / 是否通关」，UI 不碰任何布雷细节。
棋盘存的是 `a²+b²`（整数）而不是模长，全程不碰浮点，可以直接当贴图下标查表。

## 开发脚本

```bash
# 引擎逻辑校验：24 个可达值 + 360 局随机对局的不变量 + 展开判定 + 结算复盘
./scripts/engine-check/run.sh

# 从图集切出贴图（已经切好，换素材时才需要重跑）
node --experimental-strip-types scripts/atlas/slice.ts \
  assets/atlas.json assets/atlas.png entry/src/main/resources/base/media cw_

# 生成应用图标 + 标签页图标（从切好的贴图槽位）
node --experimental-strip-types scripts/atlas/make-icon.ts \
  entry/src/main/resources/base/media/cw_icon.png AppScope/resources/base/media \
  cw_flag_1,cw_flag_2,cw_flag_3 entry/src/main/resources/base/media

# 界面预览：用真实贴图和真实引擎渲染成 HTML 并截图
./scripts/ui-preview/run.sh
```

两个校验脚本都直接用 `scripts/strip-engine.sh` 剥掉 `@Observed` 后跑**当前源码本体**，
不存在副本走样。界面预览的贴图直接用 `media/` 里那批切好的 PNG，排版尺寸逐条对应
`Index.ets`，所以不会跟真实界面走样 —— 但它**验不了 ArkUI 的运行时行为**
（手势、`@ObjectLink` 刷新、`HdsTabs`/`HdsNavigation` 的实际渲染），只能验排版和观感。

## 素材与授权

代码按 **GPL-3.0** 授权（见 [`LICENSE`](LICENSE)）。

图像与音效素材分三类，授权状态不同：

| 类别 | 权利 |
| --- | --- |
| 扫雷原始图像素材（格子、数字、旗帜、雷、人脸等） | **Microsoft**，源自原版扫雷（Robert Donner、Curt Johnson），**不在** GPL-3.0 授权范围内 |
| 新增素材（24 个显示值、四种旗帜、数码管、人脸按钮、图标） | 青月晓，随本仓库按 GPL-3.0 发布 |
| 六段音效（四种踩雷、通关、计时滴答） | 青月晓自制，随本仓库按 GPL-3.0 发布 |

逐槽位的清单、以及「要商用该改哪几个矩形」都写在 **[`docs/ASSETS.md`](docs/ASSETS.md)**。

## 商标

本程序是独立复刻作品，与 Microsoft 公司无隶属关系，也未获得其授权或背书。
"Minesweeper"、"扫雷"及相关商标归各自权利人所有。

## 未实现的部分

- **双曲复数模式（闵可夫斯基模式，j² = 1）**：上游支持两种模式，本移植版只实现了圆复数模式。
  上游图集里那 42 张双曲模式的贴图已被切图脚本按名字跳过，没有切进资源目录；
  要补这个模式，图集素材是现成的，规则见上游 README。
- **音效开关**：上游可关闭音效并记住偏好，本版音效常开。
- **自定义雷区**：上游支持宽 9–40、高 9–30 与四种雷的精确配比，本版只有三档预设。

## 构建与安装

用 DevEco Studio 打开工程即可构建。**注意 `build-profile.json5` 里的 `signingConfigs` 是空的**，
直接构建出来的包装不到真机上 —— 在 `File > Project Structure > Signing Configs`
勾选自动签名（需要登录华为开发者账号）之后才能安装。

音效用的 `SoundPool` / `AudioCore` 在部分设备类型上没有 syscap，编译会有两条提示；
`SoundBoard` 全程 try/catch，初始化失败就静音，不影响游戏。
