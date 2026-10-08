import { TYPE_LABELS } from '../model/Complex';
import { flagSprite } from '../view/Sprites';
import { feedbackTick } from '../view/Feedback';

/** ForEach 要遍历的四种雷下标 */
const TYPE_INDEXES: number[] = [0, 1, 2, 3];

/** 「关于」底部展示的版本号，与应用配置 app.json5 的 versionName 保持一致 */
const APP_VERSION: string = '1.0.1';

/**
 * 「关于」弹层的内容，装在标题栏那个 bindSheet 里。
 *
 * 上半是基础规则：数字怎么来的、四种雷、空白和 0 的区别、怎么操作 ——
 * 展开的判定细节和 24 个可达值都没有展开写，上手之后自然碰到，
 * 这里再列一遍只会把基础规则淹掉。下半是版本、开发者与版权。
 *
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
        this.Body('显示 0：周围有雷，但正负两两抵消了。')

        this.SectionTitle('操作')
        this.Body('单击未翻开的格子：循环标记 空 → +1 → −1 → +i → −i → 空。')
        this.Body('长按未翻开的格子：翻开。插了旗的格子翻不开，得先把旗循环回空。')
        this.Body('单击已翻开的数字格：周围旗子插对时，一次掀开周围没插旗的格子。')

        // 页脚：一条分割线，然后是版本、开发者与版权
        Divider()
          .color($r('app.color.classic_shadow'))
          .margin({ top: 20, bottom: 12 })

        Text(`版本 ${APP_VERSION}`)
          .fontSize(12)
          .fontColor($r('app.color.classic_shadow'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ bottom: 6 })
          .onClick(() => {
            feedbackTick();
          })
          .accessibilityText(`版本${APP_VERSION}`)

        Text('原作 青月晓 · Complexweeper')
          .fontSize(12)
          .fontColor($r('app.color.classic_shadow'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ bottom: 6 })
          .accessibilityText('原作 青月晓 Complexweeper')

        Text('HarmonyOS 移植 Ray Chen (Rayawa)')
          .fontSize(12)
          .fontColor($r('app.color.classic_shadow'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ bottom: 6 })
          .accessibilityText('HarmonyOS 移植 Ray Chen Rayawa')

        Text('Copyright © 2026 Ray Chen (Rayawa)')
          .fontSize(12)
          .fontColor($r('app.color.classic_shadow'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .accessibilityText('版权所有 2026 Ray Chen Rayawa')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 14, right: 14, bottom: 48 })
    }
    .scrollBar(BarState.Auto)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.classic_face'))
  }
}
