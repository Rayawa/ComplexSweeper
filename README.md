# ComplexSweeper

> 复扫雷 · 扫雷，但雷是复数

扫雷，但雷是复数：棋盘上有四种雷，格子上的数字是它周围所有雷之和的模长。
翻开所有非雷格子就胜利。结局会用勾和叉显示标对、标错的雷，并播放对应音效。

**HarmonyOS 应用**：ArkTS + ArkUI，纯原生无第三方依赖。

> 本仓库只实现上游的**圆复数模式**；双曲复数模式（闵可夫斯基模式）未移植。

## 出处与致谢

本仓库（ComplexSweeper-HarmonyOS）是
[Yueqing-Chen/complexweeper-A-minesweeper-game](https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game)
的 **HarmonyOS 移植版**：原作为青月晓开发的 Zig + Win32 桌面程序，本仓库把它的
游戏规则、随机数算法、图像素材与音效移植到 HarmonyOS（ArkTS / ArkUI），
界面按经典扫雷的观感重做，由 Rayawa 维护。

感谢原作者**青月晓**设计并开源了这个独特的复数扫雷 —— 规则、24 个可达值、展开判据、
四种雷的贴图与六段音效都出自他手；也感谢上游仓库的贡献者们。

移植基准为上游 **v1.2.0**。原作代码按 **GPL-3.0** 授权，本仓库的移植同样以
[GPL-3.0](LICENSE) 发布；素材授权分三类，转载或商用前请先读 [`docs/ASSETS.md`](docs/ASSETS.md)。

> 英文名拼写说明：上游对外一直写 **Complexweeper**（仓库名和程序窗口标题都是），
> 只有内部的 Win32 窗口类名用了正确的 **ComplexSweeper**。本仓库采用了后者，
> 所以搜上游请用 `Complexweeper`，别用这个名字找不到。

## 规则

**圆复数模式**有四种雷：正实雷、负实雷、正虚雷和负虚雷，也就是 +1、−1、+i 和 −i（i² = −1）。

一个格子显示的数是周围所有雷之和的模长。比如周围有一颗 +1 和一颗 −i，和是 1−i，
模长是 √2，格子上就显示 √2。因为周围最多 8 格，只可能出现 24 种数字。

正负雷数量相等时会互相抵消，这种 1 正 1 负的正负对我们称为「抵消对」；
**0 和空白不是一回事**：空白格子表示周围完全没有雷；0 表示周围完全为抵消对。

| 操作 | 手势 |
| --- | --- |
| 翻开格子 | 长按 |
| 插旗（正实 → 负实 → 正虚 → 负虚 → 撤旗） | 点按未翻开的格子 |
| 展开格子 | 点按已翻开的数字格 |
| 重开 | 点人脸按钮 |

插了旗的格子翻不开 —— 旗子保护格子，要先把旗循环回「空」；连片展开也绕开旗子。

难度三档：初级 9×9 · 10 雷，中级 16×16 · 40 雷，高级 30×16 · 99 雷。
四种雷的数量是**随机**的（不预先均分），开局之后才在顶部四个计雷器上公布。
**高级有 30 列，手机一屏放不下，棋盘可以左右拖动。**

教程常驻在标题栏右上角，三个难度页都能点开，以底部弹层的形式出现。
切换难度标签只有真的换了难度才重开，来回切不会把手上的局作废。

## 技术栈

| | |
| --- | --- |
| 语言 / 框架 | ArkTS + ArkUI（HarmonyOS），纯原生、无第三方依赖 |
| 界面 | `@kit.UIDesignKit` 的 `HdsNavigation`（沉浸标题栏）+ `HdsTabs`（悬浮沉浸底栏） |
| 渲染 | 棋盘与数字全部是上游的像素贴图，按原始尺寸 16vp 显示 |
| 音效 / 触感 | `SoundPool` 音效池、`ohos.permission.VIBRATE` 轻振 |
| 引擎 | 全整数运算（棋盘存 a²+b²，不碰浮点），mulberry32 随机数 |

## 项目结构

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

仓库其余部分：`AppScope/` 应用级配置与图标，`assets/` 上游图集（`atlas.png` + 槽位表），
`scripts/` 开发脚本（图集切图与图标生成、引擎校验、界面预览，用法见各自脚本头部注释），
`docs/ASSETS.md` 逐槽位的素材清单与授权说明。

## 构建与安装

用 **DevEco Studio** 打开工程，在 `File > Project Structure > Signing Configs`
勾选自动签名（需要登录华为开发者账号），之后即可构建安装到真机。

音效用的 `SoundPool` / `AudioCore` 在部分设备类型上没有 syscap，编译会有两条提示；
`SoundBoard` 全程 try/catch，初始化失败就静音，不影响游戏。

## 素材与授权

代码按 [GPL-3.0](LICENSE) 发布。扫雷原始图像素材（格子、数字、旗帜、雷、人脸等）
版权属于 **Microsoft**，源自原版扫雷（Robert Donner、Curt Johnson），**不在** GPL-3.0
授权范围内，仅作个人学习与兼容性展示之用；其余新增素材与音效由青月晓随本仓库按
GPL-3.0 发布。逐槽位清单见 [`docs/ASSETS.md`](docs/ASSETS.md)。

本程序是独立复刻作品，与 Microsoft 公司无隶属关系，也未获得其授权或背书。
"Minesweeper"、"扫雷"及相关商标归各自权利人所有。
