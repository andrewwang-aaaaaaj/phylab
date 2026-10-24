import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'PhyLab';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
      windowStage.getMainWindow((err, mainWindow) => {
        if (err.code) {
          return;
        }
        try {
          mainWindow.setWindowLayoutFullScreen(true).catch(() => {
            hilog.warn(DOMAIN, TAG, 'Unable to enable full screen layout.');
          });
          mainWindow.setWindowSystemBarProperties({
            statusBarColor: '#00000000',
            navigationBarColor: '#F5F5F7',
            statusBarContentColor: '#1D1D1F',
            navigationBarContentColor: '#1D1D1F'
          }).catch(() => {
            hilog.warn(DOMAIN, TAG, 'Unable to style system bars.');
          });
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'Window decoration failed.');
        }
      });
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
