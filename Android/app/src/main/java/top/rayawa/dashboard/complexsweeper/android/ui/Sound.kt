package top.rayawa.dashboard.complexsweeper.android.ui

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import top.rayawa.dashboard.complexsweeper.android.R

/** res/raw 里的六段音效，下标就是 play() 的参数 */
private val SOUND_FILES = intArrayOf(
    R.raw.mine_1,   // 0 正实雷 +1
    R.raw.mine_2,   // 1 负实雷 -1
    R.raw.mine_3,   // 2 正虚雷 +i
    R.raw.mine_4,   // 3 负虚雷 -i
    R.raw.win,      // 4 通关
    R.raw.tick,     // 5 计时每秒一下
)

const val SND_WIN: Int = 4
const val SND_TICK: Int = 5

/**
 * 音效池。
 *
 * 六段音效是复扫雷作者青月晓自制的，随那个项目按 GPL-3.0 发布。
 *
 * 音频不在关键路径上：设备没音频、加载出错，一律静默降级成无声，
 * 绝不能因为放不出声把游戏搞崩。所以外部不需要关心任何失败。
 */
class SoundBoard(context: Context) {

    private val pool: SoundPool? = runCatching {
        SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .build()
    }.getOrNull()

    private val sampleIds = IntArray(SOUND_FILES.size)
    private val loaded = BooleanArray(SOUND_FILES.size)
    private val indexOfSample = HashMap<Int, Int>()

    init {
        val p = pool
        if (p != null) {
            p.setOnLoadCompleteListener { _, sampleId, status ->
                val i = indexOfSample[sampleId]
                if (i != null && status == 0) {
                    loaded[i] = true
                }
            }
            for (i in SOUND_FILES.indices) {
                runCatching {
                    val id = p.load(context, SOUND_FILES[i], 1)
                    if (id != 0) {
                        sampleIds[i] = id
                        indexOfSample[id] = i
                    }
                }
            }
        }
    }

    fun play(index: Int) {
        val p = pool ?: return
        if (index !in SOUND_FILES.indices || !loaded[index]) return
        runCatching { p.play(sampleIds[index], 1f, 1f, 1, 0, 1f) }
    }

    /** 踩雷：按踩中的那一颗的雷型播，四种雷声音不同 */
    fun playMine(kind: Int) {
        play(if (kind in 0..3) kind else 0)
    }

    fun release() {
        runCatching { pool?.release() }
    }
}
