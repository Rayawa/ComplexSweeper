import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 一格。
///
/// 整格就是一张 16×16 的像素贴图 —— 立体边、数字、旗子、雷全画在图里了，
/// 所以这里不需要任何边框或文字，只要挑对图。选图逻辑照搬复扫雷参考实现的
/// cellSprite()，那条优先级顺序（已翻开 > 结算标记 > 旗子 > 未翻开）不能动。
struct CellView: View {
    let game: GameController
    let cell: Cell
    let edge: CGFloat

    var body: some View {
        #if os(macOS)
        // 桌面：左键翻开、右键插旗，和原作的 Win32 版一致。
        // SwiftUI 没有「右键手势」，所以垫一层透明 NSView 接鼠标事件。
        sprite
            .overlay {
                MouseButtonCatcher(
                    onClick: { button in
                        if button == 0 {
                            game.reveal(cell.row, cell.col)
                        } else {
                            game.tap(cell.row, cell.col)
                        }
                    },
                    onPress: { down in
                        setPress(down)
                    }
                )
            }
        #else
        sprite
            .overlay {
                TouchCatcher(
                    onTap: { game.tap(cell.row, cell.col) },
                    onReveal: { game.reveal(cell.row, cell.col) },
                    onPress: { setPress($0) }
                )
            }
        #endif
    }

    private var sprite: some View {
        PixelImage(name: spriteName, width: edge, height: edge)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("cell-\(cell.row)-\(cell.col)")
            .accessibilityLabel("第 \(cell.row + 1) 行，第 \(cell.col + 1) 列")
            .accessibilityValue(accessibilityValue)
    }

    private func setPress(_ down: Bool) {
        if !down {
            clearPress()
            return
        }
        game.setPress(open: cell.isOpen)
    }

    private func clearPress() {
        game.clearPress()
    }

    private var accessibilityValue: String {
        if cell.isOpen {
            if cell.isMine { return cell.exploded ? "踩中的雷" : "雷" }
            return cell.isBlank ? "空白" : "数字 \(formatClue(cell.clue))"
        }
        switch cell.endMark {
        case MARK_WRONG_BLANK: return "标错的位置"
        case MARK_RIGHT_FLAG: return "标对的位置"
        case MARK_MINE: return "雷"
        default: return cell.flag > 0 ? "旗帜 \(game.mode.typeLabels[cell.flag - 1])" : "未翻开"
        }
    }

    /// 结算复盘的标记优先于旗子，但已经翻开的格子优先于一切
    private var spriteName: String {
        if cell.isOpen {
            if cell.mineKind >= 0 {
                // 踩中的那颗底色是红的，其余的雷只是亮出来
                let kind = cell.mineKind + 1
                return cell.exploded ? Sprites.boom(kind, mode: game.mode) : Sprites.mine(kind, mode: game.mode)
            }
            // 空白格（邻域一颗雷都没有）和显示 0（周围全是抵消对）是两回事，
            // 贴图也不同：前者是没字的平板，后者画着 "0"。
            if cell.isBlank {
                return Sprites.blank
            }
            return Sprites.hasNum(cell.clue, mode: game.mode) ? Sprites.num(cell.clue, mode: game.mode) : Sprites.blank
        }

        switch cell.endMark {
        case MARK_WRONG_BLANK:
            return Sprites.wrongBlank
        case MARK_RIGHT_FLAG:
            // 按玩家自己插的那型出图：结算只看位置，不评判雷型对不对得上
            return Sprites.rightFlag(cell.flag, mode: game.mode)
        case MARK_MINE:
            return Sprites.mine(cell.mineKind + 1, mode: game.mode)
        default:
            break
        }
        if cell.flag > 0 {
            return Sprites.flag(cell.flag, mode: game.mode)
        }
        return Sprites.closed
    }
}

#if os(macOS)
/// 只负责把左/右键转成闭包的一层透明 NSView。
///
/// 做成 NSView 而不是用 contextMenu：右键要的是「插旗」这个动作本身，
/// 不是弹一个菜单出来让玩家再点一次。
struct MouseButtonCatcher: NSViewRepresentable {
    /// 参数是 0（左键）或 1（右键）
    var onClick: (Int) -> Void
    var onPress: (Bool) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onClick = onClick
        view.onPress = onPress
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.onClick = onClick
        nsView.onPress = onPress
    }

    final class CatcherView: NSView {
        var onClick: ((Int) -> Void)?
        var onPress: ((Bool) -> Void)?

        /// 窗口没激活时第一次点击也要算数，不然要从第二下才开始响应
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            onPress?(true)
        }

        override func mouseUp(with event: NSEvent) {
            onPress?(false)
            onClick?(0)
        }

        override func rightMouseDown(with event: NSEvent) {
            onPress?(true)
        }

        override func rightMouseUp(with event: NSEvent) {
            onPress?(false)
            onClick?(1)
        }
    }
}
#endif

#if os(iOS)
/// 轻点等待长按失败；一次触摸只执行一个动作，抬手与取消均清除按下态。
/// 使用 UIKit 的识别器仲裁，也让外层 ScrollView 的拖动取消开格。
private struct TouchCatcher: UIViewRepresentable {
    var onTap: () -> Void
    var onReveal: () -> Void
    var onPress: (Bool) -> Void

    func makeUIView(context: Context) -> TouchView { TouchView() }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onTap = onTap
        view.onReveal = onReveal
        view.onPress = onPress
    }

    static func dismantleUIView(_ view: TouchView, coordinator: ()) {
        view.onPress?(false)
        view.onTap = nil
        view.onReveal = nil
        view.onPress = nil
    }

    final class TouchView: UIView {
        var onTap: (() -> Void)?
        var onReveal: (() -> Void)?
        var onPress: ((Bool) -> Void)?

        init() {
            super.init(frame: .zero)
            backgroundColor = .clear
            isAccessibilityElement = false
            let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
            hold.minimumPressDuration = 0.4
            hold.allowableMovement = 12
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
            tap.require(toFail: hold)
            addGestureRecognizer(hold)
            addGestureRecognizer(tap)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        @objc private func tapped() {
            onPress?(false)
            onTap?()
        }

        @objc private func held(_ recognizer: UILongPressGestureRecognizer) {
            onPress?(false)
            if recognizer.state == .began { onReveal?() }
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            onPress?(true)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            onPress?(false)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event)
            onPress?(false)
        }
    }
}
#endif
