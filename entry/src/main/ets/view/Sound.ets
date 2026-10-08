import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;

/** rawfile 里的六段音效，下标就是 SoundBoard.play() 的参数 */
const FILES: string[] = [
  'sounds/mine_1.wav',   // 0 正实雷 +1
  'sounds/mine_2.wav',   // 1 负实雷 -1
  'sounds/mine_3.wav',   // 2 正虚雷 +i
  'sounds/mine_4.wav',   // 3 负虚雷 -i
  'sounds/win.wav',      // 4 通关
  'sounds/tick.wav'      // 5 计时每秒一下
];

export const SND_WIN: number = 4;
export const SND_TICK: number = 5;

/**
 * 音效池。
 *
 * 六段音效是复扫雷作者青月晓自制的，随那个项目按 GPL-3.0 发布，
 * 已经从它的 sounds.bin 里提取成 rawfile（提取用的是它自带的
 * `tools/gen_sounds.js --extract`）。
 *
 * 音频不在关键路径上：初始化失败、设备没音频、加载出错，一律静默降级成无声，
 * 绝不能因为放不出声把游戏搞崩。所以外部不需要 await 任何东西。
 */
export class SoundBoard {
  private pool: media.SoundPool | null = null;
  private ids: number[] = [];
  private ready: boolean = false;

  async init(context: common.Context): Promise<void> {
    if (this.ready) {
      return;
    }
    try {
      // rendererFlags 是 AudioRendererInfo 的必填项，0 表示无特殊标志
      const pool: media.SoundPool = await media.createSoundPool(FILES.length, {
        usage: audio.StreamUsage.STREAM_USAGE_GAME,
        rendererFlags: 0
      });
      const ids: number[] = [];
      for (const file of FILES) {
        const fd = await context.resourceManager.getRawFd(file);
        ids.push(await pool.load(fd.fd, fd.offset, fd.length));
      }
      this.pool = pool;
      this.ids = ids;
      this.ready = true;
    } catch (err) {
      hilog.warn(DOMAIN, 'sound', '音效初始化失败，改为静音: %{public}s', JSON.stringify(err));
    }
  }

  play(index: number): void {
    if (!this.ready || this.pool === null || index < 0 || index >= this.ids.length) {
      return;
    }
    try {
      this.pool.play(this.ids[index]).catch(() => {
      });
    } catch (err) {
      // 放不出来就算了
    }
  }

  /** 踩雷：按踩中的那一颗的雷型播，四种雷声音不同 */
  playMine(kind: number): void {
    this.play(kind >= 0 && kind < 4 ? kind : 0);
  }

  release(): void {
    const pool: media.SoundPool | null = this.pool;
    this.pool = null;
    this.ids = [];
    this.ready = false;
    if (pool === null) {
      return;
    }
    try {
      pool.release().catch(() => {
      });
    } catch (err) {
    }
  }
}
