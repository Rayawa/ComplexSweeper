package top.rayawa.dashboard.complexsweeper.android.ui

import android.content.Context
import android.os.SystemClock
import androidx.lifecycle.ViewModel
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import top.rayawa.dashboard.complexsweeper.android.engine.ACT_BOOM
import top.rayawa.dashboard.complexsweeper.android.engine.ACT_JUDGE_FAIL
import top.rayawa.dashboard.complexsweeper.android.engine.ACT_IGNORED
import top.rayawa.dashboard.complexsweeper.android.engine.ACT_OK
import top.rayawa.dashboard.complexsweeper.android.engine.Board
import top.rayawa.dashboard.complexsweeper.android.model.DIFFICULTIES
import top.rayawa.dashboard.complexsweeper.android.model.Difficulty
import top.rayawa.dashboard.complexsweeper.android.model.StatsStore

/** 一局游戏的状态机 */
enum class GameState {
    /** 还没落子，雷尚未布置（首击之后才布） */
    READY,
    PLAYING,
    WON,
    LOST,
}

/** 人脸贴图的五种状态，对应图集里的 face_* */
const val FACE_NORMAL: Int = 4
const val FACE_DOWN: Int = 0
const val FACE_SCAN: Int = 1
const val FACE_DEAD: Int = 2
const val FACE_WIN: Int = 3

/** 按下状态：0 没按，1 按在未翻开的格上，2 按在已翻开的格上 */
const val PRESS_NONE: Int = 0
const val PRESS_HIDDEN: Int = 1
const val PRESS_OPEN: Int = 2

const val MAX_SECONDS: Int = 9999

/**
 * 一局复扫雷的全部状态与动作。
 *
 * 做成一个普通的（@Stable 语义的）对象配合 Compose 状态，而不是把状态摊在
 * Composable 里：Compose 的重组是按「读到哪个状态」划范围的，所以计时器每秒
 * 走字只会重组读 elapsed 的那几个视图，480 格的棋盘纹丝不动。
 *
 * 引擎对外只暴露「翻开 / 标记 / 展开 / 是否通关」，界面不碰任何布雷细节。
 */
class GameController(context: Context) : ViewModel() {

    private val appContext = context.applicationContext
    private val sound = SoundBoard(appContext)
    private val feedback = Feedback(appContext)
    val stats = StatsStore(appContext, DIFFICULTIES.size)

    var board by mutableStateOf(
        Board(DIFFICULTIES[0].w, DIFFICULTIES[0].h, DIFFICULTIES[0].mines, 1)
    )
        private set

    var difficultyIndex by mutableIntStateOf(0)
        private set

    var gameState by mutableStateOf(GameState.READY)
        private set

    var elapsed by mutableIntStateOf(0)
        private set

    /** 最快纪录，0 表示这一档还没有纪录 */
    var bestSeconds by mutableIntStateOf(0)
        private set

    var newRecord by mutableStateOf(false)
        private set

    /** 展开判定没过时的提示，过一会儿自动消失 */
    var judgeHint by mutableStateOf("")
        private set

    /** 提示换了第几次。界面盯着它起一个定时器把提示清掉。 */
    var hintToken by mutableIntStateOf(0)
        private set

    /** 每次开新局自增。它是网格的 key，用来强制重建所有格子。 */
    var gameId by mutableIntStateOf(0)
        private set

    /** 手指正按在棋盘上，按的是不是已翻开的格子（决定脸是吃惊还是扫视） */
    var pressMode by mutableIntStateOf(PRESS_NONE)
        private set

    private var startedAt: Long = 0L
    private var tickedSecond: Int = -1
    private var seed: Int = 1

    val difficulty: Difficulty get() = DIFFICULTIES[difficultyIndex]

    init {
        syncBest()
    }

    // ---------------- 计时 ----------------
    // 用开始时刻反推已用时间，而不是每秒 +1。定时器本身会漂移，被系统压制时
    // 漂得更厉害，累加出来的秒数不作数。界面用 LaunchedEffect 每 250ms 调一次 tick()。

    private fun startTimer() {
        startedAt = SystemClock.elapsedRealtime()
        tickedSecond = -1
    }

    fun tick() {
        if (gameState != GameState.PLAYING) return
        val seconds = ((SystemClock.elapsedRealtime() - startedAt) / 1000L).toInt()
        val shown = minOf(seconds, MAX_SECONDS)
        // 整秒才滴答一下，250ms 的轮询不至于一秒响四次
        if (shown != tickedSecond && shown > 0) {
            tickedSecond = shown
            sound.play(SND_TICK)
        }
        elapsed = shown
    }

    private fun syncBest() {
        bestSeconds = stats.entry(difficultyIndex).bestSeconds
    }

    // ---------------- 按下状态 ----------------

    fun setPress(open: Boolean) {
        val next = if (open) PRESS_OPEN else PRESS_HIDDEN
        if (pressMode != next) {
            pressMode = next
        }
    }

    fun clearPress() {
        if (pressMode != PRESS_NONE) {
            pressMode = PRESS_NONE
        }
    }

    // ---------------- 局面控制 ----------------

    fun newGame(index: Int) {
        if (index !in DIFFICULTIES.indices) return
        val d = DIFFICULTIES[index]
        difficultyIndex = index
        // 线性同余推进种子：每次开新局都是不同的棋盘，但种子可复现
        seed = seed * 1664525 + 1013904223
        board = Board(d.w, d.h, d.mines, seed)
        gameState = GameState.READY
        elapsed = 0
        newRecord = false
        pressMode = PRESS_NONE
        judgeHint = ""
        hintToken++
        gameId++
        syncBest()
    }

    /** 切换难度标签：换难度才重开 */
    fun selectDifficulty(index: Int) {
        if (index == difficultyIndex) return
        newGame(index)
    }

    private fun flashHint(text: String) {
        judgeHint = text
        hintToken++
    }

    fun clearHint() {
        judgeHint = ""
    }

    private fun finishGame() {
        tick()
        judgeHint = ""
        hintToken++
        pressMode = PRESS_NONE
        feedback.outcome()
        if (board.isWon()) {
            gameState = GameState.WON
            sound.play(SND_WIN)
            // 秒数下限取 1：bestSeconds 用 0 表示「还没有纪录」，
            // 真存进去一个 0 秒会把这条纪录变成「不存在」
            val seconds = if (elapsed > 0) elapsed else 1
            val previous = stats.entry(difficultyIndex).bestSeconds
            newRecord = previous == 0 || seconds < previous
            stats.recordWin(difficultyIndex, seconds)
            syncBest()
        } else {
            gameState = GameState.LOST
            // 踩雷音按踩中的那一颗的雷型播，四种雷声音不同
            val boom = board.boomIndex()
            sound.playMine(if (boom >= 0) board.cells[boom].mineKind else 0)
            stats.recordLoss(difficultyIndex)
            syncBest()
        }
    }

    /** 长按：翻开 */
    fun reveal(row: Int, col: Int) {
        if (board.isOver()) return
        pressMode = PRESS_NONE
        val wasStarted = board.isStarted()
        val result = board.reveal(row, col)
        if (result == ACT_IGNORED) return
        feedback.reveal()
        if (!wasStarted && board.isStarted()) {
            gameState = GameState.PLAYING
            startTimer()
        }
        when (result) {
            ACT_BOOM -> finishGame()
            ACT_OK -> if (board.isOver()) finishGame()
        }
    }

    /**
     * 单击。
     *
     * 未翻开的格子：循环标记 空 → +1 → -1 → +i → -i → 空。
     * 已翻开的数字格：展开判定 —— 邻域旗数等于真实雷数、且实虚比例对得上，
     * 就一次掀开周围没插旗的格子。这是试探抵消对的手段，判据不过就什么都不发生。
     */
    fun tap(row: Int, col: Int) {
        if (board.isOver() || row !in 0 until board.h || col !in 0 until board.w) return
        val cell = board.cellAt(row, col)
        if (!cell.isOpen) {
            feedback.tick()
            board.cycleFlag(row, col)
            return
        }
        when (board.tryExpand(row, col)) {
            ACT_BOOM -> finishGame()
            ACT_OK -> {
                feedback.reveal()
                if (board.isOver()) finishGame()
            }
            ACT_JUDGE_FAIL -> flashHint("这样展开不合法")
        }
    }

    override fun onCleared() {
        sound.release()
    }

    // ---------------- 文案 ----------------

    val statusText: String
        get() {
            if (judgeHint.isNotEmpty()) {
                return judgeHint
            }
            return when {
                gameState == GameState.WON ->
                    if (newRecord) "通关！用时 $elapsed 秒，新纪录" else "通关！用时 $elapsed 秒"

                gameState == GameState.LOST -> "踩雷了，用时 $elapsed 秒。绿勾标对，红叉标错"

                !board.isStarted() -> "长按翻开第一格，四种雷的数量开局后公布"

                bestSeconds > 0 -> "单击标记、长按翻开、点数字格可展开 【最佳 $bestSeconds 秒】"

                else -> "单击标记、长按翻开、点数字格可展开"
            }
        }
}
