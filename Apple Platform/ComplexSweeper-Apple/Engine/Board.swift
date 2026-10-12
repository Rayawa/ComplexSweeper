import Foundation
import Observation

/// 棋盘。规则照搬复扫雷参考实现：
///
///   - 四种雷等概率随机撒（不是均分），撒完把各类型的真实总数公开给玩家；
///   - 首击格连同八邻域保证无雷，开局必定连片展开；
///   - 插了旗的格子翻不开，连片展开也绕开它 —— 旗子保护格子；
///   - 数字格上可以「展开」：邻域旗数等于真实雷数、且实虚比例符合真实比例
///     或其倒数时，一次性翻开周围所有未插旗的格子。这是用来试探抵消对的。
///   - 翻开所有非雷格就赢。结算把雷全亮出来，旗只看位置标对错（不评判雷型）。
@Observable
final class Board {
    /// 列数
    let w: Int
    /// 行数
    let h: Int
    let mode: GameMode
    let requestedMines: Int
    let cells: [Cell]
    /// 各类雷的实际总数，下标 0..3 对应 kMineTypes。开局公开。
    private(set) var typeTotal: [Int] = [0, 0, 0, 0]

    /// 每格的雷型 + 1，0 表示无雷。引擎内部使用
    private var kinds: [Int]
    private var mineCount: Int = 0
    private var flagsOf: [Int] = [0, 0, 0, 0]
    private var rng: Rng
    private var started: Bool = false
    private var over: Bool = false
    private var won: Bool = false
    private var boomIdx: Int = -1
    /// 上一次展开判定是否失败，界面用来提示「这样展开不合法」
    private var judgeFailed: Bool = false

    init(w: Int, h: Int, mines: Int, seed: Int, mode: GameMode = .complex) {
        self.mode = mode
        self.w = w
        self.h = h
        self.requestedMines = mines
        self.rng = Rng(seed: seed)
        self.kinds = Array(repeating: 0, count: w * h)
        var built: [Cell] = []
        built.reserveCapacity(w * h)
        for i in 0..<(w * h) {
            built.append(Cell(row: i / w, col: i % w))
        }
        self.cells = built
    }

    func index(_ row: Int, _ col: Int) -> Int {
        row * w + col
    }

    func cellAt(_ row: Int, _ col: Int) -> Cell {
        cells[index(row, col)]
    }

    func isStarted() -> Bool { started }
    func isOver() -> Bool { over }
    func isWon() -> Bool { won }
    func boomIndex() -> Int { boomIdx }
    func lastJudgeFailed() -> Bool { judgeFailed }
    func mineTotal() -> Int { mineCount }

    /// (row, col) 八邻域中落在棋盘内的下标
    private func neighbors(_ row: Int, _ col: Int) -> [Int] {
        var out: [Int] = []
        out.reserveCapacity(8)
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let r = row + dr
                let c = col + dc
                if r >= 0 && r < h && c >= 0 && c < w {
                    out.append(index(r, c))
                }
            }
        }
        return out
    }

    private func neighborsOf(_ idx: Int) -> [Int] {
        neighbors(idx / w, idx % w)
    }

    // ---------------- 开局 ----------------

    /// 首击：布雷 + 算显示值 + 从首击格连片展开。
    /// 首击格连同八邻域一律无雷。
    func startAt(_ row: Int, _ col: Int) {
        guard !started, !over, contains(row, col), cellAt(row, col).flag == 0 else { return }
        let start = index(row, col)
        let n = cells.count

        var safe = Array(repeating: false, count: n)
        safe[start] = true
        for j in neighborsOf(start) {
            safe[j] = true
        }

        var pool: [Int] = []
        pool.reserveCapacity(n)
        for i in 0..<n where !safe[i] {
            pool.append(i)
        }
        // 洗位置
        var i = pool.count - 1
        while i > 0 {
            let j = rng.below(i + 1)
            pool.swapAt(i, j)
            i -= 1
        }

        let count = min(requestedMines, pool.count)
        for k in 0..<count {
            // 四种雷等概率随机，不预先均分：真实的类型分布稍后会公开给玩家
            kinds[pool[k]] = 1 + rng.below(4)
        }
        mineCount = count

        computeClues()
        countTypes()
        started = true
        cascade([start])
        checkWin()
    }

    private func computeClues() {
        for i in 0..<cells.count {
            let kind = kinds[i]
            let cell = cells[i]
            if kind != 0 {
                cell.mineKind = kind - 1
                cell.clue = -1
                continue
            }
            cell.mineKind = -1
            var a = 0
            var b = 0
            var mines = 0
            for j in neighborsOf(i) {
                let k = kinds[j]
                if k == 0 { continue }
                a += kMineTypes[k - 1].re
                b += kMineTypes[k - 1].im
                mines += 1
            }
            cell.nbrMines = mines
            // 存模长平方而不是模长：整数、可精确比较、可直接当贴图下标
            cell.clue = mode == .hyper ? a * a - b * b : a * a + b * b
        }
    }

    private func countTypes() {
        var totals = [0, 0, 0, 0]
        for i in 0..<cells.count {
            let k = kinds[i]
            if k != 0 {
                totals[k - 1] += 1
            }
        }
        typeTotal = totals
    }

    // ---------------- 查询 ----------------

    /// 这类雷还剩几颗没标（可以为负）
    func unmarked(_ t: Int) -> Int {
        typeTotal[t] - flagsOf[t]
    }

    /// 已插旗的总数
    func flagsTotal() -> Int {
        flagsOf[0] + flagsOf[1] + flagsOf[2] + flagsOf[3]
    }

    /// 展开判据：邻域旗数等于真实雷数，且「显示值区分不出来的差别」允许存在。
    ///
    /// 圆复数显示的是模长，整体取负与实虚交换不可区分；双曲模式按净和分量分别比较。
    /// 圆复数模式下，
    /// 所以只要求实虚比例等于真值比例、或者等于它的倒数。
    /// 玩家可以拿这一点去试探周围有没有抵消对。
    func matchComboTruth(_ idx: Int) -> Bool {
        var realMines = 0
        var realFlags = 0
        for j in neighborsOf(idx) {
            if kinds[j] != 0 { realMines += 1 }
            if cells[j].flag != 0 { realFlags += 1 }
        }
        if realMines != realFlags { return false }

        if mode == .hyper {
            var ta = 0, tb = 0, fa = 0, fb = 0
            for j in neighborsOf(idx) {
                let k = kinds[j], f = cells[j].flag
                if k != 0 { ta += kMineTypes[k - 1].re; tb += kMineTypes[k - 1].im }
                if f != 0 { fa += kMineTypes[f - 1].re; fb += kMineTypes[f - 1].im }
            }
            return abs(ta) == abs(fa) && abs(tb) == abs(fb)
        }
        var tr = 0
        var ti = 0
        var fr = 0
        var fi = 0
        for j in neighborsOf(idx) {
            let kind = kinds[j]
            if kind != 0 {
                if kind <= 2 { tr += 1 } else { ti += 1 }
            }
            let f = cells[j].flag
            if f != 0 {
                if f <= 2 { fr += 1 } else { fi += 1 }
            }
        }
        if fr + fi != tr + ti { return false }
        return (fr == tr && fi == ti) || (fr == ti && fi == tr)
    }

    // ---------------- 操作 ----------------

    /// 单击：空 → +1 → −1 → +i → −i → 空
    @discardableResult
    func cycleFlag(_ row: Int, _ col: Int) -> Bool {
        guard contains(row, col) else { return false }
        let cell = cellAt(row, col)
        if over || cell.isOpen { return false }
        let old = cell.flag
        let next = (old + 1) % 5
        if old != 0 {
            flagsOf[old - 1] -= 1
        }
        cell.flag = next
        if next != 0 {
            flagsOf[next - 1] += 1
        }
        return true
    }

    /// 长按：翻开一格。插了旗的翻不开 —— 传统扫雷里旗子就是保护格子的，
    /// 要翻得先单击把旗循环回「空」。
    func reveal(_ row: Int, _ col: Int) -> Int {
        guard contains(row, col) else { return ACT_IGNORED }
        let idx = index(row, col)
        let cell = cells[idx]
        judgeFailed = false
        if over || cell.isOpen || cell.flag != 0 {
            return ACT_IGNORED
        }
        if !started {
            startAt(row, col)
            return ACT_OK
        }
        if cell.mineKind >= 0 {
            cell.isOpen = true
            lose(idx)
            return ACT_BOOM
        }
        cell.isOpen = true
        if cell.isBlank {
            cascade(neighborsOf(idx))
        }
        checkWin()
        return ACT_OK
    }

    /// 在已翻开的数字格上展开：判据过了就掀开周围所有没插旗的格子。
    /// 这是试探抵消对的手段，掀到雷就输。
    func tryExpand(_ row: Int, _ col: Int) -> Int {
        guard contains(row, col) else { return ACT_IGNORED }
        let idx = index(row, col)
        judgeFailed = false
        let cell = cells[idx]
        if over || !cell.isOpen || cell.mineKind >= 0 {
            return ACT_IGNORED
        }
        var targets: [Int] = []
        for j in neighborsOf(idx) where !cells[j].isOpen && cells[j].flag == 0 {
            targets.append(j)
        }
        if targets.isEmpty {
            return ACT_IGNORED
        }
        if !matchComboTruth(idx) {
            judgeFailed = true
            return ACT_JUDGE_FAIL
        }
        for j in targets where cells[j].mineKind >= 0 {
            cells[j].isOpen = true
            lose(j)
            return ACT_BOOM
        }
        cascade(targets)
        checkWin()
        return ACT_OK
    }

    /// 连片翻开：只在空白格上继续扩散，并且绕开插了旗的格子。
    /// 注意别拿「显示 0」当扩散条件 —— 显示 0 只说明邻雷相互抵消，周围照样有雷。
    private func cascade(_ seeds: [Int]) {
        let n = cells.count
        var queued = Array(repeating: false, count: n)
        var stack: [Int] = []
        for s in seeds where !queued[s] {
            queued[s] = true
            stack.append(s)
        }

        while let idx = stack.popLast() {
            let cell = cells[idx]
            if cell.isOpen || cell.mineKind >= 0 || cell.flag != 0 {
                continue
            }
            cell.isOpen = true
            if !cell.isBlank {
                continue
            }
            for j in neighborsOf(idx) {
                if !queued[j] && !cells[j].isOpen && cells[j].mineKind < 0 && cells[j].flag == 0 {
                    queued[j] = true
                    stack.append(j)
                }
            }
        }
    }

    private func checkWin() {
        for cell in cells where cell.mineKind < 0 && !cell.isOpen {
            return
        }
        over = true
        won = true
        endReveal()
    }

    private func contains(_ row: Int, _ col: Int) -> Bool {
        row >= 0 && row < h && col >= 0 && col < w
    }

    private func lose(_ idx: Int) {
        over = true
        won = false
        boomIdx = idx
        cells[idx].exploded = true
        endReveal()
    }

    /// 结算复盘：把每一格该画什么写回格子自身。
    ///
    /// 只看旗插在哪，不看插的是哪一型 —— 旗是试探抵消对的工具，不是「这颗雷是什么」的
    /// 断言，要玩家把雷型也猜中才算标对没有道理。胜负一视同仁：结算就把答案摊开，
    /// 没插旗的雷一起亮出来。
    private func endReveal() {
        for cell in cells {
            cell.endMark = MARK_NONE
            if cell.flag == 0 {
                // 没插旗的雷亮出来；踩中的那颗已经翻开了，走爆炸贴图
                if cell.mineKind >= 0 && !cell.isOpen {
                    cell.endMark = MARK_MINE
                }
                continue
            }
            cell.endMark = cell.mineKind >= 0 ? MARK_RIGHT_FLAG : MARK_WRONG_BLANK
        }
    }
}
