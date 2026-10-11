import Foundation

/// 复数扫雷的数学。
///
/// 棋盘上每个非雷格显示的是「周围八格地雷复数之和的模长」，但真正存下来的
/// 是那个和的模长平方 a²+b² —— 它恒为非负整数，可以精确比较、可以直接当
/// 贴图名查表，全程不碰浮点。只有需要写出人类可读的式子时才开方。

/// 四种雷：(实部, 虚部)。下标 0..3 依次是 +1、-1、+i、-i。
/// 棋盘里存的是「下标 + 1」，0 留给「没有雷」。
let kMineTypes: [(re: Int, im: Int)] = [
    (1, 0),    // +1
    (-1, 0),   // -1
    (0, 1),    // +i
    (0, -1),   // -i
]

/// 显示用的名字，下标 0..3 对应 kMineTypes
let kTypeLabels: [String] = ["+1", "-1", "+i", "-i"]

/// 圆复数模式下所有可能出现的显示值（存的是 a²+b²）。
///
/// 邻域最多 8 格，实部虚部各自是「正雷数减负雷数」，两者绝对值之和不超过 8，
/// 所以 a²+b² 只有这 24 种可能。图集里正好有对应的 24 张数字贴图。
let kAchievable: [Int] = [
    0, 1, 2, 4, 5, 8, 9, 10, 13, 16, 17, 18, 20,
    25, 26, 29, 32, 34, 36, 37, 40, 49, 50, 64,
]

func isAchievable(_ normSquared: Int) -> Bool {
    kAchievable.contains(normSquared)
}

/// 把模长平方 n 化简成 k√m 的形式。贴图已经画好了这些值，
/// 这个函数是这套化简规则的唯一出处（引擎自检会拿它反推回原值）。
///
///   n=0  → "0"      n=2  → "√2"     n=8  → "2√2"
///   n=9  → "3"      n=18 → "3√2"    n=50 → "5√2"
func formatModulus(_ normSquared: Int) -> String {
    if normSquared <= 0 {
        return "0"
    }
    var outside = 1
    var inside = normSquared
    var f = 2
    while f * f <= inside {
        while inside % (f * f) == 0 {
            inside /= f * f
            outside *= f
        }
        f += 1
    }
    if inside == 1 {
        return "\(outside)"
    }
    if outside == 1 {
        return "√\(inside)"
    }
    return "\(outside)√\(inside)"
}
