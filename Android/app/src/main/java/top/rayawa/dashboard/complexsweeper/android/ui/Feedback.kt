package top.rayawa.dashboard.complexsweeper.android.ui

import android.content.Context
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * 轻振反馈。
 *
 * 长按开格如果没有任何触感反馈，手指会不确定自己到底按够时间没有 ——
 * 这个游戏里「按够没有」直接决定是标记还是开格，所以反馈很重要。
 *
 * 振动不在关键路径上：设备不支持、权限没给、调用失败，一律静默吞掉。
 */
class Feedback(context: Context) {

    private val vibrator: Vibrator? = runCatching {
        val manager = context.getSystemService(VibratorManager::class.java)
        manager?.defaultVibrator
    }.getOrNull()

    private fun buzz(durationMs: Long) {
        if (durationMs <= 0) return
        runCatching {
            vibrator?.vibrate(
                VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
            )
        }
    }

    /** 单击：标记切换 */
    fun tick() = buzz(10)

    /** 长按：开格 */
    fun reveal() = buzz(24)

    /** 踩雷或通关 */
    fun outcome() = buzz(60)
}
