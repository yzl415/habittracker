import { common } from '@kit.AbilityKit';
import { HabitStore } from '../model/HabitStore';
import { getTheme, AppTheme, resolveDark, systemIsDark, applyWindowColorMode } from '../model/Theme';
import { TodayView } from '../components/TodayView';
import { StatsView } from '../components/StatsView';
import { MineView } from '../components/MineView';
import { AppIcon } from '../components/AppIcon';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State tick: number = 0;
  @State loaded: boolean = false;
  @StorageProp('themeDark') themeDark: boolean = false;
  private store: HabitStore = HabitStore.getInstance();
  private tabsController: TabsController = new TabsController();

  th(): AppTheme {
    return getTheme(this.themeDark);
  }

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.store.init(ctx);
    // 由主题模式 + 系统色彩解析出最终深浅，并把窗口色彩模式钉死成同一值
    const dark: boolean = resolveDark(this.store.themeMode, systemIsDark(ctx));
    AppStorage.setOrCreate('themeDark', dark);
    applyWindowColorMode(ctx, dark);
    this.loaded = true;
    this.tick++;
  }

  /** 系统深浅色变化时（仅 mode=system）实时跟随 */
  onSysColorModeChange(): void {
    if (this.store.themeMode !== 'system') {
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    const dark: boolean = systemIsDark(ctx);
    AppStorage.setOrCreate('themeDark', dark);
    applyWindowColorMode(ctx, dark);
  }

  onPageShow(): void {
    this.onSysColorModeChange();
    if (this.loaded) {
      this.tick++;
    }
  }

  @Builder
  TabItem(index: number, icon: string, label: string) {
    Column() {
      AppIcon({
        name: icon,
        color: this.currentIndex === index ? this.th().accent : this.th().textTertiary,
        iconSize: 25,
        stroke: this.currentIndex === index ? 2.2 : 1.9
      })
      Text(label)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? this.th().accent : this.th().textTertiary)
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 9, bottom: 4 })
  }

  build() {
    Stack() {
      Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
        TabContent() {
          TodayView({ tick: this.tick })
        }
        .tabBar(this.TabItem(0, 'today', '今日'))
        .onWillShow(() => this.tick++)

        TabContent() {
          StatsView({ tick: this.tick })
        }
        .tabBar(this.TabItem(1, 'stats', '统计'))
        .onWillShow(() => this.tick++)

        TabContent() {
          MineView({ tick: this.tick })
        }
        .tabBar(this.TabItem(2, 'mine', '我的'))
        .onWillShow(() => this.tick++)
      }
      .barHeight(66)
      .scrollable(false)
      .barBackgroundColor(this.th().navBar)
      .divider({ strokeWidth: 0.5, color: this.th().divider })
      .onChange((index: number) => {
        // 仅记录当前页用于 TabItem 高亮。数据刷新交给每个 TabContent 的
        // onWillShow（切回时必触发且组件已激活，reload 一定生效）；
        // 不在此处 tick++，避免切换起始时机打不到非激活子树。
        this.currentIndex = index;
      })
      .backgroundColor(this.th().bg)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
