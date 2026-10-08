import { ledSprite } from './Sprites';

/** 数码管里的特殊格子 */
const CELL_BLANK: number = 12;
const CELL_MINUS: number = 10;
const CELL_UNIT_I: number = 11;

/**
 * 一排数码管。
 *
 * 复扫雷的计雷器是"这一类雷还剩几颗没标"，虚雷那一档最后一格是 i 单位而不是数字，
 * 所以这里要能按需留出单位格。数字一律右对齐、前导零不亮。
 */
@Component
export struct LedReadout {
  /**
   * 必须用 @Prop：ArkUI 里子组件未加装饰器的成员变量只在构造时赋值，
   * 父组件重绘不会同步过来。用普通变量的话，计时器会永远停在 0。
   */
  @Prop value: number = 0;
  /** 一共几格 */
  slots: number = 4;
  /** 最后一格是 i 单位（正虚雷、负虚雷用） */
  imagUnit: boolean = false;
  /** 单格宽度；高度按贴图比例 23:13 算 */
  cellWidth: number = 13;
  /** 还没开局时不显示任何数字 —— 那时各类雷的颗数还没抽出来 */
  @Prop blankAll: boolean = false;

  private cellHeight(): number {
    return this.cellWidth * 23 / 13;
  }

  /** 算出每一格该显示什么：0..9 数字、10 负号、11 i 单位、12 空格 */
  private codes(): number[] {
    const out: number[] = [];
    for (let i = 0; i < this.slots; i++) {
      out.push(CELL_BLANK);
    }
    if (this.blankAll) {
      return out;
    }
    const digitSlots: number = this.imagUnit ? this.slots - 1 : this.slots;
    const negative: boolean = this.value < 0;
    let rest: number = Math.abs(Math.round(this.value));

    let pos: number = digitSlots - 1;
    while (pos >= 0) {
      out[pos] = rest % 10;
      rest = Math.floor(rest / 10);
      if (rest === 0) {
        break;
      }
      pos--;
    }
    // 负号紧挨在最高位数字左边；位数占满了就只好不画负号
    if (negative && pos - 1 >= 0) {
      out[pos - 1] = CELL_MINUS;
    }
    if (this.imagUnit) {
      out[this.slots - 1] = CELL_UNIT_I;
    }
    return out;
  }

  build() {
    Row() {
      ForEach(this.codes(), (code: number, index: number) => {
        Image(ledSprite(code))
          .width(this.cellWidth)
          .height(this.cellHeight())
          .interpolation(ImageInterpolation.None)
          .objectFit(ImageFit.Fill)
      }, (code: number, index: number) => `${index}-${code}`)
    }
    .backgroundColor($r('app.color.led_bg'))
    .padding(2)
  }
}
