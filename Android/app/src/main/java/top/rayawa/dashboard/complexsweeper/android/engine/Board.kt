package top.rayawa.dashboard.complexsweeper.android.engine

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import top.rayawa.dashboard.complexsweeper.android.model.GameMode
import top.rayawa.dashboard.complexsweeper.android.model.ACHIEVABLE
import top.rayawa.dashboard.complexsweeper.android.model.MINE_TYPES

/** 动作结果，界面据此决定要不要播音效、闪脸 */
const val ACT_IGNORED: Int = 0

/** 正常翻开了 */
const val ACT_OK: Int = 1

/** 踩雷了 */
const val ACT_BOOM: Int = 2

/** 展开判定没过，什么都没发生 */
const val ACT_JUDGE_FAIL: Int = 3

/** 结算复盘时每一格要画什么 */
const val MARK_NONE: Int = 0

/** 给一个根本不是雷的格子插了旗 —— 位置标错了，旗 + 红叉 */
const val MARK_WRONG_BLANK: Int = 1

/** 插旗的格子确实是雷 —— 位置标对了，按玩家插的那型出图（旗 + 绿勾） */
const val MARK_RIGHT_FLAG: Int = 2

/** 没插旗的雷，结算时亮出来 */
const val MARK_MINE: Int = 3

/**
 * mulberry32。和参考实现用同一个算法：同一种子出同一个棋盘，
 * 出了问题能原样复现，自检也能跑确定性用例。
 *
 * 逐位照抄 JS 的写法：Kotlin 的 Int 本来就是 32 位回绕算术，
 * `ushr` 就是 JS 的 `>>>`，`*` / `+` 就是 `Math.imul` 那套取模 2³² 的语义。
 * 最后把结果当无符号数除以 2³²，换成 [0,1) 的浮点。
 */
class Rng(seed: Int) {

    private var a: Int = if (seed == 0) 1 else seed

    fun next(): Double {
        a += 0x6D2B79F5
        var t = a
        t = (t xor (t ushr 15)) * (t or 1)
        t = t xor (t + (t xor (t ushr 7)) * (t or 61))
        return ((t xor (t ushr 14)).toLong() and 0xFFFFFFFFL) / 4294967296.0
    }

    fun below(n: Int): Int = if (n == 0) 0 else (next() * n).toInt()
}

/**
 * 棋盘上的一格。
 *
 * 每个会变的字段都是一个 Compose 状态：格子里读到哪几个字段，就只在那几个字段
 * 变化时重画 —— 和 HarmonyOS 版用 @Observed + @ObjectLink 达到的效果一样。
 * 结算复盘要显示的东西在游戏结束时由引擎写回格子自身（endMark），
 * 这样格子视图不必知道全局状态。
 */
@Stable
class Cell(val row: Int, val col: Int) {
    /** -1 表示不是雷；0..3 是 MINE_TYPES 的下标，代表 +1 / -1 / +i / -i */
    var mineKind by mutableIntStateOf(-1)

    /** 邻域显示值：圆复数 a²+b²，双曲 a²−b²；负值有效，雷格由 mineKind 区分 */
    var clue by mutableIntStateOf(-1)

    /** 邻域里的真实雷数。非雷格上它等于 0 才叫「空白格」 */
    var nbrMines by mutableIntStateOf(0)

    var isOpen by mutableStateOf(false)

    /** 0 表示没有旗；1..4 表示插成了 MINE_TYPES[flag - 1] 那种雷 */
    var flag by mutableIntStateOf(0)

    /** 踩中的那一颗 */
    var exploded by mutableStateOf(false)

    /** 结算复盘时这一格要画什么，取值见 MARK_* */
    var endMark by mutableIntStateOf(MARK_NONE)

    val isMine: Boolean get() = mineKind >= 0

    /**
     * 空白格：邻域一颗雷都没有。
     *
     * 空白和显示 "0" 是两回事 —— 显示 0 只说明周围的雷两两抵消了。
     * 只有空白格会自动向外连片展开，这条区别是玩家推理的依据之一。
     */
    val isBlank: Boolean get() = mineKind < 0 && nbrMines == 0
}

/**
 * 棋盘。规则照搬复扫雷参考实现：
 *
 *   - 四种雷等概率随机撒（不是均分），撒完把各类型的真实总数公开给玩家；
 *   - 首击格连同八邻域保证无雷，开局必定连片展开；
 *   - 插了旗的格子翻不开，连片展开也绕开它 —— 旗子保护格子；
 *   - 数字格上可以「展开」：邻域旗数等于真实雷数、且实虚比例符合真实比例
 *     或其倒数时，一次性翻开周围所有未插旗的格子。这是用来试探抵消对的。
 *   - 翻开所有非雷格就赢。结算把雷全亮出来，旗只看位置标对错（不评判雷型）。
 */
@Stable
class Board(
    /** 列数 */
    val w: Int,
    /** 行数 */
    val h: Int,
    val requestedMines: Int,
    seed: Int,
    val mode: GameMode = GameMode.COMPLEX,
) {
    val cells: List<Cell>

    /** 每格的雷型 + 1，0 表示无雷。引擎内部使用 */
    private val kinds = IntArray(w * h)
    private val flagsOf = mutableStateListOf(0, 0, 0, 0)
    private val typeTotals = mutableStateListOf(0, 0, 0, 0)
    private var rng = Rng(seed)
    private var mineCount = 0
    private var started by mutableStateOf(false)
    private var over by mutableStateOf(false)
    private var won by mutableStateOf(false)
    private var boomIdx by mutableIntStateOf(-1)

    /** 上一次展开判定是否失败，界面用来提示「这样展开不合法」 */
    private var judgeFailed by mutableStateOf(false)

    /** 各类雷的实际总数，下标 0..3 对应 MINE_TYPES。开局公开。 */
    val typeTotal: List<Int> get() = typeTotals

    init {
        cells = (0 until w * h).map { Cell(it / w, it % w) }
    }

    fun index(row: Int, col: Int): Int = row * w + col

    fun cellAt(row: Int, col: Int): Cell = cells[index(row, col)]

    fun isStarted(): Boolean = started

    fun isOver(): Boolean = over

    fun isWon(): Boolean = won

    fun boomIndex(): Int = boomIdx

    fun lastJudgeFailed(): Boolean = judgeFailed

    fun mineTotal(): Int = mineCount

    /** (row, col) 八邻域中落在棋盘内的下标 */
    private fun neighbors(row: Int, col: Int): List<Int> {
        val out = ArrayList<Int>(8)
        for (dr in -1..1) {
            for (dc in -1..1) {
                if (dr == 0 && dc == 0) continue
                val r = row + dr
                val c = col + dc
                if (r in 0 until h && c in 0 until w) {
                    out.add(index(r, c))
                }
            }
        }
        return out
    }

    private fun neighborsOf(idx: Int): List<Int> = neighbors(idx / w, idx % w)

    // ---------------- 开局 ----------------

    /**
     * 首击：布雷 + 算显示值 + 从首击格连片展开。
     * 首击格连同八邻域一律无雷。
     */
    fun startAt(row: Int, col: Int) {
        if (started || over || !contains(row, col) || cellAt(row, col).flag != 0) return
        val start = index(row, col)
        val n = cells.size

        val safe = BooleanArray(n)
        safe[start] = true
        for (j in neighborsOf(start)) {
            safe[j] = true
        }

        val pool = ArrayList<Int>(n)
        for (i in 0 until n) {
            if (!safe[i]) pool.add(i)
        }
        // 洗位置
        for (i in pool.size - 1 downTo 1) {
            val j = rng.below(i + 1)
            val t = pool[i]
            pool[i] = pool[j]
            pool[j] = t
        }

        val count = minOf(requestedMines, pool.size)
        for (k in 0 until count) {
            // 四种雷等概率随机，不预先均分：真实的类型分布稍后会公开给玩家
            kinds[pool[k]] = 1 + rng.below(4)
        }
        mineCount = count

        computeClues()
        countTypes()
        started = true
        cascade(listOf(start))
        checkWin()
    }

    private fun computeClues() {
        for (i in cells.indices) {
            val kind = kinds[i]
            val cell = cells[i]
            if (kind != 0) {
                cell.mineKind = kind - 1
                cell.clue = -1
                continue
            }
            cell.mineKind = -1
            var a = 0
            var b = 0
            var mines = 0
            for (j in neighborsOf(i)) {
                val k = kinds[j]
                if (k == 0) continue
                a += MINE_TYPES[k - 1].re
                b += MINE_TYPES[k - 1].im
                mines++
            }
            cell.nbrMines = mines
            // 存整数显示值，保留双曲模式的符号，避免浮点误差
            cell.clue = if (mode == GameMode.HYPER) a * a - b * b else a * a + b * b
        }
    }

    private fun countTypes() {
        for (t in 0..3) {
            typeTotals[t] = 0
        }
        for (i in cells.indices) {
            val k = kinds[i]
            if (k != 0) {
                typeTotals[k - 1] = typeTotals[k - 1] + 1
            }
        }
    }

    // ---------------- 查询 ----------------

    /** 这一类雷还剩几颗没标（可以为负） */
    fun unmarked(t: Int): Int = typeTotals[t] - flagsOf[t]

    /** 已插旗的总数 */
    fun flagsTotal(): Int = flagsOf[0] + flagsOf[1] + flagsOf[2] + flagsOf[3]

    /**
     * 展开判据：邻域旗数等于真实雷数，且「显示值区分不出来的差别」允许存在。
     *
     * 圆复数显示的是模长，整体取负与实虚交换不可区分；双曲模式按净和分量分别比较。
     * 圆复数模式下，
     * 所以只要求实虚比例等于真值比例、或者等于它的倒数。
     * 玩家可以拿这一点去试探周围有没有抵消对。
     */
    internal fun matchComboTruth(idx: Int): Boolean {
        if (cells[idx].nbrMines != nbrFlagCount(idx)) {
            return false
        }
        if (mode == GameMode.HYPER) {
            var ta = 0; var tb = 0; var fa = 0; var fb = 0
            for (j in neighborsOf(idx)) {
                val k = kinds[j]
                val f = cells[j].flag
                if (k != 0) { ta += MINE_TYPES[k - 1].re; tb += MINE_TYPES[k - 1].im }
                if (f != 0) { fa += MINE_TYPES[f - 1].re; fb += MINE_TYPES[f - 1].im }
            }
            return kotlin.math.abs(ta) == kotlin.math.abs(fa) && kotlin.math.abs(tb) == kotlin.math.abs(fb)
        }
        var tr = 0
        var ti = 0
        var fr = 0
        var fi = 0
        for (j in neighborsOf(idx)) {
            val kind = kinds[j]
            if (kind != 0) {
                if (kind <= 2) tr++ else ti++
            }
            val f = cells[j].flag
            if (f != 0) {
                if (f <= 2) fr++ else fi++
            }
        }
        if (fr + fi != tr + ti) {
            return false
        }
        return (fr == tr && fi == ti) || (fr == ti && fi == tr)
    }

    private fun nbrFlagCount(idx: Int): Int {
        var n = 0
        for (j in neighborsOf(idx)) {
            if (cells[j].flag != 0) n++
        }
        return n
    }

    // ---------------- 操作 ----------------

    /** 单击：空 → +1 → −1 → +i → −i → 空 */
    fun cycleFlag(row: Int, col: Int): Boolean {
        if (!contains(row, col)) return false
        val cell = cellAt(row, col)
        if (over || cell.isOpen) return false
        val old = cell.flag
        val next = (old + 1) % 5
        if (old != 0) {
            flagsOf[old - 1] = flagsOf[old - 1] - 1
        }
        cell.flag = next
        if (next != 0) {
            flagsOf[next - 1] = flagsOf[next - 1] + 1
        }
        return true
    }

    /**
     * 长按：翻开一格。插了旗的翻不开 —— 传统扫雷里旗子就是保护格子的，
     * 要翻得先单击把旗循环回「空」。
     */
    fun reveal(row: Int, col: Int): Int {
        if (!contains(row, col)) return ACT_IGNORED
        val idx = index(row, col)
        val cell = cells[idx]
        judgeFailed = false
        if (over || cell.isOpen || cell.flag != 0) {
            return ACT_IGNORED
        }
        if (!started) {
            startAt(row, col)
            return ACT_OK
        }
        if (cell.mineKind >= 0) {
            cell.isOpen = true
            lose(idx)
            return ACT_BOOM
        }
        cell.isOpen = true
        if (cell.isBlank) {
            cascade(neighborsOf(idx))
        }
        checkWin()
        return ACT_OK
    }

    /**
     * 在已翻开的数字格上展开：判据过了就掀开周围所有没插旗的格子。
     * 这是试探抵消对的手段，掀到雷就输。
     */
    fun tryExpand(row: Int, col: Int): Int {
        if (!contains(row, col)) return ACT_IGNORED
        val idx = index(row, col)
        judgeFailed = false
        val cell = cells[idx]
        if (over || !cell.isOpen || cell.mineKind >= 0) {
            return ACT_IGNORED
        }
        val targets = ArrayList<Int>()
        for (j in neighborsOf(idx)) {
            if (!cells[j].isOpen && cells[j].flag == 0) targets.add(j)
        }
        if (targets.isEmpty()) {
            return ACT_IGNORED
        }
        if (!matchComboTruth(idx)) {
            judgeFailed = true
            return ACT_JUDGE_FAIL
        }
        for (j in targets) {
            if (cells[j].mineKind >= 0) {
                cells[j].isOpen = true
                lose(j)
                return ACT_BOOM
            }
        }
        cascade(targets)
        checkWin()
        return ACT_OK
    }

    /**
     * 连片翻开：只在空白格上继续扩散，并且绕开插了旗的格子。
     * 注意别拿「显示 0」当扩散条件 —— 显示 0 只说明邻雷相互抵消，周围照样有雷。
     */
    private fun cascade(seeds: List<Int>) {
        val n = cells.size
        val queued = BooleanArray(n)
        val stack = ArrayList<Int>(seeds.size)
        for (s in seeds) {
            if (!queued[s]) {
                queued[s] = true
                stack.add(s)
            }
        }

        while (stack.isNotEmpty()) {
            val idx = stack.removeAt(stack.size - 1)
            val cell = cells[idx]
            if (cell.isOpen || cell.mineKind >= 0 || cell.flag != 0) {
                continue
            }
            cell.isOpen = true
            if (!cell.isBlank) {
                continue
            }
            for (j in neighborsOf(idx)) {
                if (!queued[j] && !cells[j].isOpen && cells[j].mineKind < 0 && cells[j].flag == 0) {
                    queued[j] = true
                    stack.add(j)
                }
            }
        }
    }

    private fun contains(row: Int, col: Int): Boolean = row in 0 until h && col in 0 until w

    private fun checkWin() {
        for (cell in cells) {
            if (cell.mineKind < 0 && !cell.isOpen) {
                return
            }
        }
        over = true
        won = true
        endReveal()
    }

    private fun lose(idx: Int) {
        over = true
        won = false
        boomIdx = idx
        cells[idx].exploded = true
        endReveal()
    }

    /**
     * 结算复盘：把每一格该画什么写回格子自身。
     *
     * 只看旗插在哪，不看插的是哪一型 —— 旗是试探抵消对的工具，不是「这颗雷是什么」的
     * 断言，要玩家把雷型也猜中才算标对没有道理。胜负一视同仁：结算就把答案摊开，
     * 没插旗的雷一起亮出来。
     */
    private fun endReveal() {
        for (cell in cells) {
            cell.endMark = MARK_NONE
            if (cell.flag == 0) {
                // 没插旗的雷亮出来；踩中的那颗已经翻开了，走爆炸贴图
                if (cell.mineKind >= 0 && !cell.isOpen) {
                    cell.endMark = MARK_MINE
                }
                continue
            }
            cell.endMark = if (cell.mineKind >= 0) MARK_RIGHT_FLAG else MARK_WRONG_BLANK
        }
    }

    companion object {
        /** 可达值的集合，供自检与视图查表用 */
        val ACHIEVABLE_VALUES: List<Int> get() = ACHIEVABLE
    }
}
