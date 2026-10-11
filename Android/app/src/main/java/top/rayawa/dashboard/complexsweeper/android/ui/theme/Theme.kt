package top.rayawa.dashboard.complexsweeper.android.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * 经典扫雷只有银灰一套配色，本应用不做深色适配，也不用动态取色。
 *
 * 面板、立体边、数码管的颜色全部由 `ui/Classic` 直接给，这里的色板只影响
 * Material 组件（「关于」用的底部弹层）的默认取色 —— 所以底、面都刷成银灰，
 * 免得弹层里冒出一块 Material 紫。
 */
private val ClassicColorScheme = lightColorScheme(
    primary = Color(0xFF000000),
    onPrimary = Color(0xFFFFFFFF),
    secondary = Color(0xFF808080),
    onSecondary = Color(0xFFFFFFFF),
    background = Color(0xFFC0C0C0),
    onBackground = Color(0xFF000000),
    surface = Color(0xFFC0C0C0),
    onSurface = Color(0xFF000000),
    surfaceVariant = Color(0xFFC0C0C0),
    onSurfaceVariant = Color(0xFF000000),
    surfaceContainerLowest = Color(0xFFC0C0C0),
    surfaceContainerLow = Color(0xFFC0C0C0),
    surfaceContainer = Color(0xFFC0C0C0),
    surfaceContainerHigh = Color(0xFFC0C0C0),
    surfaceContainerHighest = Color(0xFFC0C0C0),
)

@Composable
fun ComplexSweeperAndroidTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = ClassicColorScheme,
        typography = Typography,
        content = content,
    )
}
