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
    /// 数字贴图：下标是 a²+b²（0…64），只有 kAchievable 里那 24 个有图
    static func num(_ clue: Int) -> String {
        "cw_num_\(clue)"
    }

    /// 数字贴图是否存在。不存在的值只能画成空白。
    static func hasNum(_ clue: Int) -> Bool {
        kAchievable.contains(clue)
    }

    /// 插着的旗，按玩家插的那一型取图（1=+1 2=-1 3=+i 4=-i）
    static func flag(_ t: Int) -> String {
        "cw_flag_\(clampType(t))"
    }

    /// 亮出来的雷，按真实雷型取图
    static func mine(_ t: Int) -> String {
        "cw_mine_\(clampType(t))"
    }

    /// 踩中的那一颗，同色雷 + 红底
    static func boom(_ t: Int) -> String {
        "cw_boom_\(clampType(t))"
    }

    /// 结算：插对的旗（插在雷上），按玩家插的那型出图，旗上画绿勾
    static func rightFlag(_ t: Int) -> String {
        "cw_rightflag_\(clampType(t))"
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
        default: return "cw_led_blank"
        }
    }

    /// 应用图标，用在「关于」弹层顶部
    static let icon = "cw_icon"

    /// 三档难度标签的小图标
    static func tab(_ index: Int) -> String {
        "cw_tab_\(min(max(index, 0), 2) + 1)"
    }

    private static func clampType(_ t: Int) -> Int {
        min(max(t, 1), 4)
    }
}
