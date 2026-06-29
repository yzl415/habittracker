import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { HabitStore } from '../model/HabitStore';
import { NotificationService } from '../model/NotificationService';
import { Habit, HABIT_COLORS, HABIT_EMOJIS, WEEK_SHORT, FrequencyType, TimeOfDay,
  HABIT_TEMPLATES, HabitTemplate, timeOfDayLabel, todayStr } from '../model/Habit';
import { getTheme, AppTheme } from '../model/Theme';

interface EditParams {
  id?: string;
}

@Entry
@Component
struct EditHabit {
  @StorageProp('themeDark') themeDark: boolean = false;
  @State name: string = '';
  @State emoji: string = HABIT_EMOJIS[0];
  @State color: string = HABIT_COLORS[0];
  @State frequency: FrequencyType = 'daily';
  @State weekdays: number[] = [1, 2, 3, 4, 5];
  @State reminderEnabled: boolean = false;
  @State reminderTime: string = '20:00';
  @State targetCount: number = 1;
  @State unit: string = '';
  @State timeOfDay: TimeOfDay = 'anytime';
  @State editingId: string = '';
  @State isCountMode: boolean = false;        // 打卡(false) / 计数(true)
  @State freqMode: string = 'daily';          // daily / workday / weekend / custom
  @State nameFocused: boolean = false;
  private store: HabitStore = HabitStore.getInstance();

  th(): AppTheme {
    return getTheme(this.themeDark);
  }

  aboutToAppear(): void {
    const params = router.getParams() as EditParams;
    if (params && params.id) {
      const h: Habit | undefined = this.store.getById(params.id);
      if (h !== undefined) {
        this.editingId = h.id;
        this.name = h.name;
        this.emoji = h.emoji;
        this.color = h.color;
        this.frequency = h.frequency;
        this.weekdays = h.weekdays.length > 0 ? h.weekdays.slice() : [1, 2, 3, 4, 5];
        this.reminderEnabled = h.reminderEnabled;
        this.reminderTime = h.reminderTime;
        this.targetCount = h.targetCount;
        this.unit = h.unit;
        this.timeOfDay = h.timeOfDay;
        this.isCountMode = h.targetCount > 1;
        this.freqMode = this.deriveFreqMode(h.frequency, h.weekdays);
      }
    }
  }

  /** 由已有 frequency + weekdays 推断 UI 频率模式 */
  deriveFreqMode(freq: FrequencyType, days: number[]): string {
    if (freq === 'daily') {
      return 'daily';
    }
    const sorted: string = days.slice().sort((a: number, b: number) => a - b).join();
    if (sorted === '1,2,3,4,5') {
      return 'workday';
    }
    if (sorted === '0,6') {
      return 'weekend';
    }
    return 'custom';
  }

  /** 选择频率快捷模式：同步 frequency 与 weekdays */
  selectFreqMode(mode: string): void {
    this.freqMode = mode;
    if (mode === 'daily') {
      this.frequency = 'daily';
    } else if (mode === 'workday') {
      this.frequency = 'weekly';
      this.weekdays = [1, 2, 3, 4, 5];
    } else if (mode === 'weekend') {
      this.frequency = 'weekly';
      this.weekdays = [0, 6];
    } else {
      this.frequency = 'weekly';
    }
  }

  isEditing(): boolean {
    return this.editingId.length > 0;
  }

  applyTemplate(t: HabitTemplate): void {
    this.name = t.name;
    this.emoji = t.emoji;
    this.color = t.color;
    this.targetCount = t.targetCount;
    this.unit = t.unit;
    this.isCountMode = t.targetCount > 1;
  }

  /** 实际保存的目标数：打卡模式恒为 1 */
  effectiveTarget(): number {
    if (!this.isCountMode) {
      return 1;
    }
    return this.targetCount < 1 ? 1 : this.targetCount;
  }

  toggleWeekday(d: number): void {
    const idx: number = this.weekdays.indexOf(d);
    if (idx >= 0) {
      this.weekdays.splice(idx, 1);
    } else {
      this.weekdays.push(d);
    }
    this.weekdays = this.weekdays.slice();
  }

  async save(): Promise<void> {
    if (this.name.trim().length === 0) {
      promptAction.showToast({ message: '请输入习惯名称' });
      return;
    }
    if (this.frequency === 'weekly' && this.weekdays.length === 0) {
      promptAction.showToast({ message: '请至少选择一天' });
      return;
    }
    try {
      let habit: Habit;
      if (this.isEditing()) {
        const h: Habit | undefined = this.store.getById(this.editingId);
        if (h === undefined) {
          router.back();
          return;
        }
        h.name = this.name.trim();
        h.emoji = this.emoji;
        h.color = this.color;
        h.frequency = this.frequency;
        h.weekdays = this.frequency === 'weekly' ? this.weekdays.slice() : [];
        h.reminderEnabled = this.reminderEnabled;
        h.reminderTime = this.reminderTime;
        h.targetCount = this.effectiveTarget();
        h.unit = this.isCountMode ? this.unit.trim() : '';
        h.timeOfDay = this.timeOfDay;
        habit = h;
        await this.store.update(h);
      } else {
        const id: string = Date.now().toString();
        habit = new Habit(id, this.name.trim(), this.emoji, this.color,
          todayStr(), [], this.frequency,
          this.frequency === 'weekly' ? this.weekdays.slice() : [],
          this.reminderEnabled, this.reminderTime, -1, false, 0,
          this.effectiveTarget(), this.isCountMode ? this.unit.trim() : '', {}, this.timeOfDay);
        await this.store.add(habit);
      }
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const newId: number = await NotificationService.schedule(habit, ctx);
      habit.reminderId = newId;
      await this.store.save();
      router.back();
    } catch (e) {
      promptAction.showToast({ message: '保存失败：' + JSON.stringify(e) });
    }
  }

  async confirmArchive(): Promise<void> {
    const h: Habit | undefined = this.store.getById(this.editingId);
    if (h !== undefined) {
      await NotificationService.cancel(h.reminderId);
      h.reminderId = -1;
      h.reminderEnabled = false;
    }
    await this.store.setArchived(this.editingId, true);
    promptAction.showToast({ message: '已归档，可在「我的」中恢复' });
    router.back();
  }

  cardBorderWidth(): number {
    return this.themeDark ? 1 : 0;
  }

  build() {
    Column() {
      this.NavBar()
      Scroll() {
        Column() {
          if (!this.isEditing()) {
            this.Templates()
          }
          this.NameField()
          this.EmojiPicker()
          this.ColorPicker()
          this.TargetSection()
          this.TimeOfDayPicker()
          this.FrequencyPicker()
          this.ReminderSection()
          if (this.isEditing()) {
            this.ArchiveButton()
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 32 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.th().bg)
  }

  @Builder
  NavBar() {
    Row() {
      Text('取消')
        .fontSize(16)
        .fontColor(this.th().textSecondary)
        .onClick(() => router.back())
      Text(this.isEditing() ? '编辑习惯' : '新建习惯')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.th().textPrimary)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('保存')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.th().accent)
        .onClick(() => this.save())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
  }

  @Builder
  SectionLabel(text: string) {
    Text(text)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.th().textTertiary)
      .letterSpacing(0.5)
      .width('100%')
      .margin({ top: 22, bottom: 10, left: 2 })
  }

  @Builder
  Templates() {
    Text('快速选择')
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.th().textTertiary)
      .letterSpacing(0.5)
      .width('100%')
      .margin({ top: 12, bottom: 10, left: 2 })
    Scroll() {
      Row({ space: 10 }) {
        ForEach(HABIT_TEMPLATES, (t: HabitTemplate) => {
          Row() {
            Text(t.emoji).fontSize(17).margin({ right: 6 })
            Text(t.name).fontSize(14).fontColor(this.th().textPrimary)
          }
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor(this.th().surface)
          .borderRadius(20)
          .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
          .onClick(() => this.applyTemplate(t))
        }, (t: HabitTemplate) => t.name)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  NameField() {
    Row() {
      Stack() {
        Text(this.emoji).fontSize(24)
      }
      .width(44)
      .height(44)
      .borderRadius(13)
      .backgroundColor(this.color + (this.themeDark ? '2E' : '1F'))
      .margin({ right: 14 })
      TextInput({ text: this.name, placeholder: '习惯名称' })
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.th().textPrimary)
        .placeholderColor(this.th().textTertiary)
        .backgroundColor('#00000000')
        .borderRadius(0)
        .height(44)
        .padding({ left: 0, right: 0, top: 0, bottom: 0 })
        .maxLength(20)
        .layoutWeight(1)
        .onFocus(() => this.nameFocused = true)
        .onBlur(() => this.nameFocused = false)
        .onChange((v: string) => this.name = v)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(13)
    .backgroundColor(this.th().surface)
    .borderRadius(18)
    .border({
      width: this.nameFocused ? 2 : this.cardBorderWidth(),
      color: this.nameFocused ? this.th().accent : this.th().cardBorder
    })
    .margin({ top: 8 })
  }

  @Builder
  EmojiPicker() {
    this.SectionLabel('图标')
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(HABIT_EMOJIS, (e: string) => {
        Column() {
          Stack() {
            Circle()
              .width(46)
              .height(46)
              .fill(this.emoji === e ? this.color + (this.themeDark ? '33' : '22') : this.th().surface)
              .stroke(this.emoji === e ? this.color : this.th().cardBorder)
              .strokeWidth(this.emoji === e ? 2 : (this.themeDark ? 1 : 0))
            Text(e).fontSize(22)
          }
        }
        .width('16.66%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 12 })
        .onClick(() => this.emoji = e)
      }, (e: string) => e)
    }
    .width('100%')
  }

  @Builder
  ColorPicker() {
    this.SectionLabel('颜色')
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(HABIT_COLORS, (c: string) => {
        Column() {
          Stack() {
            Circle().width(40).height(40).fill(c)
            if (this.color === c) {
              Text('✓').fontSize(18).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
            }
          }
        }
        .width('16.66%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 12 })
        .onClick(() => this.color = c)
      }, (c: string) => c)
    }
    .width('100%')
  }

  @Builder
  ModeTab(label: string, count: boolean) {
    Text(label)
      .fontSize(15)
      .fontColor(this.isCountMode === count ? this.th().accentText : this.th().textSecondary)
      .fontWeight(this.isCountMode === count ? FontWeight.Medium : FontWeight.Normal)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(38)
      .borderRadius(10)
      .backgroundColor(this.isCountMode === count ? this.th().accent : '#00000000')
      .onClick(() => this.isCountMode = count)
  }

  @Builder
  TargetSection() {
    this.SectionLabel('每日目标')
    Row() {
      this.ModeTab('打卡', false)
      this.ModeTab('计数', true)
    }
    .width('100%')
    .padding(4)
    .backgroundColor(this.th().surface)
    .borderRadius(14)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })

    if (this.isCountMode) {
      Row() {
        Text('目标数量')
          .fontSize(16)
          .fontColor(this.th().textPrimary)
          .layoutWeight(1)
        Text('−')
          .fontSize(22)
          .fontColor(this.targetCount > 1 ? this.th().accent : this.th().textTertiary)
          .width(38)
          .height(34)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.th().surfaceAlt)
          .borderRadius(10)
          .onClick(() => {
            if (this.targetCount > 1) {
              this.targetCount--;
            }
          })
        Text(this.targetCount + (this.unit.length > 0 ? ' ' + this.unit : ''))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.th().textPrimary)
          .constraintSize({ minWidth: 56 })
          .textAlign(TextAlign.Center)
        Text('+')
          .fontSize(22)
          .fontColor(this.th().accent)
          .width(38)
          .height(34)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.th().surfaceAlt)
          .borderRadius(10)
          .onClick(() => this.targetCount++)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.th().surface)
      .borderRadius(14)
      .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
      .margin({ top: 10 })

      TextInput({ text: this.unit, placeholder: '单位（如 杯 / 分钟 / 页），可留空' })
        .fontSize(15)
        .height(48)
        .fontColor(this.th().textPrimary)
        .placeholderColor(this.th().textTertiary)
        .backgroundColor(this.th().surface)
        .borderRadius(14)
        .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
        .padding({ left: 16, right: 16 })
        .maxLength(6)
        .margin({ top: 10 })
        .onChange((v: string) => this.unit = v)
    }
  }

  @Builder
  TodTab(t: TimeOfDay) {
    Text(timeOfDayLabel(t))
      .fontSize(14)
      .fontColor(this.timeOfDay === t ? this.th().accentText : this.th().textSecondary)
      .fontWeight(this.timeOfDay === t ? FontWeight.Medium : FontWeight.Normal)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .padding({ top: 9, bottom: 9 })
      .backgroundColor(this.timeOfDay === t ? this.th().accent : '#00000000')
      .borderRadius(11)
      .onClick(() => this.timeOfDay = t)
  }

  @Builder
  TimeOfDayPicker() {
    this.SectionLabel('时段')
    Row({ space: 6 }) {
      this.TodTab('anytime')
      this.TodTab('morning')
      this.TodTab('afternoon')
      this.TodTab('evening')
    }
    .width('100%')
    .padding(4)
    .backgroundColor(this.th().surface)
    .borderRadius(14)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
  }

  @Builder
  FreqTab(label: string, mode: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.freqMode === mode ? this.th().accentText : this.th().textSecondary)
      .fontWeight(this.freqMode === mode ? FontWeight.Medium : FontWeight.Normal)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(38)
      .borderRadius(10)
      .backgroundColor(this.freqMode === mode ? this.th().accent : '#00000000')
      .onClick(() => this.selectFreqMode(mode))
  }

  @Builder
  FrequencyPicker() {
    this.SectionLabel('频率')
    Row({ space: 4 }) {
      this.FreqTab('每天', 'daily')
      this.FreqTab('工作日', 'workday')
      this.FreqTab('周末', 'weekend')
      this.FreqTab('自定义', 'custom')
    }
    .width('100%')
    .padding(4)
    .backgroundColor(this.th().surface)
    .borderRadius(14)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })

    if (this.freqMode === 'custom') {
      Row() {
        ForEach([0, 1, 2, 3, 4, 5, 6], (d: number) => {
          Stack() {
            Circle()
              .width(40)
              .height(40)
              .fill(this.weekdays.indexOf(d) >= 0 ? this.color : this.th().surface)
              .stroke(this.weekdays.indexOf(d) >= 0 ? this.color : this.th().cardBorder)
              .strokeWidth(this.themeDark ? 1 : 0)
            Text(WEEK_SHORT[d])
              .fontSize(14)
              .fontColor(this.weekdays.indexOf(d) >= 0 ? '#FFFFFF' : this.th().textSecondary)
          }
          .onClick(() => this.toggleWeekday(d))
        }, (d: number) => d.toString())
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 12 })
    }
  }

  @Builder
  ReminderSection() {
    this.SectionLabel('提醒')
    Column() {
      Row() {
        Text('每日提醒').fontSize(16).fontColor(this.th().textPrimary).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.reminderEnabled })
          .selectedColor(this.th().accent)
          .onChange((on: boolean) => this.reminderEnabled = on)
      }
      .width('100%')
      .padding({ top: 14, bottom: 14, left: 16, right: 16 })

      if (this.reminderEnabled) {
        Divider().color(this.th().divider)
        Row() {
          Text('提醒时间').fontSize(16).fontColor(this.th().textPrimary).layoutWeight(1)
          Text(this.reminderTime).fontSize(16).fontColor(this.th().accent)
        }
        .width('100%')
        .padding({ top: 14, bottom: 14, left: 16, right: 16 })
        .onClick(() => this.openTimePicker())
      }
    }
    .width('100%')
    .backgroundColor(this.th().surface)
    .borderRadius(14)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
  }

  openTimePicker(): void {
    const parts: string[] = this.reminderTime.split(':');
    TimePickerDialog.show({
      selected: new Date(2024, 0, 1, Number(parts[0]), Number(parts[1])),
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        const h: number = value.hour;
        const m: number = value.minute;
        const hh: string = h < 10 ? '0' + h : '' + h;
        const mm: string = m < 10 ? '0' + m : '' + m;
        this.reminderTime = hh + ':' + mm;
      }
    });
  }

  @Builder
  ArchiveButton() {
    Button('归档习惯')
      .width('100%')
      .height(50)
      .fontSize(16)
      .fontColor(this.th().warn)
      .backgroundColor(this.th().surface)
      .borderRadius(14)
      .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
      .margin({ top: 28, bottom: 8 })
      .onClick(() => this.confirmArchive())
    Text('归档后会保留历史记录，可随时恢复')
      .fontSize(12)
      .fontColor(this.th().textTertiary)
      .width('100%')
      .textAlign(TextAlign.Center)
  }
}
