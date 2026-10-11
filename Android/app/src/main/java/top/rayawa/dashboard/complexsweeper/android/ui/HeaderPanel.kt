package top.rayawa.dashboard.complexsweeper.android.ui

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import top.rayawa.dashboard.complexsweeper.android.model.TYPE_LABELS
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * 一个计雷器：这一型雷的图标 + 四格数码管。
 *
 * 这一类雷还剩几颗没标。负数类型（-1、-i）显示成负数，每插一颗就朝零走。
 */
@Composable
private fun CounterRow(game: GameController, type: Int, ledCell: Dp, iconSize: Dp) {
    Row(
        modifier = Modifier.padding(horizontal = 2.dp)
            .testTag("counter-$type")
            .semantics(mergeDescendants = true) {
                contentDescription = "${TYPE_LABELS[type]} 剩余雷数"
                stateDescription = if (game.board.isStarted()) counterValue(game, type).toString() else "开局后公布"
            },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PixelImage(Sprites.flag(type + 1), iconSize, iconSize)
        LedReadout(
            value = counterValue(game, type),
            slots = 4,
            imagUnit = type >= 2,
            cellWidth = ledCell,
            blankAll = !game.board.isStarted(),
        )
    }
}

private fun counterValue(game: GameController, type: Int): Int {
    val k = game.board.unmarked(type)
    return if (type == 1 || type == 3) -k else k
}

/**
 * 人脸按钮。
 *
 * 单独一个 composable：只有它读按下状态，于是手指按上按下的瞬间，重组的只有
 * 这张脸，480 个格子一动不动。
 */
@Composable
private fun FaceButton(game: GameController) {
    PixelImage(
        id = Sprites.face(faceKind(game)),
        width = ClassicLayout.FACE_SIZE.dp,
        height = ClassicLayout.FACE_SIZE.dp,
        modifier = Modifier.testTag("restart")
            .semantics { contentDescription = "重新开始" }
            .pointerInput(Unit) {
            detectTapGestures { game.newGame(game.difficultyIndex) }
        },
    )
}

private fun faceKind(game: GameController): Int = when (game.gameState) {
    GameState.WON -> FACE_WIN
    GameState.LOST -> FACE_DEAD
    GameState.READY, GameState.PLAYING -> when (game.pressMode) {
        PRESS_OPEN -> FACE_SCAN
        PRESS_HIDDEN -> FACE_DOWN
        else -> FACE_NORMAL
    }
}

/** 计时数码管。同样单独出来：秒数每秒都在走，不该带着四个计雷器一起重组。 */
@Composable
private fun TimerReadout(game: GameController, cellWidth: Dp) {
    LedReadout(value = game.elapsed, slots = 4, cellWidth = cellWidth)
}

/**
 * 经典表头：左边四个计雷器竖排，中间人脸 + 计时。
 *
 * 三段等分（各占满一份宽度）：右边空出和计雷器列一样宽的一块，人脸那列才落在
 * 面板正中。原来只在两侧各放一个 Spacer 的话，人脸会被计雷器挤到偏右，
 * 屏幕越宽偏得越多。
 */
@Composable
fun HeaderPanel(game: GameController, pageHeight: Float) {
    val ledCell = ClassicLayout.ledCellWidth(pageHeight).dp
    val iconSize = ClassicLayout.ledIcon(ClassicLayout.ledCellWidth(pageHeight)).dp
    Row(
        modifier = Modifier
            .fillMaxWidth()
            // 3dp 立体边 + 6dp 内边距，和 HarmonyOS 版的 padding(6) + border(3) 一致
            .classicBevel(raised = false, thickness = 3.dp, inset = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            horizontalAlignment = Alignment.Start,
        ) {
            for (t in 0..3) {
                CounterRow(game, t, ledCell, iconSize)
            }
        }

        Column(
            modifier = Modifier.weight(1f),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            FaceButton(game)
            TimerReadout(game, ledCell)
        }

        Spacer(Modifier.weight(1f))
    }
}

/** 状态行：一句操作提示，或者结算结果。 */
@Composable
fun StatusLine(game: GameController) {
    Text(
        text = game.statusText,
        fontSize = 12.sp,
        color = Classic.Dark,
        textAlign = TextAlign.Center,
        maxLines = 2,
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 6.dp, bottom = 2.dp, start = 8.dp, end = 8.dp),
    )
}
