import { router } from '@kit.ArkUI';
import { HabitStore } from '../model/HabitStore';
import { Habit, currentStreak, frequencyLabel, isScheduledToday, todayStr,
  isQuantifiable, valueToday, TimeOfDay, timeOfDayLabel } from '../model/Habit';
import { getTheme, AppTheme } from '../model/Theme';
import { AppIcon } from './AppIcon';
import { EmptyArt } from './EmptyArt';

/** 时段分组 */
class Section {
  key: TimeOfDay;
  habits: Habit[];

  constructor(key: TimeOfDay, habits: Habit[]) {
    this.key = key;
    this.habits = habits;
  }
}

/** 今日页：展示今天需要打卡的习惯 + 今日进度，按时段分组 */
@Component
export struct TodayView {
  @Prop @Watch('onTick') tick: number;
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

  async subOne(h: Habit): Promise<void> {
    await this.store.addValue(h.id, -1);
    this.reload();
  }

  todayLabel(): string {
    const d: Date = new Date();
    const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${d.getMonth() + 1}月${d.getDate()}日 · ${week[d.getDay()]}`;
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
        AppIcon({ name: 'plus', color: this.th().accentText, iconSize: 26, stroke: 2.4 })
      }
      .width(58)
      .height(58)
      .backgroundColor(this.th().accent)
      .shadow({ radius: 18, color: this.th().accent + '55', offsetX: 0, offsetY: 8 })
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
        .fontSize(13)
        .fontColor(this.th().textSecondary)
        .letterSpacing(0.3)
      Row() {
        Text('今天')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.th().textPrimary)
          .letterSpacing(0.2)
          .layoutWeight(1)
        if (this.dueHabits().length > 0) {
          Row() {
            Text(this.doneCount().toString())
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.th().accent)
            Text(' / ' + this.dueHabits().length)
              .fontSize(15)
              .fontColor(this.th().textTertiary)
          }
          .padding({ left: 13, right: 13, top: 7, bottom: 7 })
          .backgroundColor(this.th().accentSoft)
          .borderRadius(20)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 6 })

      if (this.dueHabits().length > 0) {
        Stack({ alignContent: Alignment.Start }) {
          Column().width('100%').height(7).borderRadius(4).backgroundColor(this.th().track)
          Column()
            .width((this.progress() * 100) + '%')
            .height(7)
            .borderRadius(4)
            .backgroundColor(this.doneCount() === this.dueHabits().length ? this.th().success : this.th().accent)
        }
        .width('100%')
        .margin({ top: 16 })
        if (this.doneCount() === this.dueHabits().length) {
          Text('今日全部完成，继续保持 🎉')
            .fontSize(13)
            .fontColor(this.th().success)
            .margin({ top: 10 })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 22, right: 22, top: 18, bottom: 14 })
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
    List({ space: 11 }) {
      ForEach(this.sections(), (sec: Section) => {
        if (this.showSectionHeader()) {
          ListItem() {
            Text(timeOfDayLabel(sec.key))
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.th().textSecondary)
              .letterSpacing(0.5)
              .width('100%')
              .padding({ top: 8, bottom: 2, left: 4 })
          }
        }
        ForEach(sec.habits, (h: Habit) => {
          ListItem() {
            this.HabitCard(h)
          }
        }, (h: Habit) => h.id + '_' + h.checkedDates.length + '_' + valueToday(h))
      }, (sec: Section) => sec.key + '_' + sec.habits.length)

      ListItem() {
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
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 22, right: 22, top: 6, bottom: 96 })
    .scrollBar(BarState.Off)
  }

  @Builder
  HabitCard(h: Habit) {
    Row() {
      Row() {
        Stack() {
          Circle().width(44).height(44).fill(h.color + (this.themeDark ? '2E' : '1F'))
          Text(h.emoji).fontSize(21)
        }
        .margin({ right: 14 })

        Column() {
          Text(h.name)
            .fontSize(16.5)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.th().textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row() {
            if (isQuantifiable(h)) {
              Text(valueToday(h) + ' / ' + h.targetCount + (h.unit.length > 0 ? ' ' + h.unit : ''))
                .fontSize(13)
                .fontColor(this.isCheckedToday(h) ? this.th().success : h.color)
            } else {
              Text('已坚持 ' + currentStreak(h) + ' 天')
                .fontSize(13)
                .fontColor(this.th().textTertiary)
            }
            Text('  ·  ' + frequencyLabel(h))
              .fontSize(13)
              .fontColor(this.th().textTertiary)
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .onClick(() => {
        router.pushUrl({ url: 'pages/HabitDetail', params: { id: h.id } });
      })

      if (isQuantifiable(h)) {
        this.QuantControl(h)
      } else {
        this.CheckButton(h)
      }
    }
    .width('100%')
    .padding(15)
    .backgroundColor(this.th().surface)
    .borderRadius(20)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .shadow({ radius: this.th().shadowRadius, color: this.th().shadowColor, offsetX: 0, offsetY: 3 })
    .opacity(this.isCheckedToday(h) ? 0.62 : 1)
  }

  @Builder
  CheckButton(h: Habit) {
    Stack() {
      Circle()
        .width(34)
        .height(34)
        .fill(this.isCheckedToday(h) ? h.color : '#00000000')
        .stroke(this.isCheckedToday(h) ? h.color : this.th().divider)
        .strokeWidth(2)
      if (this.isCheckedToday(h)) {
        Text('✓').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
      }
    }
    .margin({ left: 12 })
    .onClick(() => this.toggle(h))
  }

  @Builder
  QuantControl(h: Habit) {
    Row() {
      if (valueToday(h) > 0) {
        Text('−')
          .fontSize(20)
          .fontColor(this.th().textTertiary)
          .width(30)
          .height(30)
          .textAlign(TextAlign.Center)
          .onClick(() => this.subOne(h))
      }
      Stack() {
        Circle()
          .width(34)
          .height(34)
          .fill(this.isCheckedToday(h) ? h.color : h.color + (this.themeDark ? '33' : '22'))
        if (this.isCheckedToday(h)) {
          Text('✓').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        } else {
          Text('+').fontSize(21).fontColor(h.color)
        }
      }
      .onClick(() => this.addOne(h))
    }
    .margin({ left: 8 })
  }
}
