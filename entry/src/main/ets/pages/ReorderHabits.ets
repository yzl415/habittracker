import { router } from '@kit.ArkUI';
import { HabitStore } from '../model/HabitStore';
import { Habit } from '../model/Habit';
import { getTheme, AppTheme } from '../model/Theme';
import { EmptyArt } from '../components/EmptyArt';

@Entry
@Component
struct ReorderHabits {
  @StorageProp('themeDark') themeDark: boolean = false;
  @State habits: Habit[] = [];
  private store: HabitStore = HabitStore.getInstance();

  th(): AppTheme {
    return getTheme(this.themeDark);
  }

  aboutToAppear(): void {
    this.habits = this.store.activeHabits().slice();
  }

  async onMove(from: number, to: number): Promise<void> {
    if (from === to) {
      return;
    }
    const moved: Habit = this.habits.splice(from, 1)[0];
    this.habits.splice(to, 0, moved);
    this.habits = this.habits.slice();
    await this.store.setOrder(this.habits.map((h: Habit) => h.id));
  }

  build() {
    Column() {
      this.NavBar()
      if (this.habits.length === 0) {
        this.Empty()
      } else {
        Text('长按拖动调整顺序')
          .fontSize(13)
          .fontColor(this.th().textTertiary)
          .width('100%')
          .padding({ left: 24, top: 4, bottom: 8 })
        List({ space: 10 }) {
          ForEach(this.habits, (h: Habit) => {
            ListItem() {
              Row() {
                Stack() {
                  Circle().width(40).height(40).fill(h.color + (this.themeDark ? '2E' : '1F'))
                  Text(h.emoji).fontSize(20)
                }
                .margin({ right: 14 })
                Text(h.name)
                  .fontSize(16)
                  .fontColor(this.th().textPrimary)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text('≡').fontSize(22).fontColor(this.th().textTertiary)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(this.th().surface)
              .borderRadius(16)
              .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
            }
          }, (h: Habit) => h.id)
          .onMove((from: number, to: number) => {
            this.onMove(from, to);
          })
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 24 })
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
      Text('排序')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.th().textPrimary)
      Blank().layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 10 })
  }

  @Builder
  Empty() {
    Column() {
      EmptyArt({ kind: 'box', accent: this.th().accent })
      Text('暂无可排序的习惯')
        .fontSize(15)
        .fontColor(this.th().textTertiary)
        .margin({ top: 18 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }
}
