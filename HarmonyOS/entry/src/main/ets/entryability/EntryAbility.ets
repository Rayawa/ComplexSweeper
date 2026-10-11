import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      // 扫雷是要盯着屏幕想很久的游戏，中途熄屏很打断。拿不到窗口就算了，不影响玩。
      mainWindow.setWindowKeepScreenOn(true);
      // 本应用只有浅色一套配色，状态栏又浮在银灰面板上。系统默认会跟着深色模式把
      // 状态栏内容刷成白的，压在银灰上就看不见了 —— 底色留透明（沉浸），字钉死黑色。
      //
      // 这条 API 对 2in1 不可用（编译会提示，和音效那两条 syscap 提示同类），
      // 分屏 / 悬浮窗下系统也不一定采纳。两种情况都只是保持系统默认配色，不影响玩。
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#000000'
      }).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, 'testTag', '状态栏设置失败: %{public}s', JSON.stringify(err));
      });
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, 'testTag', '窗口设置失败: %{public}s', JSON.stringify(err));
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}