package top.rayawa.dashboard.complexsweeper.android.ui

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import top.rayawa.dashboard.complexsweeper.android.engine.Cell

/**
 * 棋盘：经典凹陷面板包住网格。
 *
 * 网格用 Column 套 Row 逐格摆，不用 LazyVerticalGrid —— 列数是固定的，而
 * Lazy 网格的列宽算法会把除不尽的余数摊到列距上，像素贴图之间就会出现
 * 半像素的缝。固定列数的 Row 没有这个自由度，一定对齐。
 *
 * 网格比可视区宽时（高级 30 列在手机上）横向滚动；比可视区矮时竖向滚动。
 * 装得下就撑满可视区、把网格居中 —— 居中交给容器的对齐，不用 padding 硬顶。
 */
@Composable
fun BoardPanel(game: GameController, modifier: Modifier = Modifier) {
    BoxWithConstraints(
        modifier = modifier
            .fillMaxWidth()
            .testTag("board")
            // 这一层的内缩只有 3dp 立体边，所以里面量到的就是真正能摆格子的区域
            .classicBevel(raised = false, thickness = 3.dp, inset = 3.dp)
    ) {
        // 列数、行数、格子数组必须**来自同一份棋盘**，所以在这里一次性取出来做成快照，
        // 一起交给下面的网格。
        //
        // 别在网格里现读 game.board：Compose 的重组是按 scope 走的，网格那个 scope
        // 自己读了 game.board，就会被**单独**置为待重组 —— 它可能在父 scope 之前跑，
        // 那时用的是上一局留下的 cols，而 board 已经是新的了。高级 30 列切回初级 9 列
        // 那一下就变成 r * 30 + c 去索引一个 81 格的数组，IndexOutOfBoundsException 闪退。
        // 传快照之后网格不再依赖 game.board，列数和数组永远出自同一局。
        val board = game.board
        val cols = board.w
        val rows = board.h
        val cells = board.cells
        val viewportWidth = maxWidth
        val viewportHeight = maxHeight
        val edge = ClassicLayout.edge(
            cols = cols,
            rows = rows,
            innerWidth = viewportWidth.value,
            innerHeight = viewportHeight.value,
        ).dp

        key(game.gameId) {
            val hScroll = rememberScrollState()
            val vScroll = rememberScrollState()

            Box(
                Modifier
                    .fillMaxSize()
                    .horizontalScroll(hScroll)
                    .verticalScroll(vScroll)
            ) {
                Box(
                    Modifier.sizeIn(minWidth = viewportWidth, minHeight = viewportHeight),
                    contentAlignment = Alignment.Center,
                ) {
                    // 开新局时整块网格重建，别让 Compose 把上一局的格子复用过来
                    BoardGrid(game, cells, cols, rows, edge)
                }
            }
        }
    }
}

/**
 * 一块网格。
 *
 * `cells` 与 `cols` / `rows` 是同一次取出来的快照，三者一定自洽，索引不可能越界。
 * 这里刻意不再碰 `game.board`。
 */
@Composable
private fun BoardGrid(
    game: GameController,
    cells: List<Cell>,
    cols: Int,
    rows: Int,
    edge: Dp,
) {
    Column {
        for (r in 0 until rows) {
            Row {
                for (c in 0 until cols) {
                    CellView(game, cells[r * cols + c], edge)
                }
            }
        }
    }
}
