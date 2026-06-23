import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { HabitStore } from '../model/HabitStore';
import { NotificationService } from '../model/NotificationService';
import { Habit } from '../model/Habit';
import { unlockedCount, ACHIEVEMENTS } from '../model/Achievement';
import { getTheme, AppTheme } from '../model/Theme';
import { AppIcon } from './AppIcon';

/** 我的页：总览 + 主题切换 + 成就 + 备份 + 排序 + 归档管理 */
@Component
export struct MineView {
  @Prop @Watch('onTick') tick: number;
  @StorageProp('themeDark') themeDark: boolean = false;
  @State activeNum: number = 0;
  @State archived: Habit[] = [];
  @State totalCheckins: number = 0;
  @State badges: number = 0;
  private store: HabitStore = HabitStore.getInstance();

  th(): AppTheme {
    return getTheme(this.themeDark);
  }

  aboutToAppear(): void {
    this.reload();
  }

  onTick(): void {
    this.reload();
  }

  reload(): void {
    this.activeNum = this.store.activeHabits().length;
    this.archived = this.store.archivedHabits().slice();
    let n: number = 0;
    this.store.habits.forEach((h: Habit) => n += h.checkedDates.length);
    this.totalCheckins = n;
    this.badges = unlockedCount(this.store.activeHabits());
  }

  async toggleTheme(dark: boolean): Promise<void> {
    AppStorage.setOrCreate('themeDark', dark);
    await this.store.setThemeDark(dark);
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

  async importData(): Promise<void> {
    try {
      const board: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      const data: pasteboard.PasteData = await board.getData();
      const text: string = data.getPrimaryText();
      if (!text || text.length === 0) {
        promptAction.showToast({ message: '剪贴板为空' });
        return;
      }
      const ok: boolean = await this.store.importFromJson(text);
      if (ok) {
        this.reload();
        promptAction.showToast({ message: '导入成功' });
      } else {
        promptAction.showToast({ message: '数据格式不正确' });
      }
    } catch (e) {
      promptAction.showToast({ message: '导入失败，请检查剪贴板内容' });
    }
  }

  confirmImport(): void {
    AlertDialog.show({
      title: '导入数据',
      message: '将用剪贴板中的备份覆盖当前全部数据，确定继续？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '覆盖导入',
        fontColor: this.th().danger,
        action: () => { this.importData(); }
      }
    });
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
    Column() {
      Text('我的')
        .fontSize(30)
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
  }

  @Builder
  SummaryCard() {
    Row() {
      this.SummaryItem(this.activeNum.toString(), '活跃习惯', this.th().accent)
      Divider().vertical(true).height(34).color(this.th().divider)
      this.SummaryItem(this.totalCheckins.toString(), '累计打卡', this.th().textPrimary)
      Divider().vertical(true).height(34).color(this.th().divider)
      this.SummaryItem(this.badges + '/' + ACHIEVEMENTS.length, '成就', this.th().accent)
    }
    .width('100%')
    .padding({ top: 22, bottom: 22 })
    .backgroundColor(this.th().surface)
    .borderRadius(22)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .shadow({ radius: this.th().shadowRadius, color: this.th().shadowColor, offsetX: 0, offsetY: 3 })
    .margin({ top: 4 })
  }

  @Builder
  SummaryItem(value: string, label: string, valueColor: string) {
    Column() {
      Text(value)
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
      Text(label).fontSize(12).fontColor(this.th().textSecondary).margin({ top: 5 })
    }
    .layoutWeight(1)
  }

  @Builder
  ThemeCard() {
    Row() {
      Column() {
        Stack() {
          Circle().width(38).height(38).fill(this.th().accentSoft)
          AppIcon({ name: this.themeDark ? 'moon' : 'sun', color: this.th().accent, iconSize: 22, cutout: this.th().accentSoft })
        }
        .margin({ right: 14 })
      }
      Column() {
        Text('深色模式')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.th().textPrimary)
        Text(this.themeDark ? '暗黑质感已开启' : '极简亮色已开启')
          .fontSize(12.5)
          .fontColor(this.th().textTertiary)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.themeDark })
        .selectedColor(this.th().accent)
        .onChange((on: boolean) => this.toggleTheme(on))
    }
    .width('100%')
    .padding({ top: 14, bottom: 14, left: 16, right: 16 })
    .backgroundColor(this.th().surface)
    .borderRadius(18)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .margin({ top: 14 })
  }

  @Builder
  RowItem(icon: string, label: string, trailing: string, showDivider: boolean, action: () => void) {
    Column() {
      Row() {
        Stack() {
          Circle().width(34).height(34).fill(this.th().surfaceAlt)
          AppIcon({ name: icon, color: this.th().textSecondary, iconSize: 19, stroke: 1.9, cutout: this.th().surfaceAlt })
        }
        .margin({ right: 13 })
        Text(label).fontSize(15.5).fontColor(this.th().textPrimary).layoutWeight(1)
        if (trailing.length > 0) {
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
      this.RowItem('trophy', '我的成就', this.badges + '/' + ACHIEVEMENTS.length, true, () => {
        router.pushUrl({ url: 'pages/Achievements' });
      })
      this.RowItem('reorder', '习惯排序', '', false, () => {
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
      this.RowItem('bell', '开启通知权限', '', true, () => this.enableNotification())
      this.RowItem('upload', '导出备份', '复制到剪贴板', true, () => this.exportData())
      this.RowItem('download', '导入恢复', '从剪贴板', false, () => this.confirmImport())
    }
    .width('100%')
    .backgroundColor(this.th().surface)
    .borderRadius(18)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .clip(true)

    this.GroupLabel('关于')
    Column() {
      this.RowItem('shield', '隐私政策', '', false, () => {
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
              Circle().width(34).height(34).fill(h.color + (this.themeDark ? '2E' : '1F'))
              Text(h.emoji).fontSize(17)
            }
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
