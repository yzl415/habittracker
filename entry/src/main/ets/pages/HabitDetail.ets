import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { HabitStore } from '../model/HabitStore';
import { Habit, currentStreak, longestStreak, completionRate, frequencyLabel,
  isScheduledOn, toDateStr, todayStr, addDays, isQuantifiable, valueToday } from '../model/Habit';
import { getTheme, AppTheme } from '../model/Theme';

interface DetailParams {
  id?: string;
}

class DayCell {
  day: number;
  dateStr: string;
  checked: boolean;
  scheduled: boolean;

  constructor(day: number, dateStr: string, checked: boolean, scheduled: boolean) {
    this.day = day;
    this.dateStr = dateStr;
    this.checked = checked;
    this.scheduled = scheduled;
  }
}

class HeatCell {
  dateStr: string;
  level: number;

  constructor(dateStr: string, level: number) {
    this.dateStr = dateStr;
    this.level = level;
  }
}

@Entry
@Component
struct HabitDetail {
  @StorageProp('themeDark') themeDark: boolean = false;
  @State habit: Habit | null = null;
  @State year: number = new Date().getFullYear();
  @State month: number = new Date().getMonth();
  @State refreshKey: number = 0;
  @State todayVal: number = 0;
  private store: HabitStore = HabitStore.getInstance();

  th(): AppTheme {
    return getTheme(this.themeDark);
  }

  aboutToAppear(): void {
    const params = router.getParams() as DetailParams;
    if (params && params.id) {
      const h: Habit | undefined = this.store.getById(params.id);
      this.habit = h !== undefined ? h : null;
      if (this.habit !== null) {
        this.todayVal = valueToday(this.habit);
      }
    }
  }

  async onTapDay(cell: DayCell): Promise<void> {
    if (this.habit === null || cell.day === 0) {
      return;
    }
    if (cell.dateStr > todayStr()) {
      promptAction.showToast({ message: '不能给未来打卡哦' });
      return;
    }
    await this.store.setChecked(this.habit.id, cell.dateStr, !cell.checked);
    this.todayVal = valueToday(this.habit);
    this.refreshKey++;
  }

  /** 量化习惯：今日进度增减 */
  async changeToday(delta: number): Promise<void> {
    if (this.habit === null) {
      return;
    }
    await this.store.addValue(this.habit.id, delta);
    this.todayVal = valueToday(this.habit);
    this.refreshKey++;
  }

  buildCells(): DayCell[] {
    const cells: DayCell[] = [];
    if (this.habit === null) {
      return cells;
    }
    const h: Habit = this.habit;
    const checkedSet: Set<string> = new Set(h.checkedDates);
    const firstDay: number = new Date(this.year, this.month, 1).getDay();
    const daysInMonth: number = new Date(this.year, this.month + 1, 0).getDate();
    for (let i = 0; i < firstDay; i++) {
      cells.push(new DayCell(0, '', false, false));
    }
    for (let d = 1; d <= daysInMonth; d++) {
      const ds: string = toDateStr(new Date(this.year, this.month, d));
      cells.push(new DayCell(d, ds, checkedSet.has(ds), isScheduledOn(h, ds)));
    }
    return cells;
  }

  buildHeat(): HeatCell[] {
    const cells: HeatCell[] = [];
    if (this.habit === null) {
      return cells;
    }
    const checkedSet: Set<string> = new Set(this.habit.checkedDates);
    const today: string = todayStr();
    const weeks: number = 17;
    const todayWeekday: number = new Date().getDay();
    const lastSunday: string = addDays(today, -todayWeekday);
    const start: string = addDays(lastSunday, -(weeks - 1) * 7);
    for (let w = 0; w < weeks; w++) {
      for (let d = 0; d < 7; d++) {
        const ds: string = addDays(start, w * 7 + d);
        if (ds > today) {
          cells.push(new HeatCell(ds, -1));
        } else {
          cells.push(new HeatCell(ds, checkedSet.has(ds) ? 1 : 0));
        }
      }
    }
    return cells;
  }

  prevMonth(): void {
    if (this.month === 0) {
      this.month = 11;
      this.year--;
    } else {
      this.month--;
    }
  }

  nextMonth(): void {
    if (this.month === 11) {
      this.month = 0;
      this.year++;
    } else {
      this.month++;
    }
  }

  cardBorderWidth(): number {
    return this.themeDark ? 1 : 0;
  }

  build() {
    Column() {
      this.NavBar()
      if (this.habit !== null) {
        Scroll() {
          Column() {
            this.HeroCard()
            if (isQuantifiable(this.habit as Habit)) {
              this.TodayProgress()
            }
            this.StatsRow()
            this.Heatmap()
            this.Calendar()
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 28 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.th().bg)
  }

  @Builder
  NavBar() {
    Row() {
      Text('‹ 返回')
        .fontSize(16)
        .fontColor(this.th().accent)
        .onClick(() => router.back())
        .layoutWeight(1)
      Text('编辑')
        .fontSize(16)
        .fontColor(this.th().accent)
        .onClick(() => {
          if (this.habit !== null) {
            router.pushUrl({ url: 'pages/EditHabit', params: { id: this.habit.id } });
          }
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 10 })
  }

  @Builder
  HeroCard() {
    Column() {
      Stack() {
        Circle().width(72).height(72).fill((this.habit as Habit).color + (this.themeDark ? '2E' : '1F'))
        Text((this.habit as Habit).emoji).fontSize(34)
      }
      Text((this.habit as Habit).name)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.th().textPrimary)
        .margin({ top: 12 })
      Row() {
        Text('🔥 当前连续 ' + currentStreak(this.habit as Habit) + ' 天')
          .fontSize(14)
          .fontColor((this.habit as Habit).color)
        Text('  ·  ' + frequencyLabel(this.habit as Habit))
          .fontSize(14)
          .fontColor(this.th().textTertiary)
      }
      .margin({ top: 6 })
    }
    .width('100%')
    .padding({ top: 24, bottom: 24 })
    .backgroundColor(this.th().surface)
    .borderRadius(22)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
    .margin({ top: 8 })
  }

  @Builder
  TodayProgress() {
    Column() {
      Row() {
        Text('今日进度')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.th().textPrimary)
          .layoutWeight(1)
        Text(this.todayVal + ' / ' + (this.habit as Habit).targetCount
          + ((this.habit as Habit).unit.length > 0 ? ' ' + (this.habit as Habit).unit : ''))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.todayVal >= (this.habit as Habit).targetCount
            ? this.th().success : (this.habit as Habit).color)
      }
      .width('100%')

      Row() {
        Text('−')
          .fontSize(24)
          .fontColor(this.todayVal > 0 ? (this.habit as Habit).color : this.th().textTertiary)
          .width(48)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.th().surfaceAlt)
          .borderRadius(12)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(() => {
            if (this.todayVal > 0) {
              this.changeToday(-1);
            }
          })
        Progress({
          value: this.todayVal,
          total: (this.habit as Habit).targetCount,
          type: ProgressType.Capsule
        })
          .layoutWeight(1)
          .height(14)
          .color((this.habit as Habit).color)
          .backgroundColor(this.th().track)
          .margin({ left: 14, right: 14 })
        Text('+')
          .fontSize(24)
          .fontColor((this.habit as Habit).color)
          .width(48)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.th().surfaceAlt)
          .borderRadius(12)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(() => this.changeToday(1))
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.th().surface)
    .borderRadius(20)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
    .margin({ top: 12 })
  }

  @Builder
  StatItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.th().textPrimary)
      Text(label)
        .fontSize(12)
        .fontColor(this.th().textTertiary)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
  }

  @Builder
  StatsRow() {
    Row() {
      this.StatItem('最长连续', longestStreak(this.habit as Habit) + ' 天')
      Divider().vertical(true).height(32).color(this.th().divider)
      this.StatItem('累计打卡', (this.habit as Habit).checkedDates.length + ' 次')
      Divider().vertical(true).height(32).color(this.th().divider)
      this.StatItem('30天完成', completionRate(this.habit as Habit, 30) + '%')
    }
    .width('100%')
    .padding({ top: 18, bottom: 18 })
    .backgroundColor(this.th().surface)
    .borderRadius(20)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
    .margin({ top: 12 })
  }

  heatColor(level: number): string {
    if (level === 1) {
      return (this.habit as Habit).color;
    }
    if (level === 0) {
      return this.th().track;
    }
    return '#00000000';
  }

  @Builder
  Heatmap() {
    Column() {
      Row() {
        Text('打卡热力图')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.th().textPrimary)
          .layoutWeight(1)
        Text('未打卡')
          .fontSize(11)
          .fontColor(this.th().textTertiary)
        Column()
          .width(11)
          .height(11)
          .borderRadius(3)
          .backgroundColor(this.th().track)
          .margin({ left: 5, right: 5 })
        Column()
          .width(11)
          .height(11)
          .borderRadius(3)
          .backgroundColor((this.habit as Habit).color)
        Text('已打卡')
          .fontSize(11)
          .fontColor(this.th().textTertiary)
          .margin({ left: 5 })
      }
      .width('100%')
      .margin({ bottom: 12 })
      Grid() {
        ForEach(this.buildHeat(), (c: HeatCell, idx: number) => {
          GridItem() {
            Column()
              .width(13)
              .height(13)
              .borderRadius(3)
              .backgroundColor(this.heatColor(c.level))
          }
        }, (c: HeatCell, idx: number) => idx + '_' + c.dateStr + '_' + this.refreshKey)
      }
      .rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(4)
      .columnsGap(4)
      .height(7 * 13 + 6 * 4)
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.th().surface)
    .borderRadius(20)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
    .margin({ top: 12 })
  }

  @Builder
  Calendar() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(22)
          .fontColor(this.th().textSecondary)
          .width(36)
          .textAlign(TextAlign.Center)
          .onClick(() => this.prevMonth())
        Text(this.year + ' 年 ' + (this.month + 1) + ' 月')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.th().textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('›')
          .fontSize(22)
          .fontColor(this.th().textSecondary)
          .width(36)
          .textAlign(TextAlign.Center)
          .onClick(() => this.nextMonth())
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        ForEach(['日', '一', '二', '三', '四', '五', '六'], (w: string) => {
          Text(w)
            .fontSize(12)
            .fontColor(this.th().textTertiary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }, (w: string) => w)
      }
      .width('100%')
      .margin({ bottom: 8 })

      Grid() {
        ForEach(this.buildCells(), (cell: DayCell, idx: number) => {
          GridItem() {
            if (cell.day > 0) {
              Stack() {
                Circle()
                  .width(34)
                  .height(34)
                  .fill(cell.checked ? (this.habit as Habit).color : '#00000000')
                  .stroke(cell.dateStr === todayStr() && !cell.checked
                    ? (this.habit as Habit).color
                    : (!cell.checked && cell.scheduled && cell.dateStr <= todayStr()
                      ? this.th().divider : '#00000000'))
                  .strokeWidth(cell.dateStr === todayStr() && !cell.checked ? 2 : 1.5)
                Text(cell.day.toString())
                  .fontSize(14)
                  .fontColor(cell.checked ? '#FFFFFF'
                    : (cell.dateStr === todayStr() ? (this.habit as Habit).color : this.th().textSecondary))
                  .fontWeight(cell.dateStr === todayStr() ? FontWeight.Bold : FontWeight.Normal)
              }
              .onClick(() => this.onTapDay(cell))
            }
          }
          .height(42)
        }, (cell: DayCell, idx: number) => idx + '_' + cell.dateStr + '_' + this.refreshKey)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .width('100%')

      Text('点击日期可补卡或取消')
        .fontSize(12)
        .fontColor(this.th().textTertiary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.th().surface)
    .borderRadius(20)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
    .margin({ top: 12 })
  }
}
