import { ACHIEVABLE, TYPES } from '../model/Complex';

/** 动作结果，界面据此决定要不要播音效、闪脸 */
export const ACT_IGNORED: number = 0;
/** 正常翻开了 */
export const ACT_OK: number = 1;
/** 踩雷了 */
export const ACT_BOOM: number = 2;
/** 展开判定没过，什么都没发生 */
export const ACT_JUDGE_FAIL: number = 3;

/** 结算复盘时每一格要画什么 */
export const MARK_NONE: number = 0;
/** 给一个根本不是雷的格子插了旗 —— 位置标错了，旗 + 红叉 */
export const MARK_WRONG_BLANK: number = 1;
/** 插旗的格子确实是雷 —— 位置标对了，按玩家插的那型出图（旗 + 绿勾） */
export const MARK_RIGHT_FLAG: number = 2;
/** 没插旗的雷，结算时亮出来 */
export const MARK_MINE: number = 3;

/**
 * mulberry32。和参考实现用同一个算法：同一种子出同一个棋盘，
 * 出了问题能原样复现，自检脚本也能跑确定性用例。
 */
export class Rng {
  private a: number;

  constructor(seed: number) {
    this.a = seed === 0 ? 1 : seed;
  }

  next(): number {
    this.a = (this.a + 0x6D2B79F5) >>> 0;
    let t: number = this.a;
    t = Math.imul(t ^ (t >>> 15), t | 1) >>> 0;
    t = (t ^ (t + Math.imul(t ^ (t >>> 7), t | 61))) >>> 0;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  below(n: number): number {
    return n === 0 ? 0 : Math.floor(this.next() * n);
  }
}

/**
 * 棋盘上的一格。
 *
 * 标 @Observed 是为了让 CellView 里的 @ObjectLink 能感知到字段变化，
 * 只重绘这一格。结算复盘要显示的东西在游戏结束时由引擎写回格子自身
 * （endMark），这样视图不必知道全局状态。
 */
@Observed
export class Cell {
  readonly row: number;
  readonly col: number;
  /** -1 表示不是雷；0..3 是 TYPES 的下标，代表 +1 / -1 / +i / -i */
  mineKind: number = -1;
  /** 邻域地雷复数之和的模长平方 a²+b²，只在非雷格上有意义 */
  clue: number = -1;
  /** 邻域里的真实雷数。非雷格上它等于 0 才叫"空白格" */
  nbrMines: number = 0;
  open: boolean = false;
  /** 0 表示没有旗；1..4 表示插成了 TYPES[flag - 1] 那种雷 */
  flag: number = 0;
  /** 踩中的那一颗 */
  exploded: boolean = false;
  /** 结算复盘时这一格要画什么，取值见 MARK_* */
  endMark: number = MARK_NONE;

  constructor(row: number, col: number) {
    this.row = row;
    this.col = col;
  }

  isMine(): boolean {
    return this.mineKind >= 0;
  }

  /**
   * 空白格：邻域一颗雷都没有。
   *
   * 空白和显示 "0" 是两回事 —— 显示 0 只说明周围的雷两两抵消了。
   * 只有空白格会自动向外连片展开，这条区别是玩家推理的依据之一。
   */
  isBlank(): boolean {
    return this.mineKind < 0 && this.nbrMines === 0;
  }
}

/**
 * 棋盘。规则照搬复扫雷参考实现：
 *
 *   - 四种雷等概率随机撒（不是均分），撒完把各类型的真实总数公开给玩家；
 *   - 首击格连同八邻域保证无雷，开局必定连片展开；
 *   - 插了旗的格子翻不开，连片展开也绕开它 —— 旗子保护格子；
 *   - 数字格上可以"展开"：邻域旗数等于真实雷数、且实虚比例符合真实比例
 *     或其倒数时，一次性翻开周围所有未插旗的格子。这是用来试探抵消对的。
 *   - 翻开所有非雷格就赢。结算把雷全亮出来，旗只看位置标对错（不评判雷型）。
 */
export class Board {
  /** 列数 */
  readonly w: number;
  /** 行数 */
  readonly h: number;
  readonly requestedMines: number;
  readonly cells: Cell[] = [];
  /** 各类雷的实际总数，下标 0..3 对应 TYPES。开局公开。 */
  readonly typeTotal: number[] = [0, 0, 0, 0];

  /** 每格的雷型 + 1，0 表示无雷。引擎内部使用 */
  private kinds: number[] = [];
  private mineCount: number = 0;
  private flagsOf: number[] = [0, 0, 0, 0];
  private rng: Rng;
  private started: boolean = false;
  private over: boolean = false;
  private won: boolean = false;
  private boomIdx: number = -1;
  /** 上一次展开判定是否失败，界面用来提示"这样展开不合法" */
  private judgeFailed: boolean = false;

  constructor(w: number, h: number, mines: number, seed: number) {
    this.w = w;
    this.h = h;
    this.requestedMines = mines;
    this.rng = new Rng(seed);
    const n: number = w * h;
    for (let i = 0; i < n; i++) {
      this.cells.push(new Cell(Math.floor(i / w), i % w));
      this.kinds.push(0);
    }
  }

  index(row: number, col: number): number {
    return row * this.w + col;
  }

  cellAt(row: number, col: number): Cell {
    return this.cells[this.index(row, col)];
  }

  isStarted(): boolean {
    return this.started;
  }

  isOver(): boolean {
    return this.over;
  }

  isWon(): boolean {
    return this.won;
  }

  boomIndex(): number {
    return this.boomIdx;
  }

  lastJudgeFailed(): boolean {
    return this.judgeFailed;
  }

  mineTotal(): number {
    return this.mineCount;
  }

  /** (row, col) 八邻域中落在棋盘内的下标 */
  private neighbors(row: number, col: number): number[] {
    const out: number[] = [];
    for (let dr: number = -1; dr <= 1; dr++) {
      for (let dc: number = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) {
          continue;
        }
        const r: number = row + dr;
        const c: number = col + dc;
        if (r >= 0 && r < this.h && c >= 0 && c < this.w) {
          out.push(this.index(r, c));
        }
      }
    }
    return out;
  }

  private neighborsOf(idx: number): number[] {
    return this.neighbors(Math.floor(idx / this.w), idx % this.w);
  }

  // ---------------- 开局 ----------------

  /**
   * 首击：布雷 + 算显示值 + 从首击格连片展开。
   * 首击格连同八邻域一律无雷。
   */
  startAt(row: number, col: number): void {
    const start: number = this.index(row, col);
    const n: number = this.cells.length;

    const safe: boolean[] = [];
    for (let i = 0; i < n; i++) {
      safe.push(false);
    }
    safe[start] = true;
    for (const j of this.neighborsOf(start)) {
      safe[j] = true;
    }

    const pool: number[] = [];
    for (let i = 0; i < n; i++) {
      if (!safe[i]) {
        pool.push(i);
      }
    }
    // 洗位置
    for (let i = pool.length - 1; i > 0; i--) {
      const j: number = this.rng.below(i + 1);
      const t: number = pool[i];
      pool[i] = pool[j];
      pool[j] = t;
    }

    const count: number = Math.min(this.requestedMines, pool.length);
    for (let k = 0; k < count; k++) {
      // 四种雷等概率随机，不预先均分：真实的类型分布稍后会公开给玩家
      this.kinds[pool[k]] = 1 + this.rng.below(4);
    }
    this.mineCount = count;

    this.computeClues();
    this.countTypes();
    this.started = true;
    this.cascade([start]);
  }

  private computeClues(): void {
    for (let i = 0; i < this.cells.length; i++) {
      const kind: number = this.kinds[i];
      const cell: Cell = this.cells[i];
      if (kind !== 0) {
        cell.mineKind = kind - 1;
        cell.clue = -1;
        continue;
      }
      cell.mineKind = -1;
      let a: number = 0;
      let b: number = 0;
      let mines: number = 0;
      for (const j of this.neighborsOf(i)) {
        const k: number = this.kinds[j];
        if (k === 0) {
          continue;
        }
        a += TYPES[k - 1][0];
        b += TYPES[k - 1][1];
        mines++;
      }
      cell.nbrMines = mines;
      // 存模长平方而不是模长：整数、可精确比较、可直接当贴图下标
      cell.clue = a * a + b * b;
    }
  }

  private countTypes(): void {
    for (let t = 0; t < 4; t++) {
      this.typeTotal[t] = 0;
    }
    for (let i = 0; i < this.cells.length; i++) {
      const k: number = this.kinds[i];
      if (k !== 0) {
        this.typeTotal[k - 1]++;
      }
    }
  }

  // ---------------- 查询 ----------------

  /** 邻域统计出的 (a, b)：a = 正实 − 负实，b = 正虚 − 负虚。useFlag 为真时统计旗帜。 */
  private sumsOf(idx: number, useFlag: boolean): number[] {
    let a: number = 0;
    let b: number = 0;
    for (const j of this.neighborsOf(idx)) {
      const v: number = useFlag ? this.cells[j].flag : (this.kinds[j] === 0 ? 0 : this.cells[j].mineKind + 1);
      if (v === 0) {
        continue;
      }
      a += TYPES[v - 1][0];
      b += TYPES[v - 1][1];
    }
    return [a, b];
  }

  private nbrFlagCount(idx: number): number {
    let n: number = 0;
    for (const j of this.neighborsOf(idx)) {
      if (this.cells[j].flag !== 0) {
        n++;
      }
    }
    return n;
  }

  /**
   * 展开判据：邻域旗数等于真实雷数，且"显示值区分不出来的差别"允许存在。
   *
   * 显示的是模长，整体取负看不出来，实虚交换也看不出来，
   * 所以只要求实虚比例等于真值比例、或者等于它的倒数。
   * 玩家可以拿这一点去试探周围有没有抵消对。
   */
  private matchComboTruth(idx: number): boolean {
    if (this.cells[idx].nbrMines !== this.nbrFlagCount(idx)) {
      return false;
    }
    let tr: number = 0;
    let ti: number = 0;
    let fr: number = 0;
    let fi: number = 0;
    for (const j of this.neighborsOf(idx)) {
      const kind: number = this.kinds[j];
      if (kind !== 0) {
        if (kind <= 2) {
          tr++;
        } else {
          ti++;
        }
      }
      const f: number = this.cells[j].flag;
      if (f !== 0) {
        if (f <= 2) {
          fr++;
        } else {
          fi++;
        }
      }
    }
    if (fr + fi !== tr + ti) {
      return false;
    }
    return (fr === tr && fi === ti) || (fr === ti && fi === tr);
  }

  /** 这一类雷还剩几颗没标（可以为负） */
  unmarked(t: number): number {
    return this.typeTotal[t] - this.flagsOf[t];
  }

  /** 已插旗的总数 */
  flagsTotal(): number {
    return this.flagsOf[0] + this.flagsOf[1] + this.flagsOf[2] + this.flagsOf[3];
  }

  // ---------------- 操作 ----------------

  /** 单击：空 → +1 → −1 → +i → −i → 空 */
  cycleFlag(row: number, col: number): boolean {
    const cell: Cell = this.cellAt(row, col);
    if (this.over || cell.open) {
      return false;
    }
    const old: number = cell.flag;
    const next: number = (old + 1) % 5;
    if (old !== 0) {
      this.flagsOf[old - 1]--;
    }
    cell.flag = next;
    if (next !== 0) {
      this.flagsOf[next - 1]++;
    }
    return true;
  }

  /**
   * 长按：翻开一格。插了旗的翻不开 —— 传统扫雷里旗子就是保护格子的，
   * 要翻得先单击把旗循环回"空"。
   */
  reveal(row: number, col: number): number {
    const idx: number = this.index(row, col);
    const cell: Cell = this.cells[idx];
    this.judgeFailed = false;
    if (this.over || cell.open || cell.flag !== 0) {
      return ACT_IGNORED;
    }
    if (cell.mineKind >= 0) {
      cell.open = true;
      this.lose(idx);
      return ACT_BOOM;
    }
    cell.open = true;
    if (cell.isBlank()) {
      this.cascade(this.neighborsOf(idx));
    }
    this.checkWin();
    return ACT_OK;
  }

  /**
   * 在已翻开的数字格上展开：判据过了就掀开周围所有没插旗的格子。
   * 这是试探抵消对的手段，掀到雷就输。
   */
  tryExpand(row: number, col: number): number {
    const idx: number = this.index(row, col);
    this.judgeFailed = false;
    const cell: Cell = this.cells[idx];
    if (this.over || !cell.open || cell.mineKind >= 0) {
      return ACT_IGNORED;
    }
    const targets: number[] = [];
    for (const j of this.neighborsOf(idx)) {
      if (!this.cells[j].open && this.cells[j].flag === 0) {
        targets.push(j);
      }
    }
    if (targets.length === 0) {
      return ACT_IGNORED;
    }
    if (!this.matchComboTruth(idx)) {
      this.judgeFailed = true;
      return ACT_JUDGE_FAIL;
    }
    for (const j of targets) {
      if (this.cells[j].mineKind >= 0) {
        this.cells[j].open = true;
        this.lose(j);
        return ACT_BOOM;
      }
    }
    this.cascade(targets);
    this.checkWin();
    return ACT_OK;
  }

  /**
   * 连片翻开：只在空白格上继续扩散，并且绕开插了旗的格子。
   * 注意别拿"显示 0"当扩散条件 —— 显示 0 只说明邻雷相互抵消，周围照样有雷。
   */
  private cascade(seeds: number[]): void {
    const n: number = this.cells.length;
    const queued: boolean[] = [];
    for (let i = 0; i < n; i++) {
      queued.push(false);
    }
    const stack: number[] = [];
    for (const s of seeds) {
      if (!queued[s]) {
        queued[s] = true;
        stack.push(s);
      }
    }

    while (stack.length > 0) {
      const idx: number = stack.pop() as number;
      const cell: Cell = this.cells[idx];
      if (cell.open || cell.mineKind >= 0 || cell.flag !== 0) {
        continue;
      }
      cell.open = true;
      if (!cell.isBlank()) {
        continue;
      }
      for (const j of this.neighborsOf(idx)) {
        if (!queued[j] && !this.cells[j].open && this.cells[j].mineKind < 0
          && this.cells[j].flag === 0) {
          queued[j] = true;
          stack.push(j);
        }
      }
    }
  }

  private checkWin(): void {
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i].mineKind < 0 && !this.cells[i].open) {
        return;
      }
    }
    this.over = true;
    this.won = true;
    this.endReveal();
  }

  private lose(idx: number): void {
    this.over = true;
    this.won = false;
    this.boomIdx = idx;
    this.cells[idx].exploded = true;
    this.endReveal();
  }

  /**
   * 结算复盘：把每一格该画什么写回格子自身。
   *
   * 只看旗插在哪，不看插的是哪一型 —— 旗是试探抵消对的工具，不是"这颗雷是什么"的
   * 断言，要玩家把雷型也猜中才算标对没有道理。胜负一视同仁：结算就把答案摊开，
   * 没插旗的雷一起亮出来。
   */
  private endReveal(): void {
    for (let i = 0; i < this.cells.length; i++) {
      const cell: Cell = this.cells[i];
      cell.endMark = MARK_NONE;
      if (cell.flag === 0) {
        // 没插旗的雷亮出来；踩中的那颗已经翻开了，走爆炸贴图
        if (cell.mineKind >= 0 && !cell.open) {
          cell.endMark = MARK_MINE;
        }
        continue;
      }
      cell.endMark = cell.mineKind >= 0 ? MARK_RIGHT_FLAG : MARK_WRONG_BLANK;
    }
  }
}
