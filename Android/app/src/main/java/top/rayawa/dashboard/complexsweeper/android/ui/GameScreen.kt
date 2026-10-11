package top.rayawa.dashboard.complexsweeper.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.systemBars
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.BoxWithConstraints
import kotlinx.coroutines.delay
import top.rayawa.dashboard.complexsweeper.android.model.DIFFICULTIES

/**
 * 游戏主页。
 *
 * 这个 composable 自己不读任何会频繁变的状态 —— 它只拿到一个稳定的 controller，
 * 把版面搭出来。谁需要哪部分数据就让哪个子 composable 自己去读：计时走字只重组
 * 数码管，插旗只重组计雷器和那一格，480 格的网格纹丝不动。
 */
@Composable
fun GameScreen(game: GameController) {
    var showTutorial by remember { mutableStateOf(false) }
    val lifecycleOwner = LocalLifecycleOwner.current

    // 计时：每 250ms 唤醒一次，用开始时刻反推已用时间
    LaunchedEffect(game.gameId, game.gameState, lifecycleOwner) {
        if (game.gameState == GameState.PLAYING) {
            lifecycleOwner.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
                while (true) {
                    game.tick()
                    delay(250)
                }
            }
        }
    }
    // 展开判定没过的提示，过一会儿自动消失
    LaunchedEffect(game.hintToken) {
        if (game.hintToken > 0) {
            delay(1600)
            game.clearHint()
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize().background(Classic.Face)) {
        // 量到的是整个窗口的高度，表头按它决定数码管能有多大
        val pageHeight = maxHeight.value
        Column(
            Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars)
        ) {
            TopBar(onAbout = { showTutorial = true })
            HeaderPanel(game, pageHeight)
            BoardPanel(game, Modifier.weight(1f))
            StatusLine(game)
            DifficultyBar(game)
        }
    }

    if (showTutorial) {
        TutorialSheet(onDismiss = { showTutorial = false })
    }
}

/** 标题栏：应用名 + 关于。 */
@Composable
private fun TopBar(onAbout: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Classic.Face)
            .padding(start = 16.dp, end = 8.dp, top = 10.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "复扫雷",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = Classic.Dark,
            modifier = Modifier.weight(1f),
        )
        Row(
            modifier = Modifier
                .pointerInput(Unit) { detectTapGestures { onAbout() } }
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "关于", fontSize = 14.sp, color = Classic.Dark)
        }
    }
}

/**
 * 三档难度标签。
 *
 * 切换难度只有真的换了难度才重开，来回切不会把手上的局作废。
 */
@Composable
private fun DifficultyBar(game: GameController) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Classic.Face)
            .padding(vertical = 4.dp),
    ) {
        for (i in DIFFICULTIES.indices) {
            val selected = game.difficultyIndex == i
            Column(
                modifier = Modifier
                    .weight(1f)
                    .pointerInput(i) { detectTapGestures { game.selectDifficulty(i) } }
                    .padding(vertical = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                PixelImage(Sprites.tab(i), 24.dp, 24.dp)
                Text(
                    text = DIFFICULTIES[i].label,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (selected) Classic.Dark else Classic.Shadow,
                )
            }
        }
    }
}

/**
 * 「关于」弹层。
 *
 * skipPartiallyExpanded：没有中间档位可拖，打开就是全高 —— 和 HarmonyOS 版的
 * SheetSize.LARGE 一个意思。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TutorialSheet(onDismiss: () -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = Classic.Face,
    ) {
        TutorialContent(onClose = onDismiss)
    }
}

/** 分隔用的细线，颜色走经典扫雷的灰。 */
@Composable
internal fun ClassicDivider(modifier: Modifier = Modifier) {
    Spacer(
        modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(Classic.Shadow)
    )
}
