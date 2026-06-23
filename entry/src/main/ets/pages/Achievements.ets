import { router } from '@kit.ArkUI';
import { HabitStore } from '../model/HabitStore';
import { Habit } from '../model/Habit';
import { AchievementStatus, evaluateAchievements } from '../model/Achievement';
import { getTheme, AppTheme } from '../model/Theme';

@Entry
@Component
struct Achievements {
  @StorageProp('themeDark') themeDark: boolean = false;
  @State list: AchievementStatus[] = [];
  private store: HabitStore = HabitStore.getInstance();

  th(): AppTheme {
    return getTheme(this.themeDark);
  }

  aboutToAppear(): void {
    const habits: Habit[] = this.store.habits.filter((h: Habit) => !h.archived);
    this.list = evaluateAchievements(habits);
  }

  unlockedNum(): number {
    let n: number = 0;
    this.list.forEach((s: AchievementStatus) => {
      if (s.unlocked) {
        n++;
      }
    });
    return n;
  }

  build() {
    Column() {
      this.NavBar()
      Scroll() {
        Column() {
          this.HeroBanner()
          this.Grid()
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 28 })
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
      Text('‹ 返回')
        .fontSize(16)
        .fontColor(this.th().accent)
        .onClick(() => router.back())
        .layoutWeight(1)
      Text('成就')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.th().textPrimary)
      Blank().layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 10 })
  }

  @Builder
  HeroBanner() {
    Column() {
      Text('🏆').fontSize(44)
      Text(this.unlockedNum() + ' / ' + this.list.length)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ top: 8 })
      Text('已解锁成就')
        .fontSize(13)
        .fontColor('#FFFFFFCC')
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ top: 26, bottom: 26 })
    .linearGradient({ angle: 135, colors: [['#F59E0B', 0], ['#FF7B54', 1]] })
    .borderRadius(22)
    .margin({ top: 8 })
    .shadow({ radius: this.themeDark ? 0 : 20, color: '#F59E0B33', offsetX: 0, offsetY: 8 })
  }

  @Builder
  Grid() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
      ForEach(this.list, (s: AchievementStatus) => {
        this.Badge(s)
      }, (s: AchievementStatus) => s.def.id + '_' + s.unlocked)
    }
    .width('100%')
    .margin({ top: 16 })
  }

  @Builder
  Badge(s: AchievementStatus) {
    Column() {
      Stack() {
        Circle()
          .width(56)
          .height(56)
          .fill(s.unlocked ? (this.themeDark ? '#3A2E14' : '#FFF4E5') : this.th().surfaceAlt)
        Text(s.def.emoji)
          .fontSize(28)
          .opacity(s.unlocked ? 1 : 0.3)
      }
      Text(s.def.title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(s.unlocked ? this.th().textPrimary : this.th().textTertiary)
        .margin({ top: 8 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (s.unlocked) {
        Text('已达成')
          .fontSize(11)
          .fontColor(this.th().success)
          .margin({ top: 4 })
      } else {
        Text(Math.min(s.current, s.def.target) + ' / ' + s.def.target)
          .fontSize(11)
          .fontColor(this.th().textTertiary)
          .margin({ top: 4 })
      }
    }
    .width('31%')
    .padding({ top: 16, bottom: 14 })
    .backgroundColor(this.th().surface)
    .borderRadius(16)
    .border({ width: this.themeDark ? 1 : 0, color: this.th().cardBorder })
    .margin({ bottom: 10 })
  }
}
