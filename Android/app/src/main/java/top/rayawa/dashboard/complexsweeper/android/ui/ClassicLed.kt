package top.rayawa.dashboard.complexsweeper.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** 数码管里的特殊格子 */
private const val CELL_BLANK = 12
private const val CELL_MINUS = 10
private const val CELL_UNIT_I = 11

/**
 * 一排数码管。
 *
 * 复扫雷的计雷器是「这一类雷还剩几颗没标」，虚雷那一档最后一格是 i 单位而不是数字，
 * 所以这里要能按需留出单位格。数字一律右对齐、前导零不亮。
 */
@Composable
fun LedReadout(
    value: Int,
    slots: Int = 4,
    imagUnit: Boolean = false,
    hyperUnit: Boolean = false,
    cellWidth: Dp = 13.dp,
    blankAll: Boolean = false,
) {
    val codes = remember(value, slots, imagUnit, hyperUnit, blankAll) {
        ledCodes(value, slots, imagUnit, blankAll).map { if (hyperUnit && it == CELL_UNIT_I) 13 else it }
    }
    val cellHeight = cellWidth * 23f / 13f
    Row(
        Modifier
            .background(Classic.LedBackground)
            .padding(2.dp)
    ) {
        for (code in codes) {
            PixelImage(Sprites.led(code), cellWidth, cellHeight)
        }
    }
}

/** 算出每一格该显示什么：0..9 数字、10 负号、11 i 单位、12 空格 */
internal fun ledCodes(value: Int, slots: Int, imagUnit: Boolean, blankAll: Boolean): List<Int> {
    val out = MutableList(slots) { CELL_BLANK }
    if (blankAll || slots <= 0) {
        return out
    }
    val digitSlots = if (imagUnit) slots - 1 else slots
    val negative = value < 0
    var rest = kotlin.math.abs(value)

    var pos = digitSlots - 1
    while (pos >= 0) {
        out[pos] = rest % 10
        rest /= 10
        if (rest == 0) break
        pos--
    }
    // 负号紧挨在最高位数字左边；位数占满了就只好不画负号
    if (negative && pos - 1 >= 0) {
        out[pos - 1] = CELL_MINUS
    }
    if (imagUnit) {
        out[slots - 1] = CELL_UNIT_I
    }
    return out
}
