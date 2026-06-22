import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { HabitStore } from '../model/HabitStore';
import { Habit, currentStreak, todayStr } from '../model/Habit';

@Entry
@Component
struct Index {
  @State habits: Habit[] = [];
  @State loaded: boolean = false;
  private store: HabitStore = HabitStore.getInstance();

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.store.init(ctx);
    this.refresh();
    this.loaded = true;
  }

  onPageShow(): void {
    // 从编辑/详情页返回时刷新
    if (this.loaded) {
      this.refresh();
    }
  }

  refresh(): void {
    // 重新赋新数组引用，触发 UI 刷新
    this.habits = this.store.habits.slice();
  }

  isCheckedToday(h: Habit): boolean {
    return h.checkedDates.indexOf(todayStr()) >= 0;
  }

  doneCount(): number {
    const today: string = todayStr();
    let n: number = 0;
    this.habits.forEach((h: Habit) => {
      if (h.checkedDates.indexOf(today) >= 0) {
        n++;
      }
    });
    return n;
  }

  async toggle(h: Habit): Promise<void> {
    await this.store.toggleToday(h.id);
    this.refresh();
  }

  @Builder
  Header() {
    Column() {
      Text(this.todayLabel())
        .fontSize(14)
        .fontColor('#9AA0AC')
      Row() {
        Text('今日习惯')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
        if (this.habits.length > 0) {
          Text(this.doneCount() + ' / ' + this.habits.length)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0A59F7')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor('#EAF1FE')
            .borderRadius(12)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 16, bottom: 12 })
  }

  todayLabel(): string {
    const d: Date = new Date();
    const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${d.getMonth() + 1}月${d.getDate()}日 ${week[d.getDay()]}`;
  }

  @Builder
  EmptyState() {
    Column() {
      Text('🌱')
        .fontSize(64)
      Text('还没有习惯')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A1A')
        .margin({ top: 16 })
      Text('点击右下角 ＋ 添加你的第一个习惯')
        .fontSize(14)
        .fontColor('#9AA0AC')
        .margin({ top: 8 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  HabitList() {
    List({ space: 12 }) {
      ForEach(this.habits, (h: Habit) => {
        ListItem() {
          this.HabitCard(h)
        }
      }, (h: Habit) => h.id + '_' + h.checkedDates.length)
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 20, right: 20, top: 4, bottom: 90 })
    .scrollBar(BarState.Off)
  }

  @Builder
  HabitCard(h: Habit) {
    Row() {
      // 左侧：图标 + 名称（点击进详情）
      Row() {
        Stack() {
          Circle()
            .width(46)
            .height(46)
            .fill(h.color + '22')
          Text(h.emoji)
            .fontSize(22)
        }
        .margin({ right: 14 })

        Column() {
          Text(h.name)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('🔥 已坚持 ' + currentStreak(h.checkedDates) + ' 天')
            .fontSize(13)
            .fontColor('#9AA0AC')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .onClick(() => {
        router.pushUrl({ url: 'pages/HabitDetail', params: { id: h.id } });
      })

      // 右侧：打卡按钮
      Stack() {
        Circle()
          .width(34)
          .height(34)
          .fill(this.isCheckedToday(h) ? h.color : 'transparent')
          .stroke(this.isCheckedToday(h) ? h.color : '#D5D8DF')
          .strokeWidth(2)
        if (this.isCheckedToday(h)) {
          Text('✓')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
      }
      .margin({ left: 12 })
      .onClick(() => this.toggle(h))
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .shadow({ radius: 8, color: '#0D000000', offsetX: 0, offsetY: 2 })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.Header()
        if (this.habits.length === 0) {
          this.EmptyState()
        } else {
          this.HabitList()
        }
      }
      .width('100%')
      .height('100%')

      // 悬浮添加按钮
      Button() {
        Text('＋')
          .fontSize(30)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor('#0A59F7')
      .shadow({ radius: 16, color: '#400A59F7', offsetX: 0, offsetY: 6 })
      .margin({ right: 20, bottom: 28 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/EditHabit' });
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6FA')
  }
}
