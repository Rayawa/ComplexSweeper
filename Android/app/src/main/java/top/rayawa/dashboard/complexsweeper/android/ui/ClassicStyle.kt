package top.rayawa.dashboard.complexsweeper.android.ui

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import kotlin.math.floor

/**
 * 经典扫雷的配色。
 *
 * 上游素材只有银灰一套配色，本应用不做深色适配：面板恒为 #C0C0C0，
 * 立体边靠一白一灰两道，和原作 Win32 版一致。
 */
object Classic {
    val Face = Color(0xFFC0C0C0)
    val Light = Color(0xFFFFFFFF)
    val Shadow = Color(0xFF808080)
    val Dark = Color(0xFF000000)
    val LedBackground = Color(0xFF000000)
}

/**
 * 给一块面板套上经典立体边。
 *
 * 链式顺序很要紧：底色 → 画边 → 内缩内容。`drawWithContent` 画的是自己的节点
 * 边界，所以它必须在 `padding` 外面，边才落在面板最外圈；`background` 再往外一层，
 * 才能把边框和内缩之间那圈底色也填上。
 *
 * 四道等宽色条拼出来：凸面板左上白、右下灰；凹面板（表头和棋盘）反过来。
 */
fun Modifier.classicBevel(
    raised: Boolean,
    thickness: Dp = 3.dp,
    inset: Dp = 3.dp,
): Modifier = this
    .background(Classic.Face)
    .drawWithContent {
        drawContent()
        val t = thickness.toPx()
        val w = size.width
        val h = size.height
        val near = if (raised) Classic.Light else Classic.Shadow
        val far = if (raised) Classic.Shadow else Classic.Light
        drawRect(near, topLeft = Offset.Zero, size = Size(w, t))
        drawRect(far, topLeft = Offset(0f, h - t), size = Size(w, t))
        drawRect(near, topLeft = Offset.Zero, size = Size(t, h))
        drawRect(far, topLeft = Offset(w - t, 0f), size = Size(t, h))
    }
    .padding(inset)

/**
 * 像素贴图画笔缓存。
 *
 * 两个理由必须有它：
 *   - 一张贴图在整块棋盘上最多出现几十次，不能每格都解码一遍 PNG；
 *   - `BitmapPainter` 的 filterQuality 是唯一能真正关掉插值的地方 ——
 *     Compose 1.10 的 `Image(painter = …)` 上没有这个参数，只有
 *     `Image(bitmap = …)` 才有，而那条重载没有缓存。
 */
private val pixelPainterCache = HashMap<Int, BitmapPainter>()

@Composable
private fun pixelPainter(@DrawableRes id: Int): BitmapPainter {
    // 把 resources 也放进 remember 的 key：配置一变（旋转、字号、语言）resources
    // 会换一个，缓存得跟着失效，别拿旧配置解出来的位图。
    val resources = LocalContext.current.resources
    return remember(id, resources) {
        pixelPainterCache.getOrPut(id) {
            // 解不出来就退化成一张 1×1 透明图：贴图有问题顶多那一格是空的，
            // 不该把整个应用带走。
            val bitmap = runCatching { BitmapFactory.decodeResource(resources, id) }
                .getOrNull()
                ?: Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
            BitmapPainter(bitmap.asImageBitmap(), filterQuality = FilterQuality.None)
        }
    }
}

/**
 * 一张像素贴图。
 *
 * 放大一律最近邻：像素画一插值就糊成一团。
 * 贴图放在 drawable-nodpi 里，本来就是「一个像素 = 一个 dp」，
 * 再交给这里按整数倍缩放。
 */
@Composable
fun PixelImage(@DrawableRes id: Int, width: Dp, height: Dp, modifier: Modifier = Modifier) {
    Image(
        painter = pixelPainter(id),
        contentDescription = null,
        contentScale = ContentScale.FillBounds,
        modifier = modifier.size(width, height),
    )
}

/**
 * 版面尺寸的算法，全部收在这里。单位一律是 dp 的数值（不带 .dp），
 * 这样排版函数保持纯计算，好读也好测。
 */
object ClassicLayout {
    /** 贴图原始尺寸，格子不能再小 —— 像素画缩着画会糊 */
    const val MIN_EDGE = 16f
    const val MAX_EDGE = 36f

    /** 人脸按钮的边长（贴图 24×24） */
    const val FACE_SIZE = 46f

    /**
     * 数码管单格宽度。表头的高度就是它撑起来的：一行读数高 23/13×单格再加 4 内边距，
     * 四个计雷器竖排，最后加上表头的 6 内边距与 3 立体边：
     *
     *     表头高度 ≈ HEADER_PER_LED × 单格 + HEADER_BASE
     *
     * 表头一高，棋盘区就矮，所以这个数是「数字够大」和「别抢棋盘地方」的折中。
     */
    const val LED_CELL = 18f
    const val LED_MIN_CELL = 13f
    const val HEADER_PER_LED = 4f * 23f / 13f
    const val HEADER_BASE = 28f

    /** 表头最多占窗口高度的四分之一。矮窗（横屏、分屏、自由窗口）按这个反推数码管能画多大。 */
    const val HEADER_HEIGHT_SHARE = 0.25f

    /**
     * 格子边长：宽度和高度都要放得下，再夹在 [16, 36]。
     *
     * innerWidth / innerHeight 是棋盘面板内缩之后真正能摆格子的区域。
     * 只看宽度的话，横屏、分屏这类矮窗会把整块棋盘挤进滚动区、一屏只看得到半张；
     * 所以高度也一起算 —— 一屏能看全比格子大更实用。
     * 高级 30 列在手机上按宽度算还不到 16，于是棋盘横向滚动。
     */
    fun edge(cols: Int, rows: Int, innerWidth: Float, innerHeight: Float): Float {
        val byWidth = floor(innerWidth / maxOf(cols, 1))
        val byHeight = if (innerHeight > 0f) floor(innerHeight / maxOf(rows, 1)) else MAX_EDGE
        return minOf(byWidth, byHeight).coerceIn(MIN_EDGE, MAX_EDGE)
    }

    /**
     * 数码管单格宽度：标准值就是 LED_CELL，矮窗按「表头不超过窗口四分之一」往回收，
     * 收到贴图原宽为止。竖屏手机上算下来就是 LED_CELL。
     */
    fun ledCellWidth(pageHeight: Float): Float {
        if (pageHeight <= 0f) return LED_CELL
        val cap = floor((pageHeight * HEADER_HEIGHT_SHARE - HEADER_BASE) / HEADER_PER_LED)
        return cap.coerceIn(LED_MIN_CELL, LED_CELL)
    }

    /** 计雷器上那面小旗的边长，按 16/13 跟着数码管等比走（贴图 16×16、数码管 13×23） */
    fun ledIcon(cellWidth: Float): Float = Math.round(cellWidth * 16f / 13f).toFloat()
}
