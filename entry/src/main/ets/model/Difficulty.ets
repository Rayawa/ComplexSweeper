/**
 * 一档难度。三档沿用复扫雷参考实现的标准配置。
 *
 * 注意高级是 30 列 × 16 行（宽而扁），和经典扫雷专家局一致。
 * 手机上 30 列会超出一屏，棋盘横向可以滚动 —— 这是忠于参考实现的取舍，
 * 好处是格子和贴图都保持正常大小。
 */
export class Difficulty {
  readonly label: string;
  /** 列数 */
  readonly w: number;
  /** 行数 */
  readonly h: number;
  readonly mines: number;

  constructor(label: string, w: number, h: number, mines: number) {
    this.label = label;
    this.w = w;
    this.h = h;
    this.mines = mines;
  }
}

export const DIFFICULTIES: Difficulty[] = [
  new Difficulty('初级', 9, 9, 10),
  new Difficulty('中级', 16, 16, 40),
  new Difficulty('高级', 30, 16, 99)
];
