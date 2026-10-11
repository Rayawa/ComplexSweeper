package top.rayawa.dashboard.complexsweeper.android.ui

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import top.rayawa.dashboard.complexsweeper.android.model.TYPE_LABELS
import top.rayawa.dashboard.complexsweeper.android.model.formatModulus
import androidx.compose.ui.unit.Dp
import top.rayawa.dashboard.complexsweeper.android.engine.Cell
import top.rayawa.dashboard.complexsweeper.android.engine.MARK_MINE
import top.rayawa.dashboard.complexsweeper.android.engine.MARK_RIGHT_FLAG
import top.rayawa.dashboard.complexsweeper.android.engine.MARK_WRONG_BLANK

/**
 * 一格。
 *
 * 整格就是一张 16×16 的像素贴图 —— 立体边、数字、旗子、雷全画在图里了，
 * 所以这里不需要任何边框或文字，只要挑对图。选图逻辑照搬复扫雷参考实现的
 * cellSprite()，那条优先级顺序（已翻开 > 结算标记 > 旗子 > 未翻开）不能动。
 *
 * 手势和 HarmonyOS 版一致：轻点标记、长按 400ms 翻开。
 * detectTapGestures 里 onLongPress 与 onTap 天然互斥 ——
 * 长按成立之后它会一直消费到抬手再返回，不会再走 onTap。
 */
@Composable
fun CellView(game: GameController, cell: Cell, edge: Dp) {
    val systemConfiguration = LocalViewConfiguration.current
    val configuration = remember(systemConfiguration) {
        object : ViewConfiguration by systemConfiguration {
            override val longPressTimeoutMillis: Long = 400L
        }
    }
    CompositionLocalProvider(LocalViewConfiguration provides configuration) {
        PixelImage(
            id = cellSprite(cell),
            width = edge,
            height = edge,
            modifier = Modifier
                .testTag("cell-${cell.row}-${cell.col}")
                .semantics {
                    contentDescription = "第 ${cell.row + 1} 行，第 ${cell.col + 1} 列"
                    stateDescription = cellDescription(cell)
                }
                .pointerInput(cell) {
                    detectTapGestures(
                        onPress = {
                            game.setPress(cell.isOpen)
                            // try/finally：手势被取消时（手指划走变成滚动、或者长按成立之后
                            // Compose 直接消费到抬手）也要把脸收回来，不然会一直停在按下态
                            try {
                                tryAwaitRelease()
                            } finally {
                                game.clearPress()
                            }
                        },
                        onLongPress = { game.reveal(cell.row, cell.col) },
                        onTap = { game.tap(cell.row, cell.col) },
                    )
                },
        )
    }
}

/**
 * 这一格现在该画哪张图。
 *
 * 读的都是 Cell 上的 Compose 状态，所以哪几个字段变了就只重画这一格。
 */
private fun cellSprite(cell: Cell): Int {
    if (cell.isOpen) {
        if (cell.mineKind >= 0) {
            // 踩中的那颗底色是红的，其余的雷只是亮出来
            val kind = cell.mineKind + 1
            return if (cell.exploded) Sprites.boom(kind) else Sprites.mine(kind)
        }
        // 空白格（邻域一颗雷都没有）和显示 0（周围全是抵消对）是两回事，
        // 贴图也不同：前者是没字的平板，后者画着 "0"。
        if (cell.isBlank) {
            return Sprites.BLANK
        }
        return if (Sprites.hasNum(cell.clue)) Sprites.num(cell.clue) else Sprites.BLANK
    }

    when (cell.endMark) {
        MARK_WRONG_BLANK -> return Sprites.WRONG_BLANK
        // 按玩家自己插的那型出图：结算只看位置，不评判雷型对不对得上
        MARK_RIGHT_FLAG -> return Sprites.rightFlag(cell.flag)
        MARK_MINE -> return Sprites.mine(cell.mineKind + 1)
    }
    if (cell.flag > 0) {
        return Sprites.flag(cell.flag)
    }
    return Sprites.CLOSED
}

private fun cellDescription(cell: Cell): String {
    if (cell.isOpen) {
        if (cell.isMine) return if (cell.exploded) "踩中的雷" else "雷"
        return if (cell.isBlank) "空白" else "数字 ${formatModulus(cell.clue)}"
    }
    return when (cell.endMark) {
        MARK_WRONG_BLANK -> "标错的位置"
        MARK_RIGHT_FLAG -> "标对的位置"
        MARK_MINE -> "雷"
        else -> if (cell.flag > 0) "旗帜 ${TYPE_LABELS[cell.flag - 1]}" else "未翻开"
    }
}
