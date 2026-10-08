import { BlurStrategy, HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController, ScrollEffectType } from '@kit.UIDesignKit';
import { display, LengthMetrics } from '@kit.ArkUI';
import { ACT_BOOM, ACT_JUDGE_FAIL, ACT_OK, Board, Cell } from '../engine/Board';
import { DIFFICULTIES, Difficulty } from '../model/Difficulty';
import { DifficultyStats, StatsStore } from '../model/Stats';
import { CellView } from '../view/CellView';
import { LedReadout } from '../view/ClassicLed';
import { faceSprite, flagSprite } from '../view/Sprites';
import { feedbackOutcome, feedbackReveal, feedbackTick } from '../view/Feedback';
import { SND_TICK, SND_WIN, SoundBoard } from '../view/Sound';
import { TutorialContent } from '../view/TutorialContent';

enum GameState {
  /** 还没落子，雷尚未布置（首击之后才布） */
  READY,
  PLAYING,
  WON,
  LOST
}

/** 人脸贴图的五种状态，对应图集里的 face_* */
const FACE_NORMAL: number = 4;
const FACE_DOWN: number = 0;
const FACE_SCAN: number = 1;
const FACE_DEAD: number = 2;
const FACE_WIN: number = 3;

/** 按下状态：0 没按，1 按在未翻开的格上，2 按在已翻开的格上 */
const PRESS_NONE: number = 0;
const PRESS_HIDDEN: number = 1;
const PRESS_OPEN: number = 2;

const MAX_SECONDS: number = 9999;
/** 贴图原始尺寸，格子不能再小 —— 像素画缩着画会糊 */
const MIN_EDGE: number = 16;
const MAX_EDGE: number = 36;
/**
 * 沉浸式标题栏和悬浮底栏都浮在内容之上、不占内容区的布局，所以内容要自己让位。
 * 这两个数值取自 Dashboard 工程里页面用的留白量（顶部 Blank 100、底部 110）——
 * 那是实测过的，比自己估靠谱。
 */
const TITLE_BAR_INSET: number = 120;
const FLOATING_BAR_ROOM: number = 110;

/**
 * 系统浮动材质。用数值而不是枚举，理由和 Dashboard 工程一样：
 * 枚举要从 hdsMaterial 引入，老一点的设备上解析不了。
 * SDK 26 里 MaterialType.ADAPTIVE = 100，跟随系统策略。
 */
const HDS_MATERIAL_TYPE_ADAPTIVE: number = 100;
const HDS_MATERIAL_LEVEL_GENTLE: number = 1;

/**
 * 底栏标签的样式。本应用不做深色适配，底栏恒为银灰：
 * 未选中钉死黑色 —— 不钉的话 HDS 会按深色材质把它反白，白字压在银灰上看不清；
 * 选中保留系统强调色，全黑就没有选中态了。
 */
function tabBarStyle(icon: Resource, text: string): BottomTabBarStyle {
  return new BottomTabBarStyle(icon, text).labelStyle({
    selectedColor: $r('sys.color.brand'),
    unselectedColor: $r('app.color.classic_dark')
  });
}

/**
 * 首帧先用屏幕宽度估一个棋盘可用宽度。
 *
 * 真实值是 onAreaChange 测出来的，但那要等第一次布局之后 —— 在那之前
 * boardAreaWidth 是 0，格子会按最小尺寸画一帧，然后"啪"地跳成正确大小。
 * 先用屏幕宽度垫上，视觉上就没有这一跳。
 */
function estimateBoardWidth(): number {
  try {
    // 不用 px2vp（已弃用），直接拿屏幕密度换算 px → vp。
    // 页面左右各 8 内边距，棋盘面板的内边距与边框再吃掉 8，所以减 24。
    const d = display.getDefaultDisplaySync();
    return d.width / d.densityPixels - 24;
  } catch (err) {
    return 320;
  }
}

function range(n: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < n; i++) {
    out.push(i);
  }
  return out;
}

@Entry
@Component
struct Index {
  @State board: Board =
    new Board(DIFFICULTIES[0].w, DIFFICULTIES[0].h, DIFFICULTIES[0].mines, 1);
  @State difficultyIndex: number = 0;
  @State selectedTab: number = 0;
  @State gameState: GameState = GameState.READY;
  @State elapsed: number = 0;
  /** 每次开新局自增。它是 ForEach 的 key 的一部分，用来强制重建所有格子组件。 */
  @State gameId: number = 0;
  @State bestSeconds: number = 0;
  @State newRecord: boolean = false;
  /** 手指正按在棋盘上，按的是不是已翻开的格子（决定脸是吃惊还是扫视） */
  @State pressing: number = PRESS_NONE;
  /** 展开判定没过时的提示，过一会儿自动消失 */
  @State judgeHint: string = '';
  /** 棋盘区域的实测尺寸，用来把格子压到刚好放得下 */
  @State boardAreaWidth: number = estimateBoardWidth();
  @State boardAreaHeight: number = 0;
  /** 网格的行列下标，开新局时按新尺寸重建 */
  @State rowIndexes: number[] = range(DIFFICULTIES[0].h);
  @State colIndexes: number[] = range(DIFFICULTIES[0].w);
  @State showTutorial: boolean = false;
  /**
   * 四种雷各自还剩几颗没标。
   *
   * 必须单独存一份 @State：@State board 只观察 Board 实例的字段被整体替换，
   * 观察不到 board.cells[i].flag 这种深层改动。放旗时格子会靠 @ObjectLink 自己重绘，
   * 但页面不会重绘，计雷器就永远停在开局的值上。
   */
  @State flagMarks: number[] = [0, 0, 0, 0];

  private tabsController: HdsTabsController = new HdsTabsController();
  private stats: StatsStore = new StatsStore(DIFFICULTIES.length);
  private sound: SoundBoard = new SoundBoard();
  private timerId: number = -1;
  private hintTimerId: number = -1;
  private startedAt: number = 0;
  private tickedSecond: number = -1;
  private seed: number = 1;

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined) {
      this.stats.load(ctx).then(() => {
        this.syncBest();
      }).catch(() => {
      });
      // 不 await：音频初始化失败只会静音，不该拖住界面
      this.sound.init(ctx);
    }
  }

  aboutToDisappear(): void {
    this.stopTimer();
    this.sound.release();
    if (this.hintTimerId !== -1) {
      clearInterval(this.hintTimerId);
      this.hintTimerId = -1;
    }
  }

  // ---------------- 计时 ----------------
  // 用开始时刻反推已用时间，而不是每秒 +1。
  // setInterval 本身会漂移，定时器被系统压制时漂得更厉害，累加出来的秒数不作数。

  private startTimer(): void {
    this.stopTimer();
    this.startedAt = Date.now();
    this.tickedSecond = -1;
    this.timerId = setInterval(() => {
      const s: number = Math.floor((Date.now() - this.startedAt) / 1000);
      const shown: number = s > MAX_SECONDS ? MAX_SECONDS : s;
      // 整秒才滴答一下，250ms 的轮询不至于一秒响四次
      if (shown !== this.tickedSecond && shown > 0) {
        this.tickedSecond = shown;
        this.sound.play(SND_TICK);
      }
      this.elapsed = shown;
    }, 250);
  }

  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private syncBest(): void {
    const s: DifficultyStats = this.stats.get(this.difficultyIndex);
    this.bestSeconds = s.bestSeconds;
  }

  /** 把计雷器的数字从棋盘同步过来，顺带触发页面重绘 */
  private refreshMarks(): void {
    this.flagMarks = [
      this.board.unmarked(0), this.board.unmarked(1),
      this.board.unmarked(2), this.board.unmarked(3)
    ];
  }

  // ---------------- 局面控制 ----------------

  private newGame(index: number): void {
    this.stopTimer();
    const d: Difficulty = DIFFICULTIES[index];
    this.difficultyIndex = index;
    // 线性同余推进种子：每次开新局都是不同的棋盘，但种子可复现
    this.seed = (this.seed * 1664525 + 1013904223) >>> 0;
    this.board = new Board(d.w, d.h, d.mines, this.seed);
    this.rowIndexes = range(d.h);
    this.colIndexes = range(d.w);
    this.gameState = GameState.READY;
    this.elapsed = 0;
    this.newRecord = false;
    this.pressing = PRESS_NONE;
    this.judgeHint = '';
    this.gameId += 1;
    this.refreshMarks();
    this.syncBest();
  }

  /** 切换难度标签：换难度才重开 */
  private onTabChanged(index: number): void {
    this.selectedTab = index;
    if (index !== this.difficultyIndex) {
      this.newGame(index);
    }
  }

  private flashHint(text: string): void {
    this.judgeHint = text;
    if (this.hintTimerId !== -1) {
      clearInterval(this.hintTimerId);
    }
    this.hintTimerId = setInterval(() => {
      this.judgeHint = '';
      clearInterval(this.hintTimerId);
      this.hintTimerId = -1;
    }, 1600);
  }

  private finishGame(): void {
    this.stopTimer();
    this.pressing = PRESS_NONE;
    feedbackOutcome();
    if (this.board.isWon()) {
      this.gameState = GameState.WON;
      this.sound.play(SND_WIN);
      // 秒数下限取 1：bestSeconds 用 0 表示"还没有纪录"，
      // 真存进去一个 0 秒会把这条纪录变成"不存在"
      const seconds: number = this.elapsed > 0 ? this.elapsed : 1;
      this.newRecord = this.bestSeconds === 0 || seconds < this.bestSeconds;
      this.stats.recordWin(this.difficultyIndex, seconds).then(() => {
        this.syncBest();
      }).catch(() => {
      });
    } else {
      this.gameState = GameState.LOST;
      // 踩雷音按踩中的那一颗的雷型播，四种雷声音不同
      const boom: number = this.board.boomIndex();
      this.sound.playMine(boom >= 0 ? this.board.cells[boom].mineKind : 0);
      this.stats.recordLoss(this.difficultyIndex).catch(() => {
      });
    }
  }

  /** 长按：翻开 */
  private handleReveal(row: number, col: number): void {
    if (this.board.isOver()) {
      return;
    }
    this.pressing = PRESS_NONE;
    feedbackReveal();
    if (!this.board.isStarted()) {
      // 首击之后才布雷，首击格连同八邻域保证无雷，开局必定连片展开
      this.board.startAt(row, col);
      this.gameState = GameState.PLAYING;
      this.startTimer();
      this.refreshMarks();
      return;
    }
    const r: number = this.board.reveal(row, col);
    // 连片展开和结算都可能清掉旗子，计雷器要跟着走
    this.refreshMarks();
    if (r === ACT_BOOM) {
      this.finishGame();
    } else if (r === ACT_OK && this.board.isOver()) {
      this.finishGame();
    }
  }

  /**
   * 单击。
   *
   * 未翻开的格子：循环标记 空 → +1 → -1 → +i → -i → 空。
   * 已翻开的数字格：展开判定 —— 邻域旗数等于真实雷数、且实虚比例对得上，
   * 就一次掀开周围没插旗的格子。这是试探抵消对的手段，判据不过就什么都不发生。
   */
  private handleTap(row: number, col: number): void {
    if (this.board.isOver()) {
      return;
    }
    const cell: Cell = this.board.cellAt(row, col);
    if (!cell.open) {
      feedbackTick();
      this.board.cycleFlag(row, col);
      this.refreshMarks();
      return;
    }
    const r: number = this.board.tryExpand(row, col);
    this.refreshMarks();
    if (r === ACT_BOOM) {
      this.finishGame();
    } else if (r === ACT_OK) {
      feedbackReveal();
      if (this.board.isOver()) {
        this.finishGame();
      }
    } else if (r === ACT_JUDGE_FAIL) {
      this.flashHint('这样展开不合法');
    }
  }

  private faceKind(): number {
    if (this.gameState === GameState.WON) {
      return FACE_WIN;
    }
    if (this.gameState === GameState.LOST) {
      return FACE_DEAD;
    }
    if (this.pressing === PRESS_OPEN) {
      return FACE_SCAN;
    }
    if (this.pressing === PRESS_HIDDEN) {
      return FACE_DOWN;
    }
    return FACE_NORMAL;
  }

  // ---------------- 排版 ----------------

  /**
   * 格子边长：按实测宽度刚好放得下，并夹在 [16, 36]。
   * 16 是贴图的原始尺寸 —— 再小就得把像素画缩着画，会糊。
   * 高级 30 列在手机上放不下 16vp，于是棋盘横向滚动。
   */
  private edge(): number {
    const d: Difficulty = DIFFICULTIES[this.difficultyIndex];
    if (this.boardAreaWidth <= 0) {
      return MIN_EDGE;
    }
    const fits: number = Math.floor((this.boardAreaWidth - 8) / d.w);
    if (fits < MIN_EDGE) {
      return MIN_EDGE;
    }
    return fits > MAX_EDGE ? MAX_EDGE : fits;
  }

  private boardWidth(): number {
    return this.edge() * this.board.w;
  }

  private boardHeight(): number {
    return this.edge() * this.board.h;
  }

  /** 棋盘比可视区矮时上下平分余量，视觉上才是真的居中 */
  private boardPadTop(): number {
    const slack: number = this.boardAreaHeight - this.boardHeight() - 8;
    return slack > 0 ? Math.floor(slack / 2) : 0;
  }

  /**
   * 左右也要平分余量。
   *
   * 棋盘是定宽的，放进满宽的滚动区里默认靠左，右边留一条，看上去就像整片格子没对齐。
   * 放不下时（高级 30 列）返回 0，交给横向滚动。
   */
  private boardPadLeft(): number {
    const inner: number = this.boardAreaWidth - 4;
    const slack: number = inner - this.boardWidth();
    return slack > 0 ? Math.floor(slack / 2) : 0;
  }

  /** 这一类雷还剩几颗没标。负数类型（-1、-i）显示成负数，每插一颗就朝零走。 */
  private counterValue(t: number): number {
    const k: number = this.flagMarks[t];
    return (t === 1 || t === 3) ? -k : k;
  }

  // ---------------- 界面 ----------------

  /** 一个计雷器：这一型雷的图标 + 四格数码管 */
  @Builder
  Counter(t: number) {
    Row() {
      Image(flagSprite(t + 1))
        .width(18)
        .height(18)
        .interpolation(ImageInterpolation.None)
      LedReadout({
        value: this.counterValue(t),
        slots: 4,
        imagUnit: t >= 2,
        cellWidth: 13,
        blankAll: !this.board.isStarted()
      })
    }
    .padding({ left: 2, right: 2 })
  }

  /** 经典表头：左边四个计雷器竖排，右边人脸 + 计时 */
  @Builder
  HeaderPanel() {
    Row() {
      Column() {
        this.Counter(0)
        this.Counter(1)
        this.Counter(2)
        this.Counter(3)
      }

      Blank()

      Column({ space: 6 }) {
        Image(faceSprite(this.faceKind()))
          .width(46)
          .height(46)
          .interpolation(ImageInterpolation.None)
          .onClick(() => {
            this.newGame(this.difficultyIndex);
          })
        LedReadout({ value: this.elapsed, slots: 4, cellWidth: 13 })
      }

      Blank()
    }
    .width('100%')
    .padding(6)
    .backgroundColor($r('app.color.classic_face'))
    .border({
      width: { top: 3, left: 3, bottom: 3, right: 3 },
      color: {
        top: $r('app.color.classic_shadow'),
        left: $r('app.color.classic_shadow'),
        bottom: $r('app.color.classic_light'),
        right: $r('app.color.classic_light')
      }
    })
  }

  /**
   * 棋盘网格。
   *
   * 用 Column 套 Row 逐格摆，不用 Flex 的自动换行 —— Flex 换行是拿容器宽度
   * 去除格子宽度算出来的，除不尽就会把最后一格挤到下一行、或者让子项收缩，
   * 结果就是整片格子错位。固定列数的 Row 没有这个自由度，一定对齐。
   */
  @Builder
  BoardGrid() {
    Column() {
      ForEach(this.rowIndexes, (row: number) => {
        Row() {
          ForEach(this.colIndexes, (col: number) => {
            CellView({
              cell: this.board.cells[row * this.board.w + col],
              edge: this.edge(),
              onReveal: (r: number, c: number) => {
                this.handleReveal(r, c);
              },
              onFlag: (r: number, c: number) => {
                this.handleTap(r, c);
              },
              onPress: (down: boolean) => {
                const cell: Cell = this.board.cells[row * this.board.w + col];
                if (!down) {
                  this.pressing = PRESS_NONE;
                } else {
                  this.pressing = cell.open ? PRESS_OPEN : PRESS_HIDDEN;
                }
              }
            })
          }, (col: number) => `${this.gameId}-${row}-${col}`)
        }
      }, (row: number) => `${this.gameId}-r${row}`)
    }
  }

  /**
   * 棋盘：经典凹陷面板包住网格。
   *
   * 三层结构，宽度一层比一层确定：
   *   外层 Column（100% 宽）→ 横向 Scroll（100% 宽、显式 clip）→ 网格 Column（定宽 boardWidth）
   * 网格比可视区宽时（高级 30 列）横向滚动；比可视区窄时靠 margin 居中。
   */
  @Builder
  BoardPanel() {
    Scroll() {
      Column() {
        this.BoardPanelInner()
      }
      .width('100%')
      .padding({ top: this.boardPadTop() })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .layoutWeight(1)
    .width('100%')
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.boardAreaWidth = Number.parseFloat(newArea.width.toString()) - 8;
      this.boardAreaHeight = Number.parseFloat(newArea.height.toString());
    })
  }

  @Builder
  BoardPanelInner() {
    Column() {
      Scroll() {
        Column() {
          this.BoardGrid()
        }
        .width(this.boardWidth())
        .margin({ left: this.boardPadLeft() })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
      .width('100%')
      .height(this.boardHeight())
      // 网格比可视区宽时必须裁掉，否则会溢到屏幕外
      .clip(true)
    }
    .width('100%')
    .padding(3)
    .backgroundColor($r('app.color.classic_face'))
    .border({
      width: { top: 3, left: 3, bottom: 3, right: 3 },
      color: {
        top: $r('app.color.classic_shadow'),
        left: $r('app.color.classic_shadow'),
        bottom: $r('app.color.classic_light'),
        right: $r('app.color.classic_light')
      }
    })
  }

  private statusText(): string {
    if (this.judgeHint.length > 0) {
      return this.judgeHint;
    }
    if (this.gameState === GameState.WON) {
      return this.newRecord
        ? `通关！用时 ${this.elapsed} 秒，新纪录`
        : `通关！用时 ${this.elapsed} 秒`;
    }
    if (this.gameState === GameState.LOST) {
      return `踩雷了，用时 ${this.elapsed} 秒。绿勾标对，红叉标错`;
    }
    if (!this.board.isStarted()) {
      return '长按翻开第一格，四种雷的数量开局后公布';
    }
    return this.bestSeconds > 0
      ? `单击标记、长按翻开、点数字格可展开 【最佳 ${this.bestSeconds} 秒】`
      : '单击标记、长按翻开、点数字格可展开';
  }

  /**
   * 一个难度页：表头 + 棋盘 + 状态行。
   *
   * 沉浸由 HdsNavigation 上的 ignoreLayoutSafeArea 负责，内容区本身就是整屏的，
   * 所以这里只要铺个底色、上下各让出悬浮栏的位置就行 —— 不需要再自己 expandSafeArea。
   */
  @Builder
  GamePage() {
    Column() {
      this.HeaderPanel()
      this.BoardPanel()
      Text(this.statusText())
        .fontSize(12)
        .fontColor($r('app.color.classic_dark'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .padding({ top: 6, bottom: 2 })
    }
    .width('100%')
    .height('100%')
    // 顶部让开沉浸标题栏，底部让开悬浮底栏
    .padding({ left: 8, right: 8, top: TITLE_BAR_INSET, bottom: FLOATING_BAR_ROOM })
    .backgroundColor($r('app.color.classic_face'))
  }

  @Builder
  TutorialSheet() {
    TutorialContent()
  }

  /**
   * 「关于」弹层的标题栏。系统那套 title 只收文字、给不了颜色，标题和关闭按钮
   * 都是系统灰 —— 所以整条自己画：标题纯黑，关掉 showClose 用这里画的叉。
   */
  @Builder
  SheetTitleBar() {
    Row() {
      Column({ space: 2 }) {
        Text('关于')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.classic_dark'))
        Text('复扫雷 · ComplexSweeper')
          .fontSize(12)
          .fontColor($r('app.color.classic_shadow'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.xmark'))
        .fontSize(20)
        .fontColor([$r('app.color.classic_dark')])
        .padding(8)
        .accessibilityText('关闭')
        .onClick(() => {
          this.showTutorial = false;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 6 })
  }

  build() {
    HdsNavigation() {
      HdsTabs({ controller: this.tabsController, index: this.selectedTab }) {
        TabContent() {
          this.GamePage()
        }
        .tabBar(tabBarStyle($r('app.media.cw_tab_1'), '初级'))

        TabContent() {
          this.GamePage()
        }
        .tabBar(tabBarStyle($r('app.media.cw_tab_2'), '中级'))

        TabContent() {
          this.GamePage()
        }
        .tabBar(tabBarStyle($r('app.media.cw_tab_3'), '高级'))
      }
      .barPosition(BarPosition.End)
      .scrollable(false)
      .vertical(false)
      // 悬浮沉浸：底栏浮在内容之上，配系统浮动材质
      .barOverlap(true)
      .blurStrategy(BlurStrategy.ENABLE)
      .barFloatingStyle({
        barBottomMargin: 28,
        lightColor: $r('app.color.classic_face'),
        gradientMask: { maskColor: Color.Transparent, maskHeight: 96 },
        systemMaterialEffect: {
          materialType: HDS_MATERIAL_TYPE_ADAPTIVE,
          materialLevel: HDS_MATERIAL_LEVEL_GENTLE
        }
      })
      .onChange((index: number) => {
        this.onTabChanged(index);
      })
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    // 沉浸的关键：整个导航忽略系统安全区，铺满整屏。
    // 标题栏和悬浮底栏会各自避让状态栏与手势条，页面内容则靠上下留白让位。
    // 几条走不通的路：setWindowBackgroundColor 对手机 / 平板 / 2in1 不可用；
    // 给内容层直接加 expandSafeArea 会把内容一起顶上去，压到状态栏底下。
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .titleBar({
      content: {
        title: { mainTitle: '复扫雷' },
        // 关于常驻标题栏，三个难度页都能点开。tab 只留给难度。
        menu: {
          value: [
            {
              content: {
                label: '关于',
                icon: $r('sys.symbol.info_circle'),
                isEnabled: true,
                action: () => {
                  this.showTutorial = true;
                }
              }
            }
          ]
        }
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        // 透明底 + 系统浮动材质才是沉浸式标题栏：它让内容从底下透上来，
        // 刷成不透明色就变成一条实心色带，反而把表头压住了。
        // 标题字常态纯黑（不走 sys.color.font_primary）—— 系统那支偏灰，
        // 压在银色面板上不够实，本应用又只有浅色一套配色，不需要它跟着变。
        originalStyle: {
          backgroundStyle: { backgroundColor: Color.Transparent },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('app.color.classic_dark') },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('app.color.classic_dark'),
              textColor: $r('app.color.classic_dark')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: { backgroundColor: Color.Transparent },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('app.color.classic_dark') },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('app.color.classic_dark'),
              textColor: $r('app.color.classic_dark')
            }
          }
        },
        systemMaterialEffect: {
          materialType: HDS_MATERIAL_TYPE_ADAPTIVE,
          materialLevel: HDS_MATERIAL_LEVEL_GENTLE
        }
      }
    })
    .bindSheet($$this.showTutorial, this.TutorialSheet(), {
      // 标题栏自己画（SheetTitleBar），系统的关闭按钮也换成自己那个黑的
      title: () => { this.SheetTitleBar() },
      showClose: false,
      // 打开就是全屏，且不给 detents —— 没有档位可拖，高度不会缩回去
      height: SheetSize.LARGE,
      preferType: SheetType.BOTTOM,
      dragBar: true,
      // 弹层整体（含顶部标题区）刷成面板银灰，与页内同色 —— 用不透明背景色而不是
      // 毛玻璃：毛玻璃会把底下的页面和遮罩透上来，顶部就变成另一种灰，对不上。
      backgroundColor: $r('app.color.classic_face'),
      scrollSizeMode: ScrollSizeMode.CONTINUOUS
    })
  }
}
