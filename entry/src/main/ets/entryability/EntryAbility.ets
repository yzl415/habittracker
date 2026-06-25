import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';

const DOMAIN = 0x0000;
const STORE_NAME: string = 'habit_store';
const KEY_THEME_MODE: string = 'theme_mode';
const KEY_THEME_DARK: string = 'theme_dark';

export default class EntryAbility extends UIAbility {
  /** 读取已保存的主题模式（system/light/dark），兼容旧版布尔字段 */
  private async readThemeMode(): Promise<string> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, STORE_NAME);
      const mode: string = await store.get(KEY_THEME_MODE, '') as string;
      if (mode === 'system' || mode === 'light' || mode === 'dark') {
        return mode;
      }
      const legacyDark: boolean = await store.get(KEY_THEME_DARK, false) as boolean;
      return legacyDark ? 'dark' : 'system';
    } catch (e) {
      return 'system';
    }
  }

  /** 当前系统是否深色 */
  private systemIsDark(): boolean {
    return this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  /**
   * 把窗口色彩模式钉死成 App 实际要渲染的主题，避免系统对硬编码颜色做自动反相，
   * 杜绝“深色模式下浅字浅底（对比度 1.11）”的上架检测问题。
   */
  private async applyColorMode(): Promise<void> {
    const mode: string = await this.readThemeMode();
    const dark: boolean = mode === 'dark' || (mode === 'system' && this.systemIsDark());
    try {
      this.context.getApplicationContext().setColorMode(dark
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyColorMode();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  /** 系统色彩模式变化时（仅 mode=system 生效）重新钉死窗口色彩模式 */
  onConfigurationUpdate(newConfig: Configuration): void {
    this.applyColorMode();
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
