import { router } from '@kit.ArkUI';
import { HabitStore } from '../model/HabitStore';
import { Habit, currentStreak, frequencyLabel, isScheduledToday, todayStr,
  isQuantifiable, valueToday, TimeOfDay, timeOfDayLabel, timeOfDayIcon,
  addDays, parseDate, toDateStr } from '../model/Habit';
import { getTheme, AppTheme } from '../model/Theme';
import { AppIcon } from './AppIcon';
import { EmptyArt } from './EmptyArt';

/** 周日历单元格数据 */
class DayCell {
  weekLabel: string;   // 周几（短名）
  dayNum: string;      // 日期数字
  isToday: boolean;
  dateStr: string;

  constructor(weekLabel: string, dayNum: string, isToday: boolean, dateStr: string) {
    this.weekLabel = weekLabel;
    this.dayNum = dayNum;
    this.isToday = isToday;
    this.dateStr = dateStr;
  }
}

/** 时段分组 */
class Section {
  key: TimeOfDay;
  habits: Habit[];

  constructor(key: TimeOfDay, habits: Habit[]) {
    this.key = key;
    this.habits = habits;
  }
}

/** 列表行：表头 / 习惯卡 / 底部切换。扁平成单一数组，避免 List 内嵌套 ForEach 的渲染丢失 */
class ListRow {
  kind: string;          // 'header' | 'habit' | 'toggle'
  key: string;           // ForEach 稳定主键
  sectionKey: TimeOfDay; // kind==='header' 时有效
  habit: Habit | null;   // kind==='habit' 时有效

  constructor(kind: string, key: string, sectionKey: TimeOfDay, habit: Habit | null) {
    this.kind = kind;
    this.key = key;
    this.sectionKey = sectionKey;
    this.habit = habit;
  }
}

/** 今日页：展示今天需要打卡的习惯 + 今日进度，按时段分组 */
@Component
export struct TodayView {
  @Prop @Watch('onTick') tick: number;
  @StorageProp('dataVersion') @Watch('onTick') dataVersion: number = 0;
  @StorageProp('themeDark') themeDark: boolean = false;
  @State habits: Habit[] = [];
  @State showAll: boolean = false;
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
    this.habits = this.store.activeHabits().slice();
  }

  dueHabits(): Habit[] {
    if (this.showAll) {
      return this.habits;
    }
    return this.habits.filter((h: Habit) => isScheduledToday(h));
  }

  sections(): Section[] {
    const order: TimeOfDay[] = ['morning', 'afternoon', 'evening', 'anytime'];
    const due: Habit[] = this.dueHabits();
    const result: Section[] = [];
    order.forEach((key: TimeOfDay) => {
      const list: Habit[] = due.filter((h: Habit) => h.timeOfDay === key);
      if (list.length > 0) {
        result.push(new Section(key, list));
      }
    });
    return result;
  }

  showSectionHeader(): boolean {
    const secs: Section[] = this.sections();
    return secs.length > 1 || (secs.length === 1 && secs[0].key !== 'anytime');
  }

  /** 把分组扁平成单一行数组：表头 + 各习惯卡 + 末尾切换行 */
  rows(): ListRow[] {
    const secs: Section[] = this.sections();
    const showHeader: boolean = this.showSectionHeader();
    const out: ListRow[] = [];
    secs.forEach((sec: Section) => {
      if (showHeader) {
        out.push(new ListRow('header', 'h_' + sec.key, sec.key, null));
      }
      sec.habits.forEach((h: Habit) => {
        // key 只用 id：保持卡片节点稳定，使打卡时环形进度从旧值平滑过渡而非从 0 重建
        const k: string = 'c_' + h.id;
        out.push(new ListRow('habit', k, sec.key, h));
      });
    });
    out.push(new ListRow('toggle', 'toggle_' + (this.showAll ? '1' : '0'), 'anytime', null));
    return out;
  }

  /** 该时段的打卡签名：任一习惯打卡/进度变化都会改变它，强制整段重建 */
  sectionSig(sec: Section): string {
    return sec.habits.map((h: Habit) =>
      h.id + ':' + h.checkedDates.length + ':' + valueToday(h)).join('|');
  }

  isCheckedToday(h: Habit): boolean {
    return h.checkedDates.indexOf(todayStr()) >= 0;
  }

  doneCount(): number {
    const today: string = todayStr();
    let n: number = 0;
    this.dueHabits().forEach((h: Habit) => {
      if (h.checkedDates.indexOf(today) >= 0) {
        n++;
      }
    });
    return n;
  }

  progress(): number {
    const total: number = this.dueHabits().length;
    if (total === 0) {
      return 0;
    }
    return this.doneCount() / total;
  }

  async toggle(h: Habit): Promise<void> {
    await this.store.toggleToday(h.id);
    this.reload();
  }

  async addOne(h: Habit): Promise<void> {
    await this.store.addValue(h.id, 1);
    this.reload();
  }

  todayLabel(): string {
    const d: Date = new Date();
    const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${d.getMonth() + 1}月${d.getDate()}日 · ${week[d.getDay()]}`;
  }

  /** 本周日历：今天前 5 天 + 今天 + 明天，共 7 格 */
  weekCells(): DayCell[] {
    const week: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    const today: string = todayStr();
    const cells: DayCell[] = [];
    for (let i = -5; i <= 1; i++) {
      const ds: string = addDays(today, i);
      const d: Date = parseDate(ds);
      cells.push(new DayCell(week[d.getDay()], d.getDate().toString(), ds === today, ds));
    }
    return cells;
  }

  /** 今天还差几个未完成 */
  remainCount(): number {
    return this.dueHabits().length - this.doneCount();
  }

  /** 进度卡副标题文案 */
  progressHint(): string {
    const remain: number = this.remainCount();
    if (this.dueHabits().length === 0) {
      return '今天没有需要打卡的习惯';
    }
    if (remain <= 0) {
      return '今日全部完成，继续保持 🎉';
    }
    return '坚持得不错，继续保持节奏 👏';
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.Header()
        if (this.habits.length === 0) {
          this.EmptyState()
        } else {
          this.Body()
        }
      }
      .width('100%')
      .height('100%')

      Button({ type: ButtonType.Circle }) {
        AppIcon({ name: 'plus', color: this.th().accentText, iconSize: 24, stroke: 2.4 })
      }
      .width(52)
      .height(52)
      .backgroundColor(this.th().accent)
      .shadow({ radius: 16, color: this.th().accent + '55', offsetX: 0, offsetY: 8 })
      .margin({ right: 20, bottom: 22 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/EditHabit' });
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  Header() {
    Column() {
      Text(this.todayLabel())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.th().textSecondary)
        .letterSpacing(0.3)
      Text('今天')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.th().textPrimary)
        .letterSpacing(0.2)
        .width('100%')
        .margin({ top: 4 })

      this.WeekStrip()

      if (this.dueHabits().length > 0) {
        this.ProgressCard()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 22, right: 22, top: 18, bottom: 14 })
  }

  @Builder
  WeekStrip() {
    Row() {
      ForEach(this.weekCells(), (c: DayCell) => {
        Column() {
          Text(c.weekLabel)
            .fontSize(12)
            .fontWeight(c.isToday ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(c.isToday ? this.th().accent : this.th().textTertiary)
          Text(c.dayNum)
            .fontSize(15)
            .fontWeight(c.isToday ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(c.isToday ? this.th().accentText : this.th().textSecondary)
            .width('100%')
            .height(30)
            .borderRadius(10)
            .textAlign(TextAlign.Center)
            .backgroundColor(c.isToday ? this.th().accent : '#00000000')
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .padding({ left: 3, right: 3 })
      }, (c: DayCell) => c.dateStr)
    }
    .width('100%')
    .margin({ top: 14 })
  }

  @Builder
  ProgressCard() {
    Row() {
      Stack() {
        Progress({ value: this.doneCount(), total: this.dueHabits().length, type: ProgressType.Ring })
          .width(72)
          .height(72)
          .color(this.remainCount() <= 0 ? this.th().success : this.th().accent)
          .style({ strokeWidth: 7 })
          .backgroundColor(this.th().track)
        Column() {
          Text(this.doneCount() + '/' + this.dueHabits().length)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.th().textPrimary)
          Text('已完成')
            .fontSize(10)
            .fontColor(this.th().textTertiary)
            .margin({ top: 2 })
        }
      }
      .margin({ right: 18 })

      Column() {
        Text(this.remainCount() <= 0 ? '今天全部完成' : '今天还差 ' + this.remainCount() + ' 个')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.th().textPrimary)
        Text(this.progressHint())
          .fontSize(13)
          .fontColor(this.th().textSecondary)
          .margin({ top: 5 })
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.th().surface)
    .borderRadius(22)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .shadow({ radius: this.th().shadowRadius, color: this.th().shadowColor, offsetX: 0, offsetY: 3 })
    .margin({ top: 16 })
  }

  @Builder
  EmptyState() {
    Column() {
      EmptyArt({ kind: 'sprout', accent: this.th().accent })
      Text('开始你的第一个习惯')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.th().textPrimary)
        .margin({ top: 20 })
      Text('点击右下角按钮，添加想坚持的事')
        .fontSize(14)
        .fontColor(this.th().textTertiary)
        .margin({ top: 8 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  Body() {
    Scroll() {
      Column({ space: 11 }) {
        ForEach(this.rows(), (row: ListRow) => {
          if (row.kind === 'header') {
            Row() {
              Text(timeOfDayIcon(row.sectionKey)).fontSize(14).margin({ right: 5 })
              Text(timeOfDayLabel(row.sectionKey))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.th().textSecondary)
                .letterSpacing(0.5)
            }
            .width('100%')
            .padding({ top: 8, bottom: 2, left: 4 })
          } else if (row.kind === 'habit' && row.habit !== null) {
            HabitCardItem({
              habit: row.habit,
              themeDark: this.themeDark,
              onToggle: (h: Habit): void => { this.toggle(h); },
              onAddOne: (h: Habit): void => { this.addOne(h); }
            })
          } else {
            Row() {
              Text(this.showAll ? '只看今天' : '查看全部习惯')
                .fontSize(14)
                .fontColor(this.th().textTertiary)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 10, bottom: 10 })
            .onClick(() => this.showAll = !this.showAll)
          }
        }, (row: ListRow) => row.key)
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 6, bottom: 120 })
    }
    .layoutWeight(1)
    .width('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }
}

/**
 * 习惯卡片：独立 @Component + @ObjectLink 观测单个 Habit，
 * 打卡时只更新本卡片节点（环形进度原地从旧值平滑过渡，而非整卡重建从 0 起跳）。
 */
@Component
struct HabitCardItem {
  @ObjectLink habit: Habit;
  @Prop themeDark: boolean;
  onToggle: (h: Habit) => void = () => {};
  onAddOne: (h: Habit) => void = () => {};
  @State popScale: number = 1;

  th(): AppTheme {
    return getTheme(this.themeDark);
  }

  isCheckedToday(): boolean {
    return this.habit.checkedDates.indexOf(todayStr()) >= 0;
  }

  /** 完成时播放一次轻微弹动反馈 */
  playPop(): void {
    this.popScale = 1;
    animateTo({ duration: 130, curve: Curve.EaseOut }, () => {
      this.popScale = 1.25;
    });
    setTimeout(() => {
      animateTo({ duration: 180, curve: Curve.Friction }, () => {
        this.popScale = 1;
      });
    }, 130);
  }

  build() {
    Row() {
      Row() {
        Stack() {
          Text(this.habit.emoji).fontSize(21)
        }
        .width(42)
        .height(42)
        .borderRadius(13)
        .backgroundColor(this.habit.color + (this.themeDark ? '2E' : '1F'))
        .margin({ right: 13 })

        Column() {
          Text(this.habit.name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.th().textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row() {
            if (isQuantifiable(this.habit)) {
              Text(valueToday(this.habit) + ' / ' + this.habit.targetCount +
                (this.habit.unit.length > 0 ? ' ' + this.habit.unit : ''))
                .fontSize(12)
                .fontColor(this.isCheckedToday() ? this.th().success : this.habit.color)
            } else {
              Text('已坚持 ' + currentStreak(this.habit) + ' 天')
                .fontSize(12)
                .fontColor(this.th().textTertiary)
            }
            Text('  ·  ' + frequencyLabel(this.habit))
              .fontSize(12)
              .fontColor(this.th().textTertiary)
          }
          .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .onClick(() => {
        router.pushUrl({ url: 'pages/HabitDetail', params: { id: this.habit.id } });
      })

      if (isQuantifiable(this.habit)) {
        this.QuantControl()
      } else {
        this.CheckButton()
      }
    }
    .width('100%')
    .padding({ top: 11, bottom: 11, left: 13, right: 13 })
    .backgroundColor(this.th().surface)
    .borderRadius(16)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .shadow({ radius: this.th().shadowRadius, color: this.th().shadowColor, offsetX: 0, offsetY: 3 })
    .opacity(this.isCheckedToday() ? 0.62 : 1)
  }

  @Builder
  CheckButton() {
    Stack() {
      Circle()
        .width(32)
        .height(32)
        .fill(this.isCheckedToday() ? this.habit.color : '#00000000')
        .stroke(this.isCheckedToday() ? this.habit.color : this.th().divider)
        .strokeWidth(2)
      if (this.isCheckedToday()) {
        Text('✓').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
      }
    }
    .margin({ left: 12 })
    .scale({ x: this.popScale, y: this.popScale })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
    .onClick(() => {
      const was: boolean = this.isCheckedToday();
      this.onToggle(this.habit);
      if (!was) {
        this.playPop();
      }
    })
  }

  @Builder
  QuantControl() {
    Stack() {
      Progress({ value: valueToday(this.habit), total: this.habit.targetCount, type: ProgressType.Ring })
        .width(34)
        .height(34)
        .color(this.habit.color)
        .style({ strokeWidth: 3 })
        .backgroundColor(this.th().track)
      if (this.isCheckedToday()) {
        Circle().width(34).height(34).fill(this.habit.color)
        Text('✓').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
      } else {
        Text(valueToday(this.habit) + '/' + this.habit.targetCount)
          .fontSize(this.habit.targetCount > 99 ? 8 : 9)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.habit.color)
      }
    }
    .margin({ left: 12 })
    .scale({ x: this.popScale, y: this.popScale })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
    .onClick(() => {
      const was: boolean = this.isCheckedToday();
      this.onAddOne(this.habit);
      if (!was && this.isCheckedToday()) {
        this.playPop();
      }
    })
  }
}
