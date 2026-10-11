package top.rayawa.dashboard.complexsweeper.android.ui

import androidx.annotation.DrawableRes
import top.rayawa.dashboard.complexsweeper.android.R
import top.rayawa.dashboard.complexsweeper.android.model.ACHIEVABLE

/**
 * 贴图查表。
 *
 * 素材来自复扫雷项目的图集，已由 `tools/slice-atlas.ts` 切成单张 PNG 写进
 * `res/drawable-nodpi`。这一层存在的意义就是把「用哪个下标查哪张图」收在一处，
 * 别散到各个组件里。
 *
 * 注意：其中经典扫雷原始图像（closed / blank / num_* / flag_* / mine_* /
 * boom_* / wrong_* / right_* / face_*）的版权属于 Microsoft，不在本项目
 * GPL-3.0 的授权范围内，只适合个人学习用途。详见 README。
 */
object Sprites {

    /** 数字贴图：下标是 a²+b²（0…64），只有 ACHIEVABLE 里那 24 个有图 */
    @DrawableRes
    fun num(clue: Int): Int = when (clue) {
        0 -> R.drawable.cw_num_0
        1 -> R.drawable.cw_num_1
        2 -> R.drawable.cw_num_2
        4 -> R.drawable.cw_num_4
        5 -> R.drawable.cw_num_5
        8 -> R.drawable.cw_num_8
        9 -> R.drawable.cw_num_9
        10 -> R.drawable.cw_num_10
        13 -> R.drawable.cw_num_13
        16 -> R.drawable.cw_num_16
        17 -> R.drawable.cw_num_17
        18 -> R.drawable.cw_num_18
        20 -> R.drawable.cw_num_20
        25 -> R.drawable.cw_num_25
        26 -> R.drawable.cw_num_26
        29 -> R.drawable.cw_num_29
        32 -> R.drawable.cw_num_32
        34 -> R.drawable.cw_num_34
        36 -> R.drawable.cw_num_36
        37 -> R.drawable.cw_num_37
        40 -> R.drawable.cw_num_40
        49 -> R.drawable.cw_num_49
        50 -> R.drawable.cw_num_50
        else -> R.drawable.cw_num_64
    }

    /** 数字贴图是否存在。不存在的值只能画成空白。 */
    fun hasNum(clue: Int): Boolean = ACHIEVABLE.contains(clue)

    /** 插着的旗，按玩家插的那一型取图（1=+1 2=-1 3=+i 4=-i） */
    @DrawableRes
    fun flag(t: Int): Int = when (clampType(t)) {
        1 -> R.drawable.cw_flag_1
        2 -> R.drawable.cw_flag_2
        3 -> R.drawable.cw_flag_3
        else -> R.drawable.cw_flag_4
    }

    /** 亮出来的雷，按真实雷型取图 */
    @DrawableRes
    fun mine(t: Int): Int = when (clampType(t)) {
        1 -> R.drawable.cw_mine_1
        2 -> R.drawable.cw_mine_2
        3 -> R.drawable.cw_mine_3
        else -> R.drawable.cw_mine_4
    }

    /** 踩中的那一颗，同色雷 + 红底 */
    @DrawableRes
    fun boom(t: Int): Int = when (clampType(t)) {
        1 -> R.drawable.cw_boom_1
        2 -> R.drawable.cw_boom_2
        3 -> R.drawable.cw_boom_3
        else -> R.drawable.cw_boom_4
    }

    /** 结算：插对的旗（插在雷上），按玩家插的那型出图，旗上画绿勾 */
    @DrawableRes
    fun rightFlag(t: Int): Int = when (clampType(t)) {
        1 -> R.drawable.cw_rightflag_1
        2 -> R.drawable.cw_rightflag_2
        3 -> R.drawable.cw_rightflag_3
        else -> R.drawable.cw_rightflag_4
    }

    // 下面四个刻意**不用 const**：AGP 里资源 ID 已经不是编译期常量了，
    // 写成 const 会踩「把资源 ID 内联成一个字面量」的坑（lint 的
    // NonConstantResourceId 就是报这个）。用普通 val，运行时从 R 里读。

    /** 结算：给一个根本不是雷的格子插了旗，旗上画红叉 */
    @DrawableRes
    val WRONG_BLANK = R.drawable.cw_wrongblank

    /** 未翻开的格子（立体按钮） */
    @DrawableRes
    val CLOSED = R.drawable.cw_closed

    /** 已翻开的空白格 —— 邻域一颗雷都没有 */
    @DrawableRes
    val BLANK = R.drawable.cw_blank

    /** 应用图标，用在「关于」弹层顶部 */
    @DrawableRes
    val ICON = R.drawable.cw_icon

    /** 人脸按钮的五种状态 */
    @DrawableRes
    fun face(kind: Int): Int = when (kind) {
        0 -> R.drawable.cw_face_down
        1 -> R.drawable.cw_face_scan
        2 -> R.drawable.cw_face_dead
        3 -> R.drawable.cw_face_win
        else -> R.drawable.cw_face_normal
    }

    /** 数码管的一格：0..9 是数字，10 是负号，11 是 i 单位，12 是空格 */
    @DrawableRes
    fun led(cell: Int): Int = when (cell) {
        in 0..9 -> LED_DIGITS[cell]
        10 -> R.drawable.cw_led_minus
        11 -> R.drawable.cw_led_i
        else -> R.drawable.cw_led_blank
    }

    /** 三档难度标签的小图标 */
    @DrawableRes
    fun tab(index: Int): Int = TABS[index.coerceIn(0, 2)]

    private val LED_DIGITS = intArrayOf(
        R.drawable.cw_led_0, R.drawable.cw_led_1, R.drawable.cw_led_2,
        R.drawable.cw_led_3, R.drawable.cw_led_4, R.drawable.cw_led_5,
        R.drawable.cw_led_6, R.drawable.cw_led_7, R.drawable.cw_led_8,
        R.drawable.cw_led_9,
    )

    private val TABS = intArrayOf(R.drawable.cw_tab_1, R.drawable.cw_tab_2, R.drawable.cw_tab_3)

    private fun clampType(t: Int): Int = t.coerceIn(1, 4)
}
