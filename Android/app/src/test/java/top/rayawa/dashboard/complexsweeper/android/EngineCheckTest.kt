package top.rayawa.dashboard.complexsweeper.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import top.rayawa.dashboard.complexsweeper.android.engine.ACT_BOOM
import top.rayawa.dashboard.complexsweeper.android.engine.ACT_IGNORED
import top.rayawa.dashboard.complexsweeper.android.engine.ACT_JUDGE_FAIL
import top.rayawa.dashboard.complexsweeper.android.engine.ACT_OK
import top.rayawa.dashboard.complexsweeper.android.engine.Board
import top.rayawa.dashboard.complexsweeper.android.engine.MARK_MINE
import top.rayawa.dashboard.complexsweeper.android.engine.MARK_NONE
import top.rayawa.dashboard.complexsweeper.android.engine.MARK_RIGHT_FLAG
import top.rayawa.dashboard.complexsweeper.android.engine.MARK_WRONG_BLANK
import top.rayawa.dashboard.complexsweeper.android.model.ACHIEVABLE
import top.rayawa.dashboard.complexsweeper.android.model.DIFFICULTIES
import top.rayawa.dashboard.complexsweeper.android.model.MINE_TYPES
import top.rayawa.dashboard.complexsweeper.android.model.formatModulus
import top.rayawa.dashboard.complexsweeper.android.model.isAchievable

/**
 * 引擎逻辑校验。
 *
 * 逐条对应 HarmonyOS 版 scripts/engine-check/engine.test.ts 与 Apple 版
 * Tools/engine-check/main.swift：三个平台跑的是同一套断言、同一批固定种子，
 * 任何一个平台的引擎跑偏了都会在这里红。
 *
 *   ./gradlew :app:testDebugUnitTest
 */
class EngineCheckTest {

    private fun neighborsOf(b: Board, idx: Int): List<Int> {
        val w = b.w
        val r = idx / w
        val c = idx % w
        val out = ArrayList<Int>()
        for (dr in -1..1) {
            for (dc in -1..1) {
                if (dr == 0 && dc == 0) continue
                val rr = r + dr
                val cc = c + dc
                if (rr in 0 until b.h && cc in 0 until w) out.add(rr * w + cc)
            }
        }
        return out
    }

    private fun freshBoard(w: Int, h: Int, mines: Int, seed: Int, sr: Int, sc: Int): Board {
        val b = Board(w, h, mines, seed)
        b.startAt(sr, sc)
        return b
    }

    // ---------- 1. 24 个可达值：化简结果与可达集合互相印证 ----------

    @Test
    fun achievableValuesSimplifyToTheCanonicalForms() {
        val expected = listOf(
            "0", "1", "√2", "2", "√5", "2√2", "3", "√10", "√13",
            "4", "√17", "3√2", "2√5", "5", "√26", "√29", "4√2", "√34",
            "6", "√37", "2√10", "7", "5√2", "8",
        )
        assertEquals("24 个可达值的化简结果不对",
            expected, ACHIEVABLE.map { formatModulus(it) })

        // 反过来：每个化简结果重新平方回去，必须等于原值
        for (n in ACHIEVABLE) {
            val s = formatModulus(n)
            val parts = s.split("√")
            val outside = if (parts.size == 1) parts[0].toInt() else if (parts[0].isEmpty()) 1 else parts[0].toInt()
            val inside = if (parts.size == 1) 1 else parts[1].toInt()
            assertEquals("formatModulus($n) = \"$s\" 化不回原值", n, outside * outside * inside)
        }
    }

    // ---------- 2. 随机对局：所有不变量 ----------

    @Test
    fun randomBoardsSatisfyEveryInvariant() {
        var blankCells = 0
        var cancellingZeros = 0
        var boards = 0

        fun checkInvariants(b: Board, sr: Int, sc: Int, mines: Int) {
            // 首击九宫格必须无雷
            for (j in neighborsOf(b, b.index(sr, sc)) + b.index(sr, sc)) {
                assertTrue("首击九宫格内出现了雷", b.cells[j].mineKind < 0)
            }
            // 雷数正确
            var total = 0
            val typeTotals = IntArray(4)
            for (cell in b.cells) {
                if (cell.mineKind >= 0) {
                    total++
                    typeTotals[cell.mineKind]++
                }
            }
            assertEquals("雷数不对", mines, total)
            for (t in 0..3) {
                assertEquals("第 $t 种雷的公开总数算错了", typeTotals[t], b.typeTotal[t])
            }

            for (i in b.cells.indices) {
                val cell = b.cells[i]
                if (cell.mineKind >= 0) continue
                // 逐格独立重算 a、b，和引擎存的 clue 比对
                var a = 0
                var bb = 0
                var cnt = 0
                for (j in neighborsOf(b, i)) {
                    val k = b.cells[j].mineKind
                    if (k < 0) continue
                    a += MINE_TYPES[k].re
                    bb += MINE_TYPES[k].im
                    cnt++
                }
                assertEquals("第 $i 格显示值算错了", a * a + bb * bb, cell.clue)
                assertEquals("第 $i 格林雷数算错了", cnt, cell.nbrMines)
                // 显示值必须落在 24 个可达值里 —— 落了别的说明布雷/求和有问题
                assertTrue("第 $i 格出现了不可达的显示值 ${cell.clue}", isAchievable(cell.clue))
                if (cell.isBlank) {
                    blankCells++
                    assertEquals("空白格的显示值必须是 0", 0, cell.clue)
                } else if (cell.clue == 0) {
                    cancellingZeros++
                }
            }
        }

        // 三档难度各跑一批；种子固定，任何一次失败都能原样复现
        for (s in 1..120) {
            checkInvariants(freshBoard(9, 9, 10, s, 4, 4), 4, 4, 10); boards++
            checkInvariants(freshBoard(16, 16, 40, s * 7 + 1, 8, 8), 8, 8, 40); boards++
            checkInvariants(freshBoard(30, 16, 99, s * 13 + 5, 8, 15), 8, 15, 99); boards++
        }
        assertEquals("跑的对局数不对", 360, boards)
        assertTrue("空白格必须出现过", blankCells > 0)
        assertTrue("抵消对必须出现过 —— 它们的区别是这个游戏的核心", cancellingZeros > 0)
    }

    // ---------- 3. 连片展开：只从空白格扩散，且绕开旗子 ----------

    @Test
    fun firstRevealCascadesAcrossSafeCells() {
        val b = freshBoard(16, 16, 40, 4242, 8, 8)
        // 首击格必定是空白，应该连片展开一片
        val opened = b.cells.count { it.isOpen }
        assertTrue("首击只翻开了 $opened 格，连片展开没生效", opened >= 9)
        // 展开出来的每一格都得是安全的
        for (cell in b.cells) {
            if (!cell.isOpen) continue
            assertTrue("连片展开炸到了雷", cell.mineKind < 0)
        }
    }

    // ---------- 4. 旗子保护格子 ----------

    @Test
    fun flagsProtectCellsAndCycleBackToEmpty() {
        val b = freshBoard(9, 9, 10, 99, 4, 4)
        val target = b.cells.indexOfFirst { !it.isOpen && it.mineKind < 0 }
        assertTrue("没找到可插旗的非雷格", target >= 0)
        val r = target / b.w
        val c = target % b.w

        b.cycleFlag(r, c)
        assertEquals("插旗失败", 1, b.cells[target].flag)
        assertEquals("插了旗的格子居然被翻开了", ACT_IGNORED, b.reveal(r, c))
        assertFalse("插了旗的格子还是被翻开了", b.cells[target].isOpen)

        // 循环一圈回到空
        repeat(4) { b.cycleFlag(r, c) }
        assertEquals("旗子循环没有回到空", 0, b.cells[target].flag)
        assertEquals("清旗后计数没还原", b.typeTotal[0], b.unmarked(0))
    }

    // ---------- 5. 展开判定 ----------

    @Test
    fun expandJudgementMatchesTheReferenceRule() {
        val b = freshBoard(16, 16, 40, 777, 8, 8)
        val cell = b.cells.indexOfFirst { it.isOpen && it.mineKind < 0 && it.nbrMines > 0 }
        assertTrue("没找到可展开的数字格", cell >= 0)

        // 旗子插得不对 → 判据不过，什么都不发生
        val before = b.cells.count { it.isOpen }
        assertEquals("旗子插得不对时，展开判定居然过了",
            ACT_JUDGE_FAIL, b.tryExpand(cell / b.w, cell % b.w))
        assertEquals("判据没过却翻开了格子", before, b.cells.count { it.isOpen })

        // 把邻域的旗按真实雷型插满 → 判据必过（旗型与真值完全一致）
        for (j in neighborsOf(b, cell)) {
            val kind = b.cells[j].mineKind
            if (kind < 0) continue
            b.cycleFlag(j / b.w, j % b.w)
            repeat(kind) { b.cycleFlag(j / b.w, j % b.w) }
            assertEquals("旗型没插到目标值", kind + 1, b.cells[j].flag)
        }
        assertEquals("旗子全插对时展开应当成功", ACT_OK, b.tryExpand(cell / b.w, cell % b.w))
        val after = b.cells.count { it.isOpen }
        assertTrue("展开没有翻开任何格子", after > before)
    }

    // ---------- 6. 失败结算复盘 ----------

    @Test
    fun lossRevealMarksFlagsByPositionOnly() {
        val b = freshBoard(9, 9, 10, 2024, 4, 4)
        // 插两面旗：一面插在雷上，一面插在非雷上
        val rightIdx = b.cells.indexOfFirst { it.mineKind >= 0 && !it.isOpen }
        val wrongIdx = b.cells.indexOfFirst { it.mineKind < 0 && !it.isOpen }
        assertTrue(rightIdx >= 0 && wrongIdx >= 0)
        // 故意插成和真雷型对不上的那一种：结算只看位置，插在雷上就该算标对
        b.cycleFlag(rightIdx / b.w, rightIdx % b.w)
        if (b.cells[rightIdx].flag == b.cells[rightIdx].mineKind + 1) {
            b.cycleFlag(rightIdx / b.w, rightIdx % b.w)
        }
        b.cycleFlag(wrongIdx / b.w, wrongIdx % b.w)

        // 手动触发失败结算：翻一颗没插旗的雷
        // （插了旗的雷翻不开，那是旗子在保护格子，这里不能拿它当引信）
        val mineIdx = b.cells.indexOfFirst { it.mineKind >= 0 && !it.isOpen && it.flag == 0 }
        assertTrue("没找到没插旗的雷", mineIdx >= 0)
        assertEquals("翻到雷没有返回 ACT_BOOM", ACT_BOOM, b.reveal(mineIdx / b.w, mineIdx % b.w))
        assertTrue("踩雷后应当判负", b.isOver() && !b.isWon())

        assertEquals("插在雷上的旗没有标成 MARK_RIGHT_FLAG",
            MARK_RIGHT_FLAG, b.cells[rightIdx].endMark)
        assertEquals("插在非雷上的旗没有标成 MARK_WRONG_BLANK",
            MARK_WRONG_BLANK, b.cells[wrongIdx].endMark)
        assertEquals("踩中的那颗不该有复盘标记", MARK_NONE, b.cells[mineIdx].endMark)
        assertTrue("踩中的那颗没标 exploded", b.cells[mineIdx].exploded)

        // 没插旗的雷一律亮出来
        var shown = 0
        for (cell in b.cells) {
            if (cell.mineKind < 0 || cell.flag != 0 || cell.isOpen) continue
            assertEquals("失败结算时没插旗的雷没有亮出来", MARK_MINE, cell.endMark)
            shown++
        }
        assertTrue("这一局应该还有没插旗的雷", shown > 0)
    }

    // ---------- 7. 通关复盘 ----------

    @Test
    fun winByExpandingMarksEveryFlagCorrect() {
        val b = freshBoard(9, 9, 10, 31337, 4, 4)
        // 把邻域旗子按真实雷型插满，用展开判定一路推到通关
        var round = 0
        while (round < 200 && !b.isOver()) {
            var moved = false
            for (i in b.cells.indices) {
                if (b.isOver()) break
                if (!b.cells[i].isOpen || b.cells[i].mineKind >= 0) continue
                for (j in neighborsOf(b, i)) {
                    if (b.cells[j].isOpen || b.cells[j].mineKind < 0) continue
                    var guard = 0
                    while (b.cells[j].flag != b.cells[j].mineKind + 1 && guard < 8) {
                        b.cycleFlag(j / b.w, j % b.w)
                        guard++
                    }
                }
                if (b.tryExpand(i / b.w, i % b.w) == ACT_OK) moved = true
            }
            if (!moved) break
            round++
        }
        assertTrue("按真实雷型插满旗后一路展开，应该能通关", b.isWon())
        // 通关时所有非雷格都翻开了，留在场上的旗必然都在雷上
        for (cell in b.cells) {
            if (cell.flag == 0) continue
            assertTrue("通关时还有旗插在非雷格上", cell.mineKind >= 0)
            assertEquals("通关时插对的旗没标成 MARK_RIGHT_FLAG", MARK_RIGHT_FLAG, cell.endMark)
        }
    }

    // ---------- 8. 通关时没插旗的雷也亮出来 ----------

    @Test
    fun winRevealsUnflaggedMines() {
        val b = freshBoard(9, 9, 10, 606, 4, 4)
        // 只插一面旗，而且故意插成和真雷型对不上的那种，其余雷都不插
        val flagged = b.cells.indexOfFirst { it.mineKind >= 0 }
        assertTrue(flagged >= 0)
        b.cycleFlag(flagged / b.w, flagged % b.w)
        if (b.cells[flagged].flag == b.cells[flagged].mineKind + 1) {
            b.cycleFlag(flagged / b.w, flagged % b.w)
        }
        // 直接翻开所有非雷格 → 通关
        for (i in b.cells.indices) {
            if (b.isOver()) break
            if (b.cells[i].mineKind < 0 && !b.cells[i].isOpen) {
                b.reveal(i / b.w, i % b.w)
            }
        }
        assertTrue("翻开所有非雷格后应当通关", b.isWon())
        assertEquals("通关时插在雷上的旗没有标成 MARK_RIGHT_FLAG",
            MARK_RIGHT_FLAG, b.cells[flagged].endMark)
        var shown = 0
        for (cell in b.cells) {
            if (cell.mineKind < 0 || cell.flag != 0) continue
            assertEquals("通关时没插旗的雷没有亮出来", MARK_MINE, cell.endMark)
            shown++
        }
        assertTrue("这一局应该还有没插旗的雷", shown > 0)
    }

    // ---------- 9. 与 HarmonyOS / Apple 版逐位对齐 ----------

    /**
     * 下面这六个指纹是从 HarmonyOS 版的引擎（ArkTS）跑出来的：同一批固定种子、
     * 同一个首击格，把每格的雷型/显示值/邻雷数/翻开状态、四个计雷器和胜负状态
     * 拼成一个字符串再做 FNV-1a。三个平台必须得到同一串值 —— 说明 mulberry32、
     * 洗位置、求和、连片展开全都逐位一致，而不只是「看起来都对」。
     */
    @Test
    fun boardFingerprintsMatchHarmonyOSAndAppleBitForBit() {
        val cases = listOf(
            listOf(9, 9, 10, 1, 4, 4) to "e89c77c9",
            listOf(16, 16, 40, 8, 8, 8) to "d9ca35a9",
            listOf(30, 16, 99, 5, 8, 15) to "04680c3c",
            listOf(9, 9, 10, 2024, 0, 0) to "b5649eeb",
            listOf(16, 16, 40, 31337, 15, 15) to "5c1eb7a8",
            listOf(30, 16, 99, 123456, 0, 29) to "d7ac09af",
        )
        for ((args, expected) in cases) {
            val got = fingerprint(args[0], args[1], args[2], args[3], args[4], args[5])
            assertEquals("${args[0]}×${args[1]}/${args[2]} seed=${args[3]} @${args[4]},${args[5]}"
                + " 的棋盘指纹与 HarmonyOS 版不一致", expected, got)
        }
    }

    private fun fingerprint(w: Int, h: Int, mines: Int, seed: Int, sr: Int, sc: Int): String {
        val b = Board(w, h, mines, seed)
        b.startAt(sr, sc)
        val parts = ArrayList<String>()
        for (c in b.cells) {
            parts.add("${c.mineKind + 1},${c.clue},${c.nbrMines},${if (c.isOpen) 1 else 0}")
        }
        for (t in 0..3) {
            parts.add("T${b.typeTotal[t]},${b.unmarked(t)}")
        }
        parts.add("over${b.isOver()}won${b.isWon()}")
        return fnv(parts.joinToString(";"))
    }

    /** 与 JS / Swift 两侧一致的 FNV-1a 32 位 */
    private fun fnv(s: String): String {
        var h = 0x811c9dc5.toInt()
        for (ch in s) {
            h = h xor ch.code
            h *= 0x01000193
        }
        return (h.toLong() and 0xFFFFFFFFL).toString(16).padStart(8, '0')
    }

    @Test
    fun firstRevealHonorsFlagsAndStartsOnlyOnce() {
        val b = Board(9, 9, 10, 1)
        b.cycleFlag(4, 4)
        b.startAt(4, 4)
        assertFalse(b.isStarted())
        assertEquals(ACT_IGNORED, b.reveal(4, 4))
        assertFalse(b.isStarted())
        repeat(4) { b.cycleFlag(4, 4) }
        assertEquals(ACT_OK, b.reveal(4, 4))
        assertTrue(b.isStarted())
        assertEquals(10, b.mineTotal())
        assertTrue(b.cellAt(4, 4).isOpen)
        val snapshot = b.cells.map { "${it.mineKind},${it.clue},${it.isOpen}" }
        b.startAt(0, 0)
        assertEquals(snapshot, b.cells.map { "${it.mineKind},${it.clue},${it.isOpen}" })
    }

    @Test
    fun outOfBoundsActionsAreIgnored() {
        val b = Board(9, 9, 10, 1)
        for ((r, c) in listOf(-1 to 0, 0 to -1, 9 to 0, 0 to 9)) {
            assertEquals(ACT_IGNORED, b.reveal(r, c))
            assertEquals(ACT_IGNORED, b.tryExpand(r, c))
            assertFalse(b.cycleFlag(r, c))
            b.startAt(r, c)
        }
        assertFalse(b.isStarted())
        assertEquals(0, b.flagsTotal())
    }

    @Test
    fun firstRevealCanWinAndFreezeTheBoard() {
        val b = Board(3, 3, 0, 1)
        assertEquals(ACT_OK, b.reveal(1, 1))
        assertTrue(b.isWon())
        assertTrue(b.cells.all { it.isOpen })
        assertFalse(b.cycleFlag(0, 0))
        assertEquals(ACT_IGNORED, b.reveal(0, 0))
    }

    // ---------- 10. 三档难度 ----------

    @Test
    fun everyDifficultyPlacesExactlyTheRequestedMineCount() {
        for (d in DIFFICULTIES) {
            val b = Board(d.w, d.h, d.mines, 5)
            b.startAt(d.h / 2, d.w / 2)
            assertEquals("${d.label} 的雷数不对", d.mines, b.cells.count { it.mineKind >= 0 })
        }
    }
}
