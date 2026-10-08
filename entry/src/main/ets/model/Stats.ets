import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const STORE_NAME: string = 'complexsweeper_stats';
const DOMAIN: number = 0x0000;

/** 一档难度的历史战绩 */
export class DifficultyStats {
  wins: number = 0;
  losses: number = 0;
  /** 最快通关秒数，0 表示还没通关过 */
  bestSeconds: number = 0;
}

/**
 * 战绩存档。
 *
 * 所有读写都吞掉异常：存档坏了顶多丢记录，绝不能连累游戏本身。
 * 所以游戏里任何地方都不需要 await 它，也不需要关心它成没成功。
 */
export class StatsStore {
  private prefs: preferences.Preferences | null = null;
  private cache: DifficultyStats[] = [];

  constructor(slots: number) {
    for (let i = 0; i < slots; i++) {
      this.cache.push(new DifficultyStats());
    }
  }

  async load(context: common.Context): Promise<void> {
    try {
      this.prefs = await preferences.getPreferences(context, STORE_NAME);
      for (let i = 0; i < this.cache.length; i++) {
        const s: DifficultyStats = this.cache[i];
        s.wins = await this.readNumber(`wins_${i}`);
        s.losses = await this.readNumber(`losses_${i}`);
        s.bestSeconds = await this.readNumber(`best_${i}`);
      }
    } catch (err) {
      hilog.warn(DOMAIN, 'stats', '读取战绩失败: %{public}s', JSON.stringify(err));
    }
  }

  private async readNumber(key: string): Promise<number> {
    if (this.prefs === null) {
      return 0;
    }
    try {
      const raw = await this.prefs.get(key, '0');
      const n: number = parseInt(String(raw), 10);
      return Number.isNaN(n) ? 0 : n;
    } catch (err) {
      hilog.warn(DOMAIN, 'stats', '读取 %{public}s 失败: %{public}s', key, JSON.stringify(err));
      return 0;
    }
  }

  get(index: number): DifficultyStats {
    return this.cache[index];
  }

  async recordWin(index: number, seconds: number): Promise<void> {
    const s: DifficultyStats = this.cache[index];
    s.wins += 1;
    if (s.bestSeconds === 0 || seconds < s.bestSeconds) {
      s.bestSeconds = seconds;
    }
    await this.persist(index);
  }

  async recordLoss(index: number): Promise<void> {
    this.cache[index].losses += 1;
    await this.persist(index);
  }

  private async persist(index: number): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    try {
      const s: DifficultyStats = this.cache[index];
      await this.prefs.put(`wins_${index}`, `${s.wins}`);
      await this.prefs.put(`losses_${index}`, `${s.losses}`);
      await this.prefs.put(`best_${index}`, `${s.bestSeconds}`);
      await this.prefs.flush();
    } catch (err) {
      hilog.warn(DOMAIN, 'stats', '保存战绩失败: %{public}s', JSON.stringify(err));
    }
  }
}
