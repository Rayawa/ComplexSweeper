import Foundation

/// 贴图查表。
///
/// 素材来自复扫雷项目的图集，已由 `Tools/slice-atlas.ts` 切成单张 PNG 写进
/// `Assets.xcassets`。这一层存在的意义就是把「用哪个下标查哪张图」收在一处，
/// 别散到各个组件里。
///
/// 注意：其中经典扫雷原始图像（closed / blank / num_* / flag_* / mine_* /
/// boom_* / wrong_* / right_* / face_*）的版权属于 Microsoft，不在本项目
/// GPL-3.0 的授权范围内，只适合个人学习用途。详见 README。
enum Sprites {
    /// 数字贴图：按模式查询24个圆复数值或39个双曲有符号值
    static func num(_ clue: Int, mode: GameMode = .complex) -> String {
        mode == .hyper ? (hyperNumbers[clue] ?? blank) : "cw_num_\(clue)"
    }

    /// 数字贴图是否存在。不存在的值只能画成空白。
    static func hasNum(_ clue: Int, mode: GameMode = .complex) -> Bool {
        (mode == .hyper ? kHyperAchievable : kAchievable).contains(clue)
    }

    /// 插着的旗，按玩家插的那一型取图（1=+1 2=-1 3=+i 4=-i）
    static func flag(_ t: Int, mode: GameMode = .complex) -> String {
        "cw_\(mode == .hyper && t >= 3 ? "h" : "")flag_\(clampType(t))"
    }

    /// 亮出来的雷，按真实雷型取图
    static func mine(_ t: Int, mode: GameMode = .complex) -> String {
        "cw_\(mode == .hyper && t >= 3 ? "h" : "")mine_\(clampType(t))"
    }

    /// 踩中的那一颗，同色雷 + 红底
    static func boom(_ t: Int, mode: GameMode = .complex) -> String {
        "cw_\(mode == .hyper && t >= 3 ? "h" : "")boom_\(clampType(t))"
    }

    /// 结算：插对的旗（插在雷上），按玩家插的那型出图，旗上画绿勾
    static func rightFlag(_ t: Int, mode: GameMode = .complex) -> String {
        "cw_\(mode == .hyper && t >= 3 ? "h" : "")rightflag_\(clampType(t))"
    }

    /// 结算：给一个根本不是雷的格子插了旗，旗上画红叉
    static let wrongBlank = "cw_wrongblank"

    /// 未翻开的格子（立体按钮）
    static let closed = "cw_closed"

    /// 已翻开的空白格 —— 邻域一颗雷都没有
    static let blank = "cw_blank"

    /// 人脸按钮的五种状态
    static func face(_ kind: Int) -> String {
        switch kind {
        case 0: return "cw_face_down"
        case 1: return "cw_face_scan"
        case 2: return "cw_face_dead"
        case 3: return "cw_face_win"
        default: return "cw_face_normal"
        }
    }

    /// 数码管的一格：0..9 是数字，10 是负号，11 是 i 单位，12 是空格
    static func led(_ cell: Int) -> String {
        switch cell {
        case 0...9: return "cw_led_\(cell)"
        case 10: return "cw_led_minus"
        case 11: return "cw_led_i"
        case 13: return "cw_led_j"
        default: return "cw_led_blank"
        }
    }

    /// 应用图标，用在「关于」弹层顶部
    static let icon = "cw_icon"

    /// 三档难度标签的小图标
    static func tab(_ index: Int) -> String {
        "cw_tab_\(min(max(index, 0), 2) + 1)"
    }

    private static let hyperNumbers: [Int: String] = [
        -64: "cw_hnum_64_i",
        -49: "cw_hnum_49_i",
        -48: "cw_hnum_48_i",
        -36: "cw_hnum_36_i",
        -35: "cw_hnum_35_i",
        -32: "cw_hnum_32_i",
        -25: "cw_hnum_25_i",
        -24: "cw_hnum_24_i",
        -21: "cw_hnum_21_i",
        -16: "cw_hnum_16_i",
        -15: "cw_hnum_15_i",
        -12: "cw_hnum_12_i",
        -9: "cw_hnum_9_i",
        -8: "cw_hnum_8_i",
        -7: "cw_hnum_7_i",
        -5: "cw_hnum_5_i",
        -4: "cw_hnum_4_i",
        -3: "cw_hnum_3_i",
        -1: "cw_hnum_1_i",
        0: "cw_num_0",
        1: "cw_num_1",
        3: "cw_hnum_3",
        4: "cw_num_4",
        5: "cw_num_5",
        7: "cw_hnum_7",
        8: "cw_num_8",
        9: "cw_num_9",
        12: "cw_hnum_12",
        15: "cw_hnum_15",
        16: "cw_num_16",
        21: "cw_hnum_21",
        24: "cw_hnum_24",
        25: "cw_num_25",
        32: "cw_num_32",
        35: "cw_hnum_35",
        36: "cw_num_36",
        48: "cw_hnum_48",
        49: "cw_num_49",
        64: "cw_num_64",
    ]

    private static func clampType(_ t: Int) -> Int {
        min(max(t, 1), 4)
    }
}
