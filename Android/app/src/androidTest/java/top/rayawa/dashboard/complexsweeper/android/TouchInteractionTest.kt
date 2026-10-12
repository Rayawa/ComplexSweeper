package top.rayawa.dashboard.complexsweeper.android

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.click
import androidx.compose.ui.test.swipeLeft
import androidx.lifecycle.ViewModelProvider
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import top.rayawa.dashboard.complexsweeper.android.ui.GameController
import top.rayawa.dashboard.complexsweeper.android.ui.GameState
import top.rayawa.dashboard.complexsweeper.android.ui.PRESS_NONE

/** 真触摸回归；需要连接 Android 12+ 真机或模拟器。 */
class TouchInteractionTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private val game: GameController
        get() = ViewModelProvider(compose.activity)[GameController::class.java]

    private fun hold(row: Int, col: Int) {
        compose.onNodeWithTag("cell-$row-$col").performTouchInput {
            down(center)
            advanceEventTime(450)
            up()
        }
    }

    @Test fun flagsProtectFirstRevealAndNextTapStillWorks() {
        val target = compose.onNodeWithTag("cell-0-0")
        target.performTouchInput { click() }
        hold(0, 0)
        compose.runOnIdle {
            assertFalse(game.board.isStarted())
            assertEquals(GameState.READY, game.gameState)
            assertEquals(PRESS_NONE, game.pressMode)
        }
        for (value in listOf("旗帜 -1", "旗帜 +i", "旗帜 -i", "未翻开")) {
            target.performTouchInput { click() }
            target.assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, value))
        }
        hold(0, 0)
        compose.runOnIdle { assertTrue(game.board.isStarted()) }
    }

    @Test fun flagCountersUpdateImmediately() {
        hold(4, 4)
        var row = 0
        var col = 0
        var count = 0
        compose.runOnIdle {
            val cell = game.board.cells.first { !it.isOpen }
            row = cell.row
            col = cell.col
            count = game.board.unmarked(0)
        }
        compose.onNodeWithTag("cell-$row-$col").performTouchInput { click() }
        compose.onNodeWithTag("counter-0").assert(
            SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, (count - 1).toString())
        )
    }

    @Test fun rotationKeepsTheBoardAndFlags() {
        compose.onNodeWithTag("cell-0-0").performTouchInput { click() }
        lateinit var original: GameController
        compose.runOnIdle { original = game }
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.runOnIdle {
            assertSame(original, game)
            assertEquals(1, game.board.cellAt(0, 0).flag)
        }
    }

    @Test fun advancedBoardScrollDoesNotStartTheGame() {
        compose.onNodeWithText("高级").performTouchInput { click() }
        compose.onNodeWithTag("board").performTouchInput { swipeLeft() }
        compose.runOnIdle {
            assertFalse(game.board.isStarted())
            assertEquals(0, game.board.flagsTotal())
            assertEquals(PRESS_NONE, game.pressMode)
        }
        for (label in listOf("初级", "中级", "高级", "初级")) {
            compose.onNodeWithText(label).performTouchInput { click() }
            compose.waitForIdle()
        }
        compose.runOnIdle { assertEquals(81, game.board.cells.size) }
    }

    @Test fun modeTabsKeepDifficultyAndRepeatedSelectionsKeepBoard() {
        compose.onNodeWithTag("difficulty-1").performTouchInput { click() }
        compose.onNodeWithTag("mode-1").performTouchInput { click() }
        lateinit var original: top.rayawa.dashboard.complexsweeper.android.engine.Board
        compose.runOnIdle {
            original=game.board
            assertEquals(16,original.w)
            assertEquals(top.rayawa.dashboard.complexsweeper.android.model.GameMode.HYPER,original.mode)
        }
        repeat(3) {compose.onNodeWithTag("cell-0-0").performTouchInput { click() }}
        compose.onNodeWithTag("mode-1").performTouchInput { click() }
        compose.onNodeWithTag("difficulty-1").performTouchInput { click() }
        compose.runOnIdle {assertSame(original,game.board);assertEquals(3,game.board.cellAt(0,0).flag)}
        compose.onNodeWithTag("mode-0").performTouchInput { click() }
        compose.runOnIdle {
            assertEquals(16,game.board.w);assertEquals(0,game.board.flagsTotal())
            assertFalse(game.board.isStarted())
        }
    }
}
