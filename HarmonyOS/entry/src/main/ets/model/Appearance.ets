import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** 外观偏好独立保存，不触碰旧战绩。 */
export class AppearanceStore {
  private prefs: preferences.Preferences | null = null;

  async load(context: common.Context): Promise<boolean> {
    try {
      this.prefs = await preferences.getPreferences(context, 'complexsweeper_settings');
      const value = await this.prefs.get('colorEnabled', true);
      return typeof value === 'boolean' ? value : true;
    } catch (err) {
      hilog.warn(0, 'appearance', '读取外观失败: %{public}s', JSON.stringify(err));
      return true;
    }
  }

  save(enabled: boolean): void {
    if (this.prefs === null) return;
    try {
      this.prefs.putSync('colorEnabled', enabled);
      this.prefs.flush().catch(() => {
        hilog.warn(0, 'appearance', '保存外观失败');
      });
    } catch (err) {
      hilog.warn(0, 'appearance', '保存外观失败: %{public}s', JSON.stringify(err));
    }
  }
}
