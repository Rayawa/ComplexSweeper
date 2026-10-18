package top.rayawa.dashboard.complexsweeper.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.rayawa.dashboard.complexsweeper.android.model.TYPE_LABELS

/** 「关于」底部展示的版本号，与 build.gradle.kts 的 versionName 保持一致 */
const val APP_VERSION: String = "1.2.0"

/**
 * 「关于」弹层的内容。
 *
 * 上半是基础规则：数字怎么来的、四种雷、空白和 0 的区别、怎么操作 ——
 * 展开的判定细节和 24 个可达值都没有展开写，上手之后自然碰到，
 * 这里再列一遍只会把基础规则淹掉。下半是版本、开发者与版权。
 *
 * 标题栏自己画：系统的 BottomSheet 标题只收文字、给不了颜色，标题和关闭按钮
 * 都会是系统灰，压在银灰面板上不好看。
 */
@Composable
fun TutorialContent(onClose: () -> Unit) {
    val uriHandler = LocalUriHandler.current
    Column(
        Modifier
            .fillMaxWidth()
            .background(Classic.Face)
            .verticalScroll(rememberScrollState())
    ) {
        SheetTitleBar(onClose)
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp)
                .padding(bottom = 32.dp)
        ) {
            AppHeader()

            SectionTitle("两种模式")
            Body("底部切换圆复数与闵可夫斯基模式，上方选择难度。切换模式或难度会重开，重复选择保留当前局。两种模式分别保存纪录。")

            SectionTitle("圆复数模式 · i² = −1")
            Body("四种雷为 +1、−1、+i、−i。邻域和为 a+bi 时，显示 √(a²+b²)。展开要求旗数等于真雷数，实虚数量比例相同或互为倒数。")

            SectionTitle("闵可夫斯基模式 · j² = +1")
            Body("四种雷为 +1、−1、+j、−j，分别为正负实雷（类空雷）和正负双曲虚雷（类时雷）。邻域和为 a+bj 时，显示 √(a²−b²)；负值显示为带 i 的根式，例如 −4 显示 2i。")

            SectionTitle("新模式的展开与 0")
            Body("展开要求旗数等于真雷数，且旗帜净和的 |a|、|b| 分别与真雷相等。不能交换实部与 j 部。显示 0 也可能来自 |a|=|b|，例如 +1 与 +j；只有周围完全无雷的空白格自动扩散。")

            SectionTitle("怎么玩")
            Body("格子上的数字，是周围所有雷之和的模长。翻开所有非雷格就赢。")

            SectionTitle("圆复数示例")
            Body(
                "它们当复数相加，和再取模长就是格子上的数。比如周围有一颗 +1 和一颗 −i，"
                    + "和是 1−i，显示 √2。"
            )
            TypeRow()

            SectionTitle("空白和 0 不是一回事")
            Body("空白格：周围一颗雷都没有。")
            Body("显示 0：周围有雷，但当前模式的模长为 0。")

            SectionTitle("操作")
            Body("单击未翻开的格子：循环标记 空 → +1 → −1 → +i / +j → −i / −j → 空。")
            Body("长按未翻开的格子：清除该格标记并翻开。首击安全，开局后翻到雷会失败；连片展开仍跳过其他标记格。")
            Body("单击已翻开的数字格：周围旗子插对时，一次掀开周围没插旗的格子。")

            ClassicDivider(Modifier.padding(top = 20.dp, bottom = 12.dp))

            Footer("版本 $APP_VERSION")
            Footer(
                "原作 青月晓 · Complexweeper ↗",
                color = Color(0xFF005BB5),
                modifier = Modifier.testTag("original-repository").clickable(
                    role = Role.Button,
                    onClickLabel = "打开原仓库 GitHub",
                ) {
                    uriHandler.openUri("https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game")
                },
            )
            Footer("Android 移植 Ray Chen (Rayawa)")
            Footer("Copyright © 2026 Ray Chen (Rayawa)")
        }
    }
}

@Composable
private fun SheetTitleBar(onClose: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "关于",
            fontSize = 17.sp,
            fontWeight = FontWeight.Bold,
            color = Classic.Dark,
            modifier = Modifier.weight(1f),
        )
        // 圆底关闭按钮，和标题栏那颗「关于」一个分量 —— 光一支叉子没有边界，
        // 压在银灰面板上不像个能按的东西
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.08f))
                .pointerInput(Unit) { detectTapGestures { onClose() } },
            contentAlignment = Alignment.Center,
        ) {
            Text(text = "✕", fontSize = 15.sp, color = Classic.Dark)
        }
    }
}

/** 顶部：图标 + 中英文名 */
@Composable
private fun AppHeader() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .classicBevel(raised = true, thickness = 3.dp, inset = 17.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PixelImage(Sprites.ICON, 56.dp, 56.dp)
        Spacer(Modifier.width(14.dp))
        Column {
            Text("复扫雷", fontSize = 21.sp, fontWeight = FontWeight.Bold, color = Classic.Dark)
            Text("ComplexSweeper", fontSize = 13.sp, color = Classic.Shadow)
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        fontSize = 16.sp,
        fontWeight = FontWeight.Bold,
        color = Classic.Dark,
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp, bottom = 6.dp),
    )
}

@Composable
private fun Body(text: String) {
    Text(
        text = text,
        fontSize = 14.sp,
        lineHeight = 21.sp,
        color = Classic.Dark,
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 4.dp),
    )
}

/** 四种雷：旗帜贴图 + 名字 */
@Composable
private fun TypeRow() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 6.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        for (t in TYPE_LABELS.indices) {
            Column(
                modifier = Modifier.padding(horizontal = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                PixelImage(Sprites.flag(t + 1), 30.dp, 30.dp)
                Text(
                    text = TYPE_LABELS[t],
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = Classic.Dark,
                )
            }
        }
    }
}

@Composable
private fun Footer(text: String, modifier: Modifier = Modifier, color: Color = Classic.Shadow) {
    Text(
        text = text,
        fontSize = 12.sp,
        color = color,
        textAlign = TextAlign.Center,
        modifier = modifier
            .fillMaxWidth()
            .padding(bottom = 6.dp),
    )
}
