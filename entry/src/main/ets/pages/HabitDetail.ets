import { router } from '@kit.ArkUI';
import { HabitStore } from '../model/HabitStore';
import { Habit, currentStreak, longestStreak, completionRate,
  toDateStr, todayStr } from '../model/Habit';

interface DetailParams {
  id?: string;
}

/** 日历格子 */
class DayCell {
  day: number;      // 0 表示占位空格
  dateStr: string;
  checked: boolean;

  constructor(day: number, dateStr: string, checked: boolean) {
    this.day = day;
    this.dateStr = dateStr;
    this.checked = checked;
  }
}

@Entry
@Component
struct HabitDetail {
  @State habit: Habit | null = null;
  @State year: number = new Date().getFullYear();
  @State month: number = new Date().getMonth(); // 0-11
  private store: HabitStore = HabitStore.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as DetailParams;
    if (params && params.id) {
      const h: Habit | undefined = this.store.getById(params.id);
      this.habit = h !== undefined ? h : null;
    }
  }

  // 生成当月日历格子（前面补空格对齐星期）
  buildCells(): DayCell[] {
    const cells: DayCell[] = [];
    if (this.habit === null) {
      return cells;
    }
    const checkedSet: Set<string> = new Set(this.habit.checkedDates);
    const firstDay: number = new Date(this.year, this.month, 1).getDay(); // 0=周日
    const daysInMonth: number = new Date(this.year, this.month + 1, 0).getDate();
    for (let i = 0; i < firstDay; i++) {
      cells.push(new DayCell(0, '', false));
    }
    for (let d = 1; d <= daysInMonth; d++) {
      const ds: string = toDateStr(new Date(this.year, this.month, d));
      cells.push(new DayCell(d, ds, checkedSet.has(ds)));
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

  build() {
    Column() {
      this.NavBar()

      if (this.habit !== null) {
        Scroll() {
          Column() {
            this.HeroCard()
            this.StatsRow()
            this.Calendar()
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6FA')
  }

  @Builder
  NavBar() {
    Row() {
      Text('‹ 返回')
        .fontSize(16)
        .fontColor('#0A59F7')
        .onClick(() => router.back())
        .layoutWeight(1)
      Text('编辑')
        .fontSize(16)
        .fontColor('#0A59F7')
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
        Circle().width(70).height(70).fill((this.habit as Habit).color + '22')
        Text((this.habit as Habit).emoji).fontSize(34)
      }
      Text((this.habit as Habit).name)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ top: 12 })
      Text('🔥 当前连续 ' + currentStreak((this.habit as Habit).checkedDates) + ' 天')
        .fontSize(15)
        .fontColor((this.habit as Habit).color)
        .margin({ top: 6 })
    }
    .width('100%')
    .padding({ top: 24, bottom: 24 })
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ top: 8 })
  }

  @Builder
  StatItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      Text(label)
        .fontSize(12)
        .fontColor('#9AA0AC')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
  }

  @Builder
  StatsRow() {
    Row() {
      this.StatItem('最长连续', longestStreak((this.habit as Habit).checkedDates) + ' 天')
      Divider().vertical(true).height(32).color('#EEEFF2')
      this.StatItem('累计打卡', (this.habit as Habit).checkedDates.length + ' 次')
      Divider().vertical(true).height(32).color('#EEEFF2')
      this.StatItem('30天完成', completionRate((this.habit as Habit).checkedDates, 30) + '%')
    }
    .width('100%')
    .padding({ top: 18, bottom: 18 })
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ top: 14 })
  }

  @Builder
  Calendar() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(22)
          .fontColor('#5A6072')
          .width(36)
          .textAlign(TextAlign.Center)
          .onClick(() => this.prevMonth())
        Text(this.year + ' 年 ' + (this.month + 1) + ' 月')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('›')
          .fontSize(22)
          .fontColor('#5A6072')
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
            .fontColor('#9AA0AC')
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
                  .fill(cell.checked ? (this.habit as Habit).color : 'transparent')
                Text(cell.day.toString())
                  .fontSize(14)
                  .fontColor(cell.checked ? '#FFFFFF'
                    : (cell.dateStr === todayStr() ? (this.habit as Habit).color : '#3A3F4B'))
                  .fontWeight(cell.dateStr === todayStr() ? FontWeight.Bold : FontWeight.Normal)
              }
            }
          }
          .height(42)
        }, (cell: DayCell, idx: number) => idx + '_' + cell.dateStr)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ top: 14 })
  }
}
