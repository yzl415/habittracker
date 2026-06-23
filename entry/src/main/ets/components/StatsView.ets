import { HabitStore } from '../model/HabitStore';
import { Habit, currentStreak, longestStreak,
  isScheduledOn, addDays, todayStr, WEEK_SHORT, weekdayOf } from '../model/Habit';
import { getTheme, AppTheme } from '../model/Theme';
import { EmptyArt } from './EmptyArt';

/** 单日完成统计 */
class DayStat {
  label: string;
  ratio: number;
  done: number;
  total: number;

  constructor(label: string, ratio: number, done: number, total: number) {
    this.label = label;
    this.ratio = ratio;
    this.done = done;
    this.total = total;
  }
}

/** 统计页：总览数据 + 近 7 日柱状图 + 习惯排行 */
@Component
export struct StatsView {
  @Prop @Watch('onTick') tick: number;
  @StorageProp('themeDark') themeDark: boolean = false;
  @State habits: Habit[] = [];
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

  totalCheckins(): number {
    let n: number = 0;
    this.habits.forEach((h: Habit) => n += h.checkedDates.length);
    return n;
  }

  bestStreak(): number {
    let best: number = 0;
    this.habits.forEach((h: Habit) => {
      const s: number = longestStreak(h);
      if (s > best) {
        best = s;
      }
    });
    return best;
  }

  todayRate(): number {
    const today: string = todayStr();
    let total: number = 0;
    let done: number = 0;
    this.habits.forEach((h: Habit) => {
      if (isScheduledOn(h, today)) {
        total++;
        if (h.checkedDates.indexOf(today) >= 0) {
          done++;
        }
      }
    });
    if (total === 0) {
      return 0;
    }
    return Math.round(done / total * 100);
  }

  weekStats(): DayStat[] {
    const stats: DayStat[] = [];
    for (let i = 6; i >= 0; i--) {
      const ds: string = addDays(todayStr(), -i);
      let total: number = 0;
      let done: number = 0;
      this.habits.forEach((h: Habit) => {
        if (ds >= h.createdAt && isScheduledOn(h, ds)) {
          total++;
          if (h.checkedDates.indexOf(ds) >= 0) {
            done++;
          }
        }
      });
      const ratio: number = total === 0 ? 0 : done / total;
      stats.push(new DayStat(WEEK_SHORT[weekdayOf(ds)], ratio, done, total));
    }
    return stats;
  }

  ranking(): Habit[] {
    return this.habits.slice().sort((a: Habit, b: Habit) => currentStreak(b) - currentStreak(a));
  }

  /** 排行中最高的连续天数，用作进度条满格基准 */
  maxStreak(): number {
    let max: number = 0;
    this.habits.forEach((h: Habit) => {
      const s: number = currentStreak(h);
      if (s > max) {
        max = s;
      }
    });
    return max;
  }

  cardBorderWidth(): number {
    return this.themeDark ? 1 : 0;
  }

  build() {
    Column() {
      Text('统计')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.th().textPrimary)
        .letterSpacing(0.2)
        .width('100%')
        .padding({ left: 22, right: 22, top: 22, bottom: 14 })

      if (this.habits.length === 0) {
        this.Empty()
      } else {
        Scroll() {
          Column() {
            this.OverviewGrid()
            this.WeekChart()
            this.Ranking()
          }
          .width('100%')
          .padding({ left: 22, right: 22, bottom: 96 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  Empty() {
    Column() {
      EmptyArt({ kind: 'chart', accent: this.th().accent })
      Text('打卡后这里会显示数据')
        .fontSize(15)
        .fontColor(this.th().textTertiary)
        .margin({ top: 18 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  StatCard(value: string, label: string, accent: string) {
    Column() {
      Text(value)
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
        .fontColor(accent)
      Text(label)
        .fontSize(13)
        .fontColor(this.th().textSecondary)
        .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding({ top: 18, bottom: 18, left: 18, right: 12 })
    .backgroundColor(this.th().surface)
    .borderRadius(18)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
  }

  @Builder
  OverviewGrid() {
    Row({ space: 12 }) {
      this.StatCard(this.todayRate() + '%', '今日完成', this.th().accent)
      this.StatCard(this.habits.length.toString(), '活跃习惯', this.th().success)
    }
    .width('100%')
    .margin({ top: 4 })

    Row({ space: 12 }) {
      this.StatCard(this.totalCheckins().toString(), '累计打卡', '#FF7B54')
      this.StatCard(this.bestStreak() + ' 天', '最佳连续', '#A855F7')
    }
    .width('100%')
    .margin({ top: 12 })
  }

  @Builder
  WeekChart() {
    Column() {
      Text('近 7 日完成率')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.th().textPrimary)
        .width('100%')
      Row() {
        ForEach(this.weekStats(), (s: DayStat, idx: number) => {
          Column() {
            Text(s.total > 0 ? Math.round(s.ratio * 100) + '' : '')
              .fontSize(10)
              .fontColor(idx === 6 ? this.th().accent : this.th().textTertiary)
              .fontWeight(idx === 6 ? FontWeight.Bold : FontWeight.Normal)
              .margin({ bottom: 4 })
            Column() {
              Column()
                .width('58%')
                .height((6 + s.ratio * 94) + '%')
                .backgroundColor(s.ratio > 0
                  ? (idx === 6 ? this.th().accent : this.th().accent + (this.themeDark ? '66' : '4D'))
                  : this.th().track)
                .borderRadius(7)
            }
            .height(112)
            .width('100%')
            .justifyContent(FlexAlign.End)
            .alignItems(HorizontalAlign.Center)
            Text(s.label)
              .fontSize(12)
              .fontColor(idx === 6 ? this.th().accent : this.th().textTertiary)
              .fontWeight(idx === 6 ? FontWeight.Medium : FontWeight.Normal)
              .margin({ top: 8 })
          }
          .layoutWeight(1)
        }, (s: DayStat, idx: number) => idx + '_' + s.label + '_' + Math.round(s.ratio * 100))
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 14 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.th().surface)
    .borderRadius(20)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
    .margin({ top: 12 })
  }

  @Builder
  Ranking() {
    Column() {
      Text('坚持排行')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.th().textPrimary)
        .width('100%')
        .margin({ bottom: 4 })
      ForEach(this.ranking(), (h: Habit, idx: number) => {
        Row() {
          Stack() {
            Circle().width(36).height(36).fill(h.color + (this.themeDark ? '2E' : '1F'))
            Text(h.emoji).fontSize(18)
          }
          .margin({ right: 12 })
          Column() {
            Row() {
              Text(h.name)
                .fontSize(15)
                .fontColor(this.th().textPrimary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              Text('🔥 ' + currentStreak(h))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(h.color)
                .margin({ left: 8 })
            }
            .width('100%')
            Stack({ alignContent: Alignment.Start }) {
              Column().width('100%').height(6).borderRadius(3).backgroundColor(this.th().track)
              Column()
                .width((this.maxStreak() > 0 ? currentStreak(h) / this.maxStreak() * 100 : 0) + '%')
                .height(6)
                .borderRadius(3)
                .backgroundColor(h.color)
            }
            .width('100%')
            .margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 11, bottom: 11 })
      }, (h: Habit) => h.id + '_' + h.checkedDates.length)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.th().surface)
    .borderRadius(20)
    .border({ width: this.cardBorderWidth(), color: this.th().cardBorder })
    .margin({ top: 12 })
  }
}
