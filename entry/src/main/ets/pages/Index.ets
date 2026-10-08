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
/** 棋盘面板四周各有 3 内边距 + 3 边框，算尺寸时格子之外还要留出这么多 */
const PANEL_BOX: number = 12;

/**
 * 数码管单格宽度。表头的高度就是它撑起来的：一行读数高 23/13×单格再加 4 内边距，
 * 四个计雷器竖排，最后加上表头的 6 内边距与 3 边框：
 *
 *     表头高度 ≈ HEADER_PER_LED × 单格 + HEADER_BASE
 *
 * 表头一高，棋盘区就矮，所以这个数是"数字够大"和"别抢棋盘地方"的折中。
 * 18 在竖屏手机上算下来还剩得下整块初级棋盘；13 是贴图原宽，再小数字就糊了。
 */
const LED_CELL: number = 18;
const LED_MIN_CELL: number = 13;
const HEADER_PER_LED: number = 4 * 23 / 13;
const HEADER_BASE: number = 28;
/**
 * 表头最多占窗口高度的四分之一。矮窗（横屏、分屏、自由窗口）按这个反推数码管能画多大，
 * 不然表头会把棋盘区整个吃掉。
 */
const HEADER_HEIGHT_SHARE: number = 0.25;
/** 人脸按钮的边长（贴图 24×24） */
const FACE_SIZE: number = 46;
/** 「关于」弹层右上角关闭按钮的圆底直径，跟标题栏那颗系统菜单按钮实测一样大 */
const CLOSE_BUTTON_SIZE: number = 36;

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
  /** 内容区的实测高度（等于窗口高度），矮窗时用来决定表头和数码管能有多大 */
  @State pageHeight: number = 0;
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
   * 格子边长：宽度和高度都要放得下，再夹在 [16, 36]。
   *
   * 16 是贴图的原始尺寸 —— 再小就得把像素画缩着画，会糊。
   * 只看宽度的话，横屏、分屏这类矮窗会把整块棋盘挤进滚动区、一屏只看得到半张；
   * 所以高度也一起算 —— 一屏能看全比格子大更实用。
   * 高级 30 列在手机上按宽度算还不到 16，于是棋盘横向滚动。
   */
  private edge(): number {
    const d: Difficulty = DIFFICULTIES[this.difficultyIndex];
    if (this.boardAreaWidth <= 0) {
      return MIN_EDGE;
    }
    const byWidth: number = Math.floor((this.boardAreaWidth - 8) / d.w);
    const byHeight: number = this.boardAreaHeight > 0
      ? Math.floor((this.boardAreaHeight - PANEL_BOX) / d.h)
      : MAX_EDGE;
    const fits: number = Math.min(byWidth, byHeight);
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

  /**
   * 横向滚动区的可视宽度。
   *
   * boardAreaWidth 是外层竖向滚动区的实测宽度减 8 得来的，其中 4 属于面板左
   * 内边距 + 边框，所以再减 4 正好是里面那条横向滚动区的宽度。
   */
  private boardInnerWidth(): number {
    return this.boardAreaWidth - 4;
  }

  /**
   * 棋盘容器的宽度：装得下就撑满可视宽度，装不下（高级 30 列）就按网格本身来。
   *
   * 居中交给容器自己的对齐，不能用 margin 硬推 —— 横向 Scroll 本来就会把比可视区窄的
   * 内容居中，再叠一层 margin 就偏出去了（实测偏右约半个余量，左右一边宽一边窄）。
   */
  private boardBoxWidth(): number {
    return Math.max(this.boardWidth(), this.boardInnerWidth());
  }

  /** 棋盘面板的总高度：网格 + 四周各 3 内边距 + 3 边框 */
  private boardPanelHeight(): number {
    return this.boardHeight() + PANEL_BOX;
  }

  /**
   * 棋盘容器的总高度：装得下就撑满可视高度，装不下（矮窗里放不下整块棋盘）就按面板本身来。
   *
   * 和横向同理：Scroll 会把比可视区小的子内容自己在主轴方向居中，所以这里把尺寸钉死成
   * 可视区大小，居中交给容器的 justifyContent 去做。要是反过来用 padding 顶，
   * 就成了"padding + 居中"两遍，面板会明显偏下（实测偏下 20 上下）。
   */
  private boardBoxHeight(): number {
    return Math.max(this.boardPanelHeight(), this.boardAreaHeight);
  }

  /**
   * 数码管单格宽度：标准值就是 LED_CELL，矮窗按"表头不超过窗口四分之一"往回收，
   * 收到贴图原宽为止。竖屏手机上算下来就是 LED_CELL。
   */
  private ledCell(): number {
    const h: number = this.pageHeight;
    if (h <= 0) {
      return LED_CELL;
    }
    const cap: number = Math.floor((h * HEADER_HEIGHT_SHARE - HEADER_BASE) / HEADER_PER_LED);
    return Math.max(LED_MIN_CELL, Math.min(LED_CELL, cap));
  }

  /** 计雷器上那面小旗的边长，按 16/13 跟着数码管等比走（贴图 16×16、数码管 13×23） */
  private ledIcon(): number {
    return Math.round(this.ledCell() * 16 / 13);
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
        .width(this.ledIcon())
        .height(this.ledIcon())
        .interpolation(ImageInterpolation.None)
      LedReadout({
        value: this.counterValue(t),
        slots: 4,
        imagUnit: t >= 2,
        cellWidth: this.ledCell(),
        blankAll: !this.board.isStarted()
      })
    }
    .padding({ left: 2, right: 2 })
  }

  /**
   * 经典表头：左边四个计雷器竖排，中间人脸 + 计时。
   *
   * 三段等分（各 layoutWeight(1)）：右边空出和计雷器列一样宽的一块，人脸那列才落在
   * 面板正中。原来只在两侧各放一个 Blank，人脸会被计雷器挤到偏右，屏幕越宽偏得越多。
   */
  @Builder
  HeaderPanel() {
    Row() {
      Column() {
        this.Counter(0)
        this.Counter(1)
        this.Counter(2)
        this.Counter(3)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Image(faceSprite(this.faceKind()))
          .width(FACE_SIZE)
          .height(FACE_SIZE)
          .interpolation(ImageInterpolation.None)
          .onClick(() => {
            this.newGame(this.difficultyIndex);
          })
        LedReadout({ value: this.elapsed, slots: 4, cellWidth: this.ledCell() })
      }
      .layoutWeight(1)

      Blank()
        .layoutWeight(1)
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
   *   外层 Column（100% 宽）→ 横向 Scroll（100% 宽、显式 clip）→ 网格容器（定宽）
   * 网格比可视区宽时（高级 30 列）横向滚动；比可视区窄时容器撑满，网格在里面居中。
   */
  @Builder
  BoardPanel() {
    Scroll() {
      Column() {
        this.BoardPanelInner()
      }
      .width('100%')
      .height(this.boardBoxHeight())
      .justifyContent(FlexAlign.Center)
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
        // 容器宽度已经保证不小于可视宽度，居中就交给对齐，不再用 margin 硬推
        .width(this.boardBoxWidth())
        .alignItems(HorizontalAlign.Center)
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
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      // 这里量到的是整个窗口的高度（沉浸布局下内容区就是整屏），表头按它决定大小
      this.pageHeight = Number.parseFloat(newArea.height.toString());
    })
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
      Text('关于')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.classic_dark'))
        .layoutWeight(1)

      // 关掉按钮画成圆底，和标题栏那颗「关于」一个样子 —— 光一支叉子没有边界，
      // 压在银灰面板上不像个能按的东西
      SymbolGlyph($r('sys.symbol.xmark'))
        .fontSize(20)
        .fontColor([$r('app.color.classic_dark')])
        .width(CLOSE_BUTTON_SIZE)
        .height(CLOSE_BUTTON_SIZE)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(CLOSE_BUTTON_SIZE / 2)
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
