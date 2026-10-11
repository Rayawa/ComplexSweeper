package top.rayawa.dashboard.complexsweeper.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import top.rayawa.dashboard.complexsweeper.android.ui.GameController
import top.rayawa.dashboard.complexsweeper.android.ui.GameScreen
import top.rayawa.dashboard.complexsweeper.android.ui.theme.ComplexSweeperAndroidTheme

/**
 * 单 Activity。
 *
 * enableEdgeToEdge 之后内容会铺到状态栏和手势条底下，让经典扫雷的银灰面板
 * 通到屏幕边缘；页面自己用 windowInsetsPadding 把内容让开系统栏。
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val game = ViewModelProvider(this, object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T =
                GameController(applicationContext) as T
        })[GameController::class.java]
        setContent {
            ComplexSweeperAndroidTheme {
                GameScreen(game)
            }
        }
    }
}
