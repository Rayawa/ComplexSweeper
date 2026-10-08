import { Cell, MARK_MINE, MARK_NONE, MARK_RIGHT, MARK_RIGHT_FLAG, MARK_WRONG, MARK_WRONG_BLANK, MARK_WRONG_FLAG } from '../engine/Board';
import { hasNumSprite } from './Sprites';
import {
  blankSprite,
  boomSprite,
  closedSprite,
  flagSprite,
  mineSprite,
  numSprite,
  rightFlagSprite,
  rightSprite,
  wrongBlankSprite,
  wrongFlagSprite,
  wrongSprite
} from './Sprites';

/**
 * 一格。
 *
 * 整格就是一张 16×16 的像素贴图 —— 立体边、数字、旗子、雷全画在图里了，
 * 所以这里不需要任何边框或文字，只要挑对图。选图逻辑照搬复扫雷参考实现的
 * cellSprite()，那条优先级顺序（结算标记 > 旗子 > 未翻开）不能动。
 */
@Component
export struct CellView {
  @ObjectLink cell: Cell;
  /**
   * 必须用 @Prop：格子边长在首帧之后还会变一次 —— 棋盘区域的实测宽度要等
   * onAreaChange 才知道。用普通变量的话，首屏会一直停在 16vp 那个小尺寸上。
   */
  @Prop edge: number = 16;
  onReveal: (row: number, col: number) => void = () => {
  };
  onFlag: (row: number, col: number) => void = () => {
  };
  onPress: (down: boolean) => void = () => {
  };

  /** 结算复盘的标记优先于一切：那时要显示的是"你标得对不对" */
  private endMarkSprite(): Resource | null {
    const kind: number = this.cell.mineKind + 1;
    switch (this.cell.endMark) {
      case MARK_WRONG_BLANK:
        return wrongBlankSprite();
      case MARK_WRONG:
        return wrongSprite(kind);
      case MARK_RIGHT:
        return rightSprite(kind);
      case MARK_RIGHT_FLAG:
        return rightFlagSprite(kind);
      case MARK_WRONG_FLAG:
        return wrongFlagSprite(kind !== 0 ? kind : this.cell.flag);
      case MARK_MINE:
        return mineSprite(kind);
      default:
        return null;
    }
  }

  private sprite(): Resource {
    if (this.cell.open) {
      if (this.cell.mineKind >= 0) {
        // 踩中的那颗底色是红的，其余的雷只是亮出来
        const kind: number = this.cell.mineKind + 1;
        return this.cell.exploded ? boomSprite(kind) : mineSprite(kind);
      }
      // 空白格（邻域一颗雷都没有）和显示 0（周围全是抵消对）是两回事，
      // 贴图也不同：前者是没字的平板，后者画着 "0"。
      if (this.cell.isBlank()) {
        return blankSprite();
      }
      return hasNumSprite(this.cell.clue) ? numSprite(this.cell.clue) : blankSprite();
    }
    const mark: Resource | null = this.endMarkSprite();
    if (mark !== null) {
      return mark;
    }
    if (this.cell.flag > 0) {
      return flagSprite(this.cell.flag);
    }
    return closedSprite();
  }

  build() {
    Image(this.sprite())
      .width(this.edge)
      .height(this.edge)
      // 像素画放大必须用最近邻，插值一开就糊成一团
      .interpolation(ImageInterpolation.None)
      .objectFit(ImageFit.Fill)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.onPress(true);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.onPress(false);
        }
      })
      .gesture(
        // Exclusive：谁先达成谁生效。按住 400ms 是长按（开格），
        // 在那之前松手就是单击（未翻开→循环标记，已翻开→展开判定）。
        GestureGroup(GestureMode.Exclusive,
          LongPressGesture({ repeat: false, duration: 400 })
            .onAction(() => {
              this.onReveal(this.cell.row, this.cell.col);
            }),
          TapGesture({ count: 1 })
            .onAction(() => {
              this.onFlag(this.cell.row, this.cell.col);
            })
        )
      )
  }
}
