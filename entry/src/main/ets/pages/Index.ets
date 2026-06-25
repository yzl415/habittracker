import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
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
  @State showPrivacy: boolean = false;
  @State showWelcome: boolean = false;
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
    this.showPrivacy = !this.store.privacyAgreed;
    this.showWelcome = this.store.privacyAgreed && !this.store.onboarded;
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

  async agreePrivacy(): Promise<void> {
    await this.store.setPrivacyAgreed();
    this.showPrivacy = false;
    this.showWelcome = !this.store.onboarded;
  }

  async finishWelcome(): Promise<void> {
    await this.store.setOnboarded();
    this.showWelcome = false;
  }

  exitApp(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    ctx.terminateSelf();
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

      if (this.showPrivacy) {
        this.PrivacyGate()
      }
      if (this.showWelcome && !this.showPrivacy) {
        this.WelcomeScreen()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  WelcomeScreen() {
    Column() {
      Blank().layoutWeight(1)
      // App 图标（渐变圆角方 + 对勾）
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(96)
          .height(96)
          .borderRadius(24)
          .linearGradient({ angle: 135, colors: [['#5B53E8', 0], ['#7C76F0', 1]] })
        Text('✓')
          .fontSize(52)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      Text('萌芽打卡')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.th().textPrimary)
        .margin({ top: 24 })
      Text('每天一点点，坚持看得见')
        .fontSize(15)
        .fontColor(this.th().textSecondary)
        .margin({ top: 10 })

      Column({ space: 16 }) {
        this.Feature('记录每天想坚持的小事')
        this.Feature('打卡进度、连续天数一目了然')
        this.Feature('数据只存本地，安全又私密')
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 44 })

      Blank().layoutWeight(1)
      Button('开始使用')
        .width('100%')
        .height(52)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(this.th().accent)
        .borderRadius(16)
        .onClick(() => this.finishWelcome())
    }
    .width('100%')
    .height('100%')
    .padding({ left: 36, right: 36, top: 60, bottom: 48 })
    .backgroundColor(this.th().bg)
  }

  @Builder
  Feature(text: string) {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Circle().width(24).height(24).fill(this.th().accentSoft)
        Text('✓')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.th().accent)
      }
      .margin({ right: 14 })
      Text(text)
        .fontSize(15)
        .fontColor(this.th().textPrimary)
        .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  PrivacyGate() {
    Column() {
      Column() {
        Text('欢迎使用萌芽打卡')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.th().textPrimary)
          .margin({ top: 4, bottom: 14 })
        Text() {
          Span('在使用前，请阅读并同意')
          Span('《隐私政策》')
            .fontColor(this.th().accent)
            .onClick(() => router.pushUrl({ url: 'pages/Privacy' }))
          Span('。我们高度重视你的隐私：所有习惯数据仅保存在你的设备本地，不收集、不上传、无广告、无第三方共享。')
        }
        .fontSize(14)
        .lineHeight(23)
        .textAlign(TextAlign.Start)
        .width('100%')

        Button('同意并开始使用')
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(this.th().accent)
          .borderRadius(14)
          .margin({ top: 22 })
          .onClick(() => this.agreePrivacy())
        Text('不同意并退出')
          .fontSize(14)
          .fontColor(this.th().textTertiary)
          .margin({ top: 14, bottom: 4 })
          .onClick(() => this.exitApp())
      }
      .width('86%')
      .padding(24)
      .backgroundColor(this.th().surface)
      .borderRadius(22)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#99000000')
    .justifyContent(FlexAlign.Center)
  }
}
