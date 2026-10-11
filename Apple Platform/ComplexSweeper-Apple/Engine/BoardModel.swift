import Foundation
import Observation

/// 动作结果，界面据此决定要不要播音效、闪脸
let ACT_IGNORED: Int = 0
/// 正常翻开了
let ACT_OK: Int = 1
/// 踩雷了
let ACT_BOOM: Int = 2
/// 展开判定没过，什么都没发生
let ACT_JUDGE_FAIL: Int = 3

/// 结算复盘时每一格要画什么
let MARK_NONE: Int = 0
/// 给一个根本不是雷的格子插了旗 —— 位置标错了，旗 + 红叉
let MARK_WRONG_BLANK: Int = 1
/// 插旗的格子确实是雷 —— 位置标对了，按玩家插的那型出图（旗 + 绿勾）
let MARK_RIGHT_FLAG: Int = 2
/// 没插旗的雷，结算时亮出来
let MARK_MINE: Int = 3

/// mulberry32。和参考实现用同一个算法：同一种子出同一个棋盘，
/// 出了问题能原样复现，自检也能跑确定性用例。
///
/// 逐位照抄 JS 的写法：全程 UInt32 回绕运算（`&+` / `&*` 等价于 JS 的
/// `Math.imul` 加 `>>> 0`），最后除以 2³² 换成 [0,1) 的浮点。
struct Rng {
    private var a: UInt32

    init(seed: Int) {
        let s = UInt32(truncatingIfNeeded: seed)
        self.a = s == 0 ? 1 : s
    }

    mutating func next() -> Double {
        a = a &+ 0x6D2B79F5
        var t: UInt32 = a
        t = (t ^ (t >> 15)) &* (t | 1)
        t = t ^ (t &+ ((t ^ (t >> 7)) &* (t | 61)))
        return Double(t ^ (t >> 14)) / 4294967296.0
    }

    mutating func below(_ n: Int) -> Int {
        n == 0 ? 0 : Int(next() * Double(n))
    }
}

/// 棋盘上的一格。
///
/// 标 @Observable 是为了让 CellView 只重绘这一格：SwiftUI 在 body 里读到
/// cell.isOpen 这类属性时会自动登记依赖，字段一变就只重算那一个视图。
/// 结算复盘要显示的东西在游戏结束时由引擎写回格子自身（endMark），
/// 这样视图不必知道全局状态。
@Observable
final class Cell {
    let row: Int
    let col: Int
    /// -1 表示不是雷；0..3 是 kMineTypes 的下标，代表 +1 / -1 / +i / -i
    var mineKind: Int = -1
    /// 邻域地雷复数之和的模长平方 a²+b²，只在非雷格上有意义
    var clue: Int = -1
    /// 邻域里的真实雷数。非雷格上它等于 0 才叫「空白格」
    var nbrMines: Int = 0
    var isOpen: Bool = false
    /// 0 表示没有旗；1..4 表示插成了 kMineTypes[flag - 1] 那种雷
    var flag: Int = 0
    /// 踩中的那一颗
    var exploded: Bool = false
    /// 结算复盘时这一格要画什么，取值见 MARK_*
    var endMark: Int = MARK_NONE

    init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    var isMine: Bool { mineKind >= 0 }

    /// 空白格：邻域一颗雷都没有。
    ///
    /// 空白和显示 "0" 是两回事 —— 显示 0 只说明周围的雷两两抵消了。
    /// 只有空白格会自动向外连片展开，这条区别是玩家推理的依据之一。
    var isBlank: Bool { mineKind < 0 && nbrMines == 0 }
}
