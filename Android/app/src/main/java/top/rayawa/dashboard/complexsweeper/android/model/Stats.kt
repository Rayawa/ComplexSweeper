package top.rayawa.dashboard.complexsweeper.android.model

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** 一档难度的历史战绩 */
data class DifficultyStats(
    val wins: Int = 0,
    val losses: Int = 0,
    /** 最快通关秒数，0 表示还没通关过 */
    val bestSeconds: Int = 0,
)

/**
 * 战绩存档。
 *
 * 用 SharedPreferences：读写都是同步的，不需要协程。
 * 存档坏了顶多丢记录，绝不能连累游戏本身 —— 所以读一律给默认值。
 */
class StatsStore(context: Context, slots: Int) {

    private val prefs = context.getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)

    var entries by mutableStateOf(load(slots))
        private set

    private fun load(slots: Int): List<DifficultyStats> =
        (0 until slots).map { i ->
            DifficultyStats(
                wins = prefs.getInt("wins_$i", 0),
                losses = prefs.getInt("losses_$i", 0),
                bestSeconds = prefs.getInt("best_$i", 0),
            )
        }

    fun entry(index: Int): DifficultyStats =
        entries.getOrElse(index) { DifficultyStats() }

    fun recordWin(index: Int, seconds: Int) {
        if (index !in entries.indices) return
        val old = entries[index]
        val best = if (old.bestSeconds == 0 || seconds < old.bestSeconds) seconds else old.bestSeconds
        update(index, old.copy(wins = old.wins + 1, bestSeconds = best))
    }

    fun recordLoss(index: Int) {
        if (index !in entries.indices) return
        val old = entries[index]
        update(index, old.copy(losses = old.losses + 1))
    }

    private fun update(index: Int, stats: DifficultyStats) {
        entries = entries.toMutableList().also { it[index] = stats }
        prefs.edit()
            .putInt("wins_$index", stats.wins)
            .putInt("losses_$index", stats.losses)
            .putInt("best_$index", stats.bestSeconds)
            .apply()
    }

    private companion object {
        const val STORE_NAME = "complexsweeper_stats"
    }
}
