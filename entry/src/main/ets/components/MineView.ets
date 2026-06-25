import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { HabitStore, ThemeMode } from '../model/HabitStore';
import { NotificationService } from '../model/NotificationService';
import { Habit } from '../model/Habit';
import { unlockedCount, ACHIEVEMENTS } from '../model/Achievement';
import { getTheme, AppTheme, resolveDark, systemIsDark, applyWindowColorMode } from '../model/Theme';
import { AppIcon } from './AppIcon';

/** 我的页：总览 + 主题切换 + 成就 + 备份 + 排序 + 归档管理 */
@Component
export struct MineView {
  @Prop @Watch('onTick') tick: number;
  @StorageProp('dataVersion') @Watch('onTick') dataVersion: number = 0;
  @StorageProp('themeDark') themeDark: boolean = false;
  @State themeMode: ThemeMode = 'system';
  @State activeNum: number = 0;
  @State archived: Habit[] = [];
  @State totalCheckins: number = 0;
  @State badges: number = 0;
  @State showImport: boolean = false;
  @State importText: string = '';
  private store: HabitStore = HabitStore.getInstance();

  th(): AppTheme {
    return getTheme(this.themeDark);
  }

  aboutToAppear(): void {
    this.themeMode = this.store.themeMode;
    this.reload();
  }

  onTick(): void {
    this.reload();
  }

  reload(): void {
    this.themeMode = this.store.themeMode;
    this.activeNum = this.store.activeHabits().length;
    this.archived = this.store.archivedHabits().slice();
    let n: number = 0;
    this.store.habits.forEach((h: Habit) => n += h.checkedDates.length);
    this.totalCheckins = n;
    this.badges = unlockedCount(this.store.activeHabits());
  }

  /** 选择主题模式：保存偏好并把窗口色彩模式钉死成解析后的深浅 */
  async selectThemeMode(mode: ThemeMode): Promise<void> {
    this.themeMode = mode;
    await this.store.setThemeMode(mode);
    const ctx = getContext(this) as common.UIAbilityContext;
    const dark: boolean = resolveDark(mode, systemIsDark(ctx));
    AppStorage.setOrCreate('themeDark', dark);
    applyWindowColorMode(ctx, dark);
  }

  async enableNotification(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const ok: boolean = await NotificationService.requestEnable(ctx);
    promptAction.showToast({ message: ok ? '已开启通知权限' : '请在系统设置中开启通知' });
  }

  async exportData(): Promise<void> {
    const json: string = this.store.exportJson();
    const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, json);
    const board: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    await board.setData(data);
    promptAction.showToast({ message: '数据已复制到剪贴板，请妥善保存' });
  }

  /** 打开导入弹窗（清空输入框） */
  openImport(): void {
    this.importText = '';
    this.showImport = true;
  }

  /** 一键把剪贴板内容填入输入框 */
  async pasteFromClipboard(): Promise<void> {
    try {
      const board: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      const data: pasteboard.PasteData = await board.getData();
      const text: string = data.getPrimaryText();
      if (!text || text.length === 0) {
        promptAction.showToast({ message: '剪贴板为空，可手动粘贴备份内容' });
        return;
      }
      this.importText = text;
    } catch (e) {
      promptAction.showToast({ message: '读取剪贴板失败，可手动粘贴备份内容' });
    }
  }

  /** 用输入框中的备份内容覆盖导入 */
  async doImport(): Promise<void> {
    const text: string = this.importText.trim();
    if (text.length === 0) {
      promptAction.showToast({ message: '请先粘贴备份内容' });
      return;
    }
    const ok: boolean = await this.store.importFromJson(text);
    if (ok) {
      this.showImport = false;
      this.importText = '';
      this.reload();
      promptAction.showToast({ message: '导入成功' });
    } else {
      promptAction.showToast({ message: '数据格式不正确，请检查备份内容' });
    }
  }

  async restore(h: Habit): Promise<void> {
    await this.store.setArchived(h.id, false);
    this.reload();
    promptAction.showToast({ message: '已恢复到今日列表' });
  }

  async deleteForever(h: Habit): Promise<void> {
    await NotificationService.cancel(h.reminderId);
    await this.store.remove(h.id);
    this.reload();
    promptAction.showToast({ message: '已彻底删除' });
  }

  build() {
    Stack() {
      Column() {
        Text('我的')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.th().textPrimary)
          .letterSpacing(0.2)
          .width('100%')
          .padding({ left: 22, right: 22, top: 22, bottom: 14 })

        Scroll() {
          Column() {
            this.SummaryCard()
            this.ThemeCard()
            this.SettingsGroup()
            if (this.archived.length > 0) {
              this.ArchivedGroup()
            }
            this.About()
          }
          .width('100%')
          .padding({ left: 22, right: 22, bottom: 96 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      if (this.showImport) {
        this.ImportDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ImportDialog() {
    Column() {
      Column() {
        Text('导入恢复')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.th().textPrimary)
          .width('100%')
        Text('粘贴此前“导出备份”得到的内容，将覆盖当前全部数据。')
          .fontSize(13)
          .fontColor(this.th().textSecondary)
          .lineHeight(20)
          .width('100%')
          .margin({ top: 8 })

        TextArea({ text: this.importText, placeholder: '在此粘贴备份内容…' })
          .width('100%')
          .height(150)
          .fontSize(13)
          .fontColor(this.th().textPrimary)
          .placeholderColor(this.th().textTertiary)
          .backgroundColor(this.th().surfaceAlt)
          .borderRadius(12)
          .margin({ top: 14 })
          .onChange((v: string) => this.importText = v)

        Text('从剪贴板粘贴')
          .fontSize(14)
          .fontColor(this.th().accent)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .margin({ top: 12 })
          .borderRadius(12)
          .backgroundColor(this.th().accentSoft)
          .onClick(() => this.pasteFromClipboard())

        Row({ space: 12 }) {
          Text('取消')
            .fontSize(16)
            .fontColor(this.th().textSecondary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(46)
            .borderRadius(13)
            .backgroundColor(this.th().surfaceAlt)
            .onClick(() => { this.showImport = false; })
          Text('覆盖导入')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(46)
            .borderRadius(13)
            .backgroundColor(this.th().danger)
            .onClick(() => this.doImport())
        }
        .width('100%')
        .margin({ top: 16 })
      }
      .width('86%')
      .padding(22)
      .backgroundColor(this.th().surface)
      .borderRadius(22)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#99000000')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  SummaryCard() {
    Row() {
      this.SummaryItem('active', '活跃习惯', false)
      Divider().vertical(true).height(34).color(this.th().divider)
      this.SummaryItem('total', '累计打卡', false)
      Divider().vertical(true).height(34).color(this.th().divider)
      this.SummaryItem('badges', '成就', true)
    }
    .width('100%')
    .padding({ top: 22, bottom: 22 })
    .backgroundColor(this.th().surface)
    .borderRadius(22)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .shadow({ radius: this.th().shadowRadius, color: this.th().shadowColor, offsetX: 0, offsetY: 3 })
    .margin({ top: 4 })
  }

  /** 概览数值：在 @Builder 体内实时计算，避免按值传参在数据变化后不刷新 */
  summaryValue(kind: string): string {
    if (kind === 'active') {
      return this.activeNum.toString();
    }
    if (kind === 'total') {
      return this.totalCheckins.toString();
    }
    return this.badges + '/' + ACHIEVEMENTS.length;
  }

  @Builder
  SummaryItem(kind: string, label: string, accent: boolean) {
    Column() {
      // 数值与颜色均在 @Builder 体内实时读取，避免按值传参导致数据/主题变化后不刷新
      Text(this.summaryValue(kind))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(accent ? this.th().accent : this.th().textPrimary)
      Text(label).fontSize(11).fontColor(this.th().textSecondary).margin({ top: 5 })
    }
    .layoutWeight(1)
  }

  @Builder
  ThemeCard() {
    Column() {
      Row() {
        Column() {
          Stack() {
            AppIcon({ name: this.themeDark ? 'moon' : 'sun', color: this.th().accent, iconSize: 22, cutout: this.th().accentSoft })
          }
          .width(38)
          .height(38)
          .borderRadius(11)
          .backgroundColor(this.th().accentSoft)
          .margin({ right: 14 })
        }
        Column() {
          Text('外观')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.th().textPrimary)
          Text(this.themeModeHint())
            .fontSize(12.5)
            .fontColor(this.th().textTertiary)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 6 }) {
        this.ThemeTab('跟随系统', 'system')
        this.ThemeTab('浅色', 'light')
        this.ThemeTab('深色', 'dark')
      }
      .width('100%')
      .padding(4)
      .backgroundColor(this.th().surfaceAlt)
      .borderRadius(13)
      .margin({ top: 14 })
    }
    .width('100%')
    .padding({ top: 14, bottom: 14, left: 16, right: 16 })
    .backgroundColor(this.th().surface)
    .borderRadius(18)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .margin({ top: 14 })
  }

  themeModeHint(): string {
    if (this.themeMode === 'light') {
      return '已锁定极简亮色';
    }
    if (this.themeMode === 'dark') {
      return '已锁定暗黑质感';
    }
    return '跟随系统深浅切换';
  }

  @Builder
  ThemeTab(label: string, mode: ThemeMode) {
    Text(label)
      .fontSize(14)
      .fontColor(this.themeMode === mode ? this.th().accentText : this.th().textSecondary)
      .fontWeight(this.themeMode === mode ? FontWeight.Medium : FontWeight.Normal)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(36)
      .borderRadius(10)
      .backgroundColor(this.themeMode === mode ? this.th().accent : '#00000000')
      .onClick(() => this.selectThemeMode(mode))
  }

  @Builder
  RowItem(icon: string, label: string, trailing: string, liveBadge: boolean, showDivider: boolean, action: () => void) {
    Column() {
      Row() {
        Stack() {
          AppIcon({ name: icon, color: this.th().textSecondary, iconSize: 19, stroke: 1.9, cutout: this.th().surfaceAlt })
        }
        .width(34)
        .height(34)
        .borderRadius(10)
        .backgroundColor(this.th().surfaceAlt)
        .margin({ right: 13 })
        Text(label).fontSize(15.5).fontColor(this.th().textPrimary).layoutWeight(1)
        // liveBadge=true 时在体内实时计算徽章计数，避免按值传参在解锁后不刷新
        if (liveBadge) {
          Text(this.badges + '/' + ACHIEVEMENTS.length)
            .fontSize(13.5).fontColor(this.th().textTertiary).margin({ right: 6 })
        } else if (trailing.length > 0) {
          Text(trailing).fontSize(13.5).fontColor(this.th().textTertiary).margin({ right: 6 })
        }
        Text('›').fontSize(19).fontColor(this.th().textTertiary)
      }
      .width('100%')
      .padding({ top: 13, bottom: 13, left: 14, right: 14 })
      .onClick(action)
      if (showDivider) {
        Divider().color(this.th().divider).margin({ left: 61 })
      }
    }
    .width('100%')
  }

  @Builder
  GroupLabel(text: string) {
    Text(text)
      .fontSize(12.5)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.th().textTertiary)
      .letterSpacing(0.5)
      .width('100%')
      .margin({ top: 20, bottom: 9, left: 6 })
  }

  @Builder
  SettingsGroup() {
    this.GroupLabel('习惯')
    Column() {
      this.RowItem('trophy', '我的成就', '', true, true, () => {
        router.pushUrl({ url: 'pages/Achievements' });
      })
      this.RowItem('reorder', '习惯排序', '', false, false, () => {
        router.pushUrl({ url: 'pages/ReorderHabits' });
      })
    }
    .width('100%')
    .backgroundColor(this.th().surface)
    .borderRadius(18)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .clip(true)

    this.GroupLabel('数据与提醒')
    Column() {
      this.RowItem('bell', '开启通知权限', '', false, true, () => this.enableNotification())
      this.RowItem('upload', '导出备份', '复制到剪贴板', false, true, () => this.exportData())
      this.RowItem('download', '导入恢复', '粘贴备份', false, false, () => this.openImport())
    }
    .width('100%')
    .backgroundColor(this.th().surface)
    .borderRadius(18)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .clip(true)

    this.GroupLabel('关于')
    Column() {
      this.RowItem('shield', '隐私政策', '', false, false, () => {
        router.pushUrl({ url: 'pages/Privacy' });
      })
    }
    .width('100%')
    .backgroundColor(this.th().surface)
    .borderRadius(18)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .clip(true)
  }

  @Builder
  ArchivedGroup() {
    this.GroupLabel('已归档 (' + this.archived.length + ')')
    Column() {
      ForEach(this.archived, (h: Habit, idx: number) => {
        Column() {
          Row() {
            Stack() {
              Text(h.emoji).fontSize(17)
            }
            .width(34)
            .height(34)
            .borderRadius(10)
            .backgroundColor(h.color + (this.themeDark ? '2E' : '1F'))
            .margin({ right: 12 })
            Text(h.name)
              .fontSize(15)
              .fontColor(this.th().textPrimary)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('恢复')
              .fontSize(13.5)
              .fontColor(this.th().accent)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .onClick(() => this.restore(h))
            Text('删除')
              .fontSize(13.5)
              .fontColor(this.th().danger)
              .padding({ left: 10, right: 6, top: 6, bottom: 6 })
              .onClick(() => this.deleteForever(h))
          }
          .width('100%')
          .padding({ top: 9, bottom: 9, left: 14, right: 8 })
          if (idx < this.archived.length - 1) {
            Divider().color(this.th().divider).margin({ left: 60 })
          }
        }
        .width('100%')
      }, (h: Habit) => h.id)
    }
    .width('100%')
    .backgroundColor(this.th().surface)
    .borderRadius(18)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .clip(true)
  }

  @Builder
  About() {
    Column() {
      Text('习惯打卡 · v2.0')
        .fontSize(13)
        .fontColor(this.th().textTertiary)
      Text('坚持，是看得见的成长')
        .fontSize(12)
        .fontColor(this.th().textTertiary)
        .opacity(0.7)
        .margin({ top: 6 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: 30 })
  }
}
