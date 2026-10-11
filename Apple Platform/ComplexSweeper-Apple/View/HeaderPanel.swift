import SwiftUI

/// 一个计雷器：这一型雷的图标 + 四格数码管。
///
/// 这一类雷还剩几颗没标。负数类型（-1、-i）显示成负数，每插一颗就朝零走。
struct CounterRow: View {
    let game: GameController
    let type: Int
    let ledCell: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            PixelImage(name: Sprites.flag(type + 1),
                       width: ClassicLayout.ledIcon(cellWidth: ledCell),
                       height: ClassicLayout.ledIcon(cellWidth: ledCell))
            LedReadout(value: counterValue,
                       slots: 4,
                       imagUnit: type >= 2,
                       cellWidth: ledCell,
                       blankAll: !game.board.isStarted())
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("counter-\(type)")
        .accessibilityLabel("\(kTypeLabels[type]) 剩余雷数")
        .accessibilityValue(game.board.isStarted() ? "\(counterValue)" : "开局后公布")
    }

    private var counterValue: Int {
        let k = game.board.unmarked(type)
        return (type == 1 || type == 3) ? -k : k
    }
}

/// 人脸按钮的当前表情。
///
/// 单独做成一个视图：只有它读按下状态，于是手指按上按下的瞬间，重算的只有这张脸，
/// 480 个格子一动不动。
struct FaceButton: View {
    let game: GameController

    var body: some View {
        PixelImage(name: Sprites.face(faceKind),
                   width: ClassicLayout.faceSize,
                   height: ClassicLayout.faceSize)
            .contentShape(Rectangle())
            .onTapGesture {
                game.newGame(game.difficultyIndex)
            }
            .accessibilityLabel("重新开始")
            .accessibilityIdentifier("restart")
    }

    private var faceKind: Int {
        switch game.gameState {
        case .won:
            return FACE_WIN
        case .lost:
            return FACE_DEAD
        case .ready, .playing:
            if game.press.mode == PRESS_OPEN { return FACE_SCAN }
            if game.press.mode == PRESS_HIDDEN { return FACE_DOWN }
            return FACE_NORMAL
        }
    }
}

/// 计时数码管。同样单独成视图：秒数每秒都在走，不该带着四个计雷器一起重算。
private struct TimerReadout: View {
    let game: GameController
    let cellWidth: CGFloat

    var body: some View {
        LedReadout(value: game.elapsed, slots: 4, cellWidth: cellWidth)
    }
}

/// 经典表头：左边四个计雷器竖排，中间人脸 + 计时。
///
/// 三段等分（各占满一份宽度）：右边空出和计雷器列一样宽的一块，人脸那列才落在
/// 面板正中。原来只在两侧各放一个 Spacer 的话，人脸会被计雷器挤到偏右，屏幕越宽偏得越多。
struct HeaderPanel: View {
    let game: GameController
    let pageHeight: CGFloat

    var body: some View {
        let ledCell = ClassicLayout.ledCellWidth(pageHeight: pageHeight)
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<4, id: \.self) { t in
                    CounterRow(game: game, type: t, ledCell: ledCell)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                FaceButton(game: game)
                TimerReadout(game: game, cellWidth: ledCell)
            }
            .frame(maxWidth: .infinity)

            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        }
        .padding(6)
        .background(Classic.face)
        .classicBevel(raised: false)
    }
}

/// 状态行：一句操作提示，或者结算结果。
struct StatusLine: View {
    let game: GameController

    var body: some View {
        Text(game.statusText)
            .font(.system(size: 12))
            .foregroundStyle(Classic.dark)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .accessibilityIdentifier("status")
    }
}
