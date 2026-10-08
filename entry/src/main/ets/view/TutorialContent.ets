import { ACHIEVABLE, formatModulus, TYPE_LABELS } from '../model/Complex';
import { flagSprite, numSprite } from '../view/Sprites';

/** ForEach 要遍历的四种雷下标 */
const TYPE_INDEXES: number[] = [0, 1, 2, 3];

/**
 * 教程内容，装在标题栏那个 bindSheet 里。
 *
 * 三段式：顶部图标配中英文名，中间正文，末尾移植者信息。
 * 这里**不加任何顶部留白** —— 弹层自己有标题栏和拖拽条，内容从它下面开始就好；
 * 底部也不留悬浮底栏那个空档，弹层里没有底栏。
 */
@Component
export struct TutorialContent {
  // ---------------- 顶部：图标 + 中英文名 ----------------

  @Builder
  AppHeader() {
    Row({ space: 14 }) {
      Image($r('app.media.cw_icon'))
        .width(56)
        .height(56)
        .interpolation(ImageInterpolation.None)
        .objectFit(ImageFit.Contain)

      Column({ space: 3 }) {
        Text('复扫雷')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.classic_dark'))
        Text('ComplexSweeper')
          .fontSize(13)
          .fontColor($r('app.color.classic_shadow'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.classic_face'))
    .border({
      width: { top: 3, left: 3, bottom: 3, right: 3 },
      color: {
        top: $r('app.color.classic_light'),
        left: $r('app.color.classic_light'),
        bottom: $r('app.color.classic_shadow'),
        right: $r('app.color.classic_shadow')
      }
    })
  }

  // ---------------- 排版小件 ----------------

  @Builder
  SectionTitle(text: string) {
    Text(text)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.classic_dark'))
      .width('100%')
      .padding({ top: 16, bottom: 6 })
  }

  @Builder
  Body(text: string) {
    Text(text)
      .fontSize(14)
      .lineHeight(21)
      .fontColor($r('app.color.classic_dark'))
      .width('100%')
      .padding({ bottom: 4 })
  }

  /** 四种雷：旗帜贴图 + 名字 */
  @Builder
  TypeRow() {
    Row({ space: 20 }) {
      ForEach(TYPE_INDEXES, (t: number) => {
        Column({ space: 4 }) {
          Image(flagSprite(t + 1))
            .width(30)
            .height(30)
            .interpolation(ImageInterpolation.None)
          Text(TYPE_LABELS[t])
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.classic_dark'))
        }
      }, (t: number) => `type-${t}`)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 6, bottom: 2 })
  }

  /** 24 个可能出现的数字，用真实贴图列出来 */
  @Builder
  ValueGrid() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(ACHIEVABLE, (v: number) => {
        Column() {
          Image(numSprite(v))
            .width(28)
            .height(28)
            .interpolation(ImageInterpolation.None)
        }
        .width(46)
        .padding({ top: 5, bottom: 5 })
      }, (v: number) => `val-${v}`)
    }
    .width('100%')
  }

  /** 末尾的一组信息行 */
  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.classic_shadow'))
        .width(72)
      Text(value)
        .fontSize(13)
        .fontColor($r('app.color.classic_dark'))
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ bottom: 5 })
  }

  // ---------------- 组装 ----------------

  build() {
    Scroll() {
      Column() {
        this.AppHeader()

        this.SectionTitle('怎么玩')
        this.Body('格子上的数字，是周围所有雷之和的模长。翻开所有非雷格就赢。')

        this.SectionTitle('四种雷')
        this.Body('它们当复数相加，和再取模长就是格子上的数。比如周围有一颗 +1 和一颗 −i，'
          + '和是 1−i，显示 √2。')
        this.TypeRow()

        this.SectionTitle('空白和 0 不是一回事')
        this.Body('空白格：周围一颗雷都没有。')
        this.Body('显示 0：周围有雷，但两两抵消了。')
        this.Body('只有空白格会自动向外连片展开。所以点开一个显示 0 的格子却没有展开，'
          + '就说明它周围有雷。')

        this.SectionTitle('数字格可以展开')
        this.Body('点一个已经翻开的数字格，如果它周围的旗子数量正好等于真实雷数、'
          + '实虚比例也对得上（或正好反过来），就会一次掀开周围没插旗的格子。'
          + '掀开是安全的，说明判断成立；不合法什么都不会发生；掀到雷就输了。')

        this.SectionTitle('操作')
        this.Body('单击未翻开的格子：循环标记 空 → +1 → −1 → +i → −i → 空。')
        this.Body('单击已翻开的数字格：展开。')
        this.Body('长按未翻开的格子：翻开。插了旗的格子翻不开，得先把旗循环回空。')

        this.SectionTitle('只会出现这 24 个数')
        this.ValueGrid()

        this.SectionTitle('移自')
        this.InfoRow('移植维护', 'Rayawa')
        this.InfoRow('原作', '青月晓 · 复扫雷（Zig + Win32）')
        this.InfoRow('规则与素材', '均来自上游项目')
        this.Body('经典扫雷原始图像素材版权属于 Microsoft，不在本项目 GPL-3.0 授权范围内，'
          + '仅作个人学习与兼容性展示之用。其余素材与代码遵循 GPL-3.0。')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 14, right: 14, bottom: 24 })
    }
    .scrollBar(BarState.Auto)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.classic_face'))
  }
}
