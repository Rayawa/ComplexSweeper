package top.rayawa.dashboard.complexsweeper.android.model

/**
 * 一档难度。三档沿用复扫雷参考实现的标准配置。
 *
 * 注意高级是 30 列 × 16 行（宽而扁），和经典扫雷专家局一致。
 * 手机上 30 列会超出一屏，棋盘横向可以滚动 —— 这是忠于参考实现的取舍，
 * 好处是格子和贴图都保持正常大小。
 */
data class Difficulty(
    val label: String,
    /** 列数 */
    val w: Int,
    /** 行数 */
    val h: Int,
    val mines: Int,
)

val DIFFICULTIES: List<Difficulty> = listOf(
    Difficulty("初级", 9, 9, 10),
    Difficulty("中级", 16, 16, 40),
    Difficulty("高级", 30, 16, 99),
)
