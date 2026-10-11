import SwiftUI
import Observation

/// 经典扫雷的配色。
///
/// 上游素材只有银灰一套配色，本应用不做深色适配：面板恒为 #C0C0C0，
/// 立体边靠一白一灰两道，和原作 Win32 版一致。
enum Classic {
    static let face = Color(red: 0xC0 / 255, green: 0xC0 / 255, blue: 0xC0 / 255)
    static let light = Color.white
    static let shadow = Color(red: 0x80 / 255, green: 0x80 / 255, blue: 0x80 / 255)
    static let dark = Color.black
    static let ledBackground = Color.black
}

/// 经典扫雷的立体边。
///
/// 四道等宽色条拼出来：凸面板左上白、右下灰；凹面板（表头和棋盘）反过来。
/// 用四条 Rectangle 而不是 Path —— 拐角处正好一个压一个，不需要算斜接。
struct BevelBorder: View {
    var raised: Bool
    var thickness: CGFloat

    var body: some View {
        let top = raised ? Classic.light : Classic.shadow
        let bottom = raised ? Classic.shadow : Classic.light
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(top).frame(height: thickness)
                Spacer(minLength: 0)
                Rectangle().fill(bottom).frame(height: thickness)
            }
            HStack(spacing: 0) {
                Rectangle().fill(top).frame(width: thickness)
                Spacer(minLength: 0)
                Rectangle().fill(bottom).frame(width: thickness)
            }
        }
        .allowsHitTesting(false)
    }
}

/// 一张像素贴图。
///
/// 放大一律最近邻：像素画一插值就糊成一团。贴图只有一份原始位图
/// （资源目录里是 Single Scale），所以 1 点 = 1 像素由系统保证。
struct PixelImage: View {
    let name: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Image(name)
            .interpolation(.none)
            .resizable()
            .frame(width: width, height: height)
    }
}

extension View {
    /// 给一块面板套上经典立体边：内容先按 inset 内缩，再把边画在最外圈。
    func classicBevel(raised: Bool, thickness: CGFloat = 3, inset: CGFloat = 3) -> some View {
        self
            .padding(inset)
            .overlay { BevelBorder(raised: raised, thickness: thickness) }
    }
}

// ---------------- 按下状态 ----------------

/// 手指正按在棋盘上：0 没按，1 按在未翻开的格上，2 按在已翻开的格上
let PRESS_NONE: Int = 0
let PRESS_HIDDEN: Int = 1
let PRESS_OPEN: Int = 2

/// 按下状态单独放一个 @Observable 对象。
///
/// 按下的瞬间要换脸（吃惊 / 扫视），但棋盘本身不该跟着重绘 —— 30×16 有 480 格，
/// 每按一下就重排一遍太浪费。观察是按属性登记的：只有读 mode 的那个视图会重算。
@Observable
final class PressState {
    var mode: Int = PRESS_NONE
}

// ---------------- 排版常数 ----------------

/// 版面尺寸的算法，全部收在这里。
enum ClassicLayout {
    /// 贴图原始尺寸，格子不能再小 —— 像素画缩着画会糊
    static let minEdge: CGFloat = 16
    static let maxEdge: CGFloat = 36
    /// 棋盘面板四周各有 3 内边距 + 3 立体边，算尺寸时格子之外还要留出这么多
    static let panelBox: CGFloat = 6
    /// 人脸按钮的边长（贴图 24×24）
    static let faceSize: CGFloat = 46

    /// 数码管单格宽度。表头的高度就是它撑起来的：一行读数高 23/13×单格再加 4 内边距，
    /// 四个计雷器竖排，最后加上表头的 6 内边距与 3 立体边：
    ///
    ///     表头高度 ≈ headerPerLed × 单格 + headerBase
    ///
    /// 表头一高，棋盘区就矮，所以这个数是「数字够大」和「别抢棋盘地方」的折中。
    static let ledCell: CGFloat = 18
    static let ledMinCell: CGFloat = 13
    static let headerPerLed: CGFloat = 4 * 23 / 13
    static let headerBase: CGFloat = 28
    /// 表头最多占窗口高度的四分之一
    static let headerHeightShare: CGFloat = 0.25

    /// 格子边长：宽度和高度都要放得下，再夹在 [16, 36]。
    ///
    /// inner 是棋盘面板内缩之后真正能摆格子的区域。只看宽度的话，横屏、分屏
    /// 这类矮窗会把整块棋盘挤进滚动区、一屏只看得到半张；所以高度也一起算 ——
    /// 一屏能看全比格子大更实用。高级 30 列在手机上按宽度算还不到 16，于是横向滚动。
    static func edge(cols: Int, rows: Int, inner: CGSize) -> CGFloat {
        let byWidth = (inner.width / CGFloat(max(cols, 1))).rounded(.down)
        let byHeight = inner.height > 0
            ? (inner.height / CGFloat(max(rows, 1))).rounded(.down)
            : maxEdge
        let fits = min(byWidth, byHeight)
        if fits < minEdge { return minEdge }
        return fits > maxEdge ? maxEdge : fits
    }

    /// 数码管单格宽度：标准值就是 ledCell，矮窗按「表头不超过窗口四分之一」往回收，
    /// 收到贴图原宽为止。竖屏手机上算下来就是 ledCell。
    static func ledCellWidth(pageHeight: CGFloat) -> CGFloat {
        if pageHeight <= 0 { return ledCell }
        let cap = ((pageHeight * headerHeightShare - headerBase) / headerPerLed).rounded(.down)
        return max(ledMinCell, min(ledCell, cap))
    }

    /// 计雷器上那面小旗的边长，按 16/13 跟着数码管等比走（贴图 16×16、数码管 13×23）
    static func ledIcon(cellWidth: CGFloat) -> CGFloat {
        (cellWidth * 16 / 13).rounded()
    }
}
