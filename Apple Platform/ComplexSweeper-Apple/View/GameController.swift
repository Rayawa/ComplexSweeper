import Foundation
import Observation
import Combine
import CoreGraphics

/// 一局游戏的状态机
enum GameState {
    /// 还没落子，雷尚未布置（首击之后才布）
    case ready
    case playing
    case won
    case lost
}

/// 人脸贴图的五种状态，对应图集里的 face_*
let FACE_NORMAL: Int = 4
let FACE_DOWN: Int = 0
let FACE_SCAN: Int = 1
let FACE_DEAD: Int = 2
let FACE_WIN: Int = 3

let MAX_SECONDS: Int = 9999

/// 一局复扫雷的全部状态与动作。
///
/// 做成一个 @Observable 对象而不是散在视图里的 @State：视图拿到的只是一个
/// 稳定的对象引用，于是「格子变了一格」只会重算那一格，而计时器每秒走字
/// 也只需要重算读 elapsed 的那几个视图 —— 30×16 有 480 格，这一点很要紧。
///
/// 引擎对外只暴露「翻开 / 标记 / 展开 / 是否通关」，视图不碰任何布雷细节。
@Observable
final class GameController {
    private(set) var board: Board
    private(set) var mode: GameMode = .complex
    private var statsIndex: Int { mode.rawValue * kDifficulties.count + difficultyIndex }
    private(set) var difficultyIndex: Int = 0
    private(set) var gameState: GameState = .ready
    private(set) var elapsed: Int = 0
    /// 最快纪录，0 表示这一档还没有纪录
    private(set) var bestSeconds: Int = 0
    private(set) var newRecord: Bool = false
    /// 展开判定没过时的提示，过一会儿自动消失
    private(set) var judgeHint: String = ""
    /// 每次开新局自增。它是格子视图 id 的一部分，用来强制重建所有格子。
    private(set) var gameId: Int = 0

    let press = PressState()
    let stats: StatsStore
    private let sound = SoundBoard()

    /// 内容区实测高度，矮窗时用来决定表头和数码管能有多大。
    /// 不是 @Observable 意义上的状态 —— 由视图直接把量到的值传下去。
    var pageHeight: CGFloat = 0

    private var startedAt = ContinuousClock.now
    private var tickedSecond: Int = -1
    private var seed: Int = 1
    private var ticker: AnyCancellable?
    private var hintTask: Task<Void, Never>?

    init(difficultyIndex: Int = 0) {
        let d = kDifficulties[difficultyIndex]
        self.board = Board(w: d.w, h: d.h, mines: d.mines, seed: 1)
        self.stats = StatsStore(slots: kDifficulties.count * GameMode.allCases.count)
        self.difficultyIndex = difficultyIndex
        syncBest()
    }

    deinit {
        ticker?.cancel()
        hintTask?.cancel()
    }

    var difficulty: Difficulty { kDifficulties[difficultyIndex] }

    // ---------------- 计时 ----------------
    // 用开始时刻反推已用时间，而不是每秒 +1。Timer 本身会漂移，定时器被系统
    // 压制时漂得更厉害，累加出来的秒数不作数。

    private func startTimer() {
        stopTimer()
        startedAt = ContinuousClock.now
        tickedSecond = -1
        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTimer() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard gameState == .playing else { return }
        let seconds = Int(startedAt.duration(to: ContinuousClock.now).components.seconds)
        let shown = min(seconds, MAX_SECONDS)
        // 整秒才滴答一下，250ms 的轮询不至于一秒响四次
        if shown != tickedSecond && shown > 0 {
            tickedSecond = shown
            sound.play(SND_TICK)
        }
        elapsed = shown
    }

    private func syncBest() {
        bestSeconds = stats.entry(statsIndex).bestSeconds
    }

    // ---------------- 局面控制 ----------------

    func newGame(_ index: Int) {
        guard kDifficulties.indices.contains(index) else { return }
        stopTimer()
        hintTask?.cancel()
        hintTask = nil
        let d = kDifficulties[index]
        difficultyIndex = index
        // 线性同余推进种子：每次开新局都是不同的棋盘，但种子可复现
        seed = Int(UInt32(truncatingIfNeeded: seed) &* 1664525 &+ 1013904223)
        board = Board(w: d.w, h: d.h, mines: d.mines, seed: seed, mode: mode)
        gameState = .ready
        elapsed = 0
        newRecord = false
        press.mode = PRESS_NONE
        judgeHint = ""
        gameId += 1
        syncBest()
    }

    func selectMode(_ selected: GameMode) {
        guard selected != mode else { return }
        mode = selected
        newGame(difficultyIndex)
    }

    /// 切换难度标签：换难度才重开
    func selectDifficulty(_ index: Int) {
        guard index != difficultyIndex else { return }
        newGame(index)
    }

    /// 按下时换脸。按下/抬起在一次手势里会被反复调用（拖动会一直触发 onChanged），
    /// 所以这里自己挡掉重复写入 —— 状态没变就别惊动观察者。
    func setPress(open: Bool) {
        let next = open ? PRESS_OPEN : PRESS_HIDDEN
        if press.mode != next {
            press.mode = next
        }
    }

    func clearPress() {
        if press.mode != PRESS_NONE {
            press.mode = PRESS_NONE
        }
    }

    private func flashHint(_ text: String) {
        judgeHint = text
        hintTask?.cancel()
        hintTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if Task.isCancelled { return }
            self?.judgeHint = ""
        }
    }

    private func finishGame() {
        tick()
        stopTimer()
        hintTask?.cancel()
        hintTask = nil
        judgeHint = ""
        press.mode = PRESS_NONE
        feedbackOutcome()
        if board.isWon() {
            gameState = .won
            sound.play(SND_WIN)
            // 秒数下限取 1：bestSeconds 用 0 表示「还没有纪录」，
            // 真存进去一个 0 秒会把这条纪录变成「不存在」
            let seconds = elapsed > 0 ? elapsed : 1
            let previous = stats.entry(statsIndex).bestSeconds
            newRecord = previous == 0 || seconds < previous
            stats.recordWin(statsIndex, seconds: seconds)
            syncBest()
        } else {
            gameState = .lost
            // 踩雷音按踩中的那一颗的雷型播，四种雷声音不同
            let boom = board.boomIndex()
            sound.playMine(boom >= 0 ? board.cells[boom].mineKind : 0)
            stats.recordLoss(statsIndex)
            syncBest()
        }
    }

    /// 长按 / 左键：翻开
    func reveal(_ row: Int, _ col: Int) {
        if board.isOver() { return }
        press.mode = PRESS_NONE
        let wasStarted = board.isStarted()
        let result = board.reveal(row, col)
        guard result != ACT_IGNORED else { return }
        feedbackReveal()
        if !wasStarted && board.isStarted() {
            gameState = .playing
            startTimer()
        }
        if result == ACT_BOOM {
            finishGame()
        } else if result == ACT_OK && board.isOver() {
            finishGame()
        }
    }

    /// 轻点 / 右键。
    ///
    /// 未翻开的格子：循环标记 空 → +1 → -1 → +i → -i → 空。
    /// 已翻开的数字格：展开判定 —— 邻域旗数等于真实雷数、且实虚比例对得上，
    /// 就一次掀开周围没插旗的格子。这是试探抵消对的手段，判据不过就什么都不发生。
    func tap(_ row: Int, _ col: Int) {
        if board.isOver() || row < 0 || row >= board.h || col < 0 || col >= board.w { return }
        let cell = board.cellAt(row, col)
        if !cell.isOpen {
            feedbackTick()
            board.cycleFlag(row, col)
            return
        }
        let result = board.tryExpand(row, col)
        if result == ACT_BOOM {
            finishGame()
        } else if result == ACT_OK {
            feedbackReveal()
            if board.isOver() {
                finishGame()
            }
        } else if result == ACT_JUDGE_FAIL {
            flashHint("这样展开不合法")
        }
    }

    // ---------------- 文案 ----------------

    var statusText: String {
        if !judgeHint.isEmpty {
            return judgeHint
        }
        if gameState == .won {
            return newRecord
                ? "通关！用时 \(elapsed) 秒，新纪录"
                : "通关！用时 \(elapsed) 秒"
        }
        if gameState == .lost {
            return "踩雷了，用时 \(elapsed) 秒。绿勾标对，红叉标错"
        }
        if !board.isStarted() {
            #if os(macOS)
            return "左键翻开第一格，四种雷的数量开局后公布"
            #else
            return "长按翻开第一格，四种雷的数量开局后公布"
            #endif
        }
        #if os(macOS)
        let actions = "左键翻开、右键标记或展开数字格"
        #else
        let actions = "单击标记、长按翻开、点数字格可展开"
        #endif
        return bestSeconds > 0 ? "\(actions) 【最佳 \(bestSeconds) 秒】" : actions
    }
}
