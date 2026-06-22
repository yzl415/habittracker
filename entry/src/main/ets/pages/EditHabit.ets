import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { HabitStore } from '../model/HabitStore';
import { Habit, HABIT_COLORS, HABIT_EMOJIS, todayStr } from '../model/Habit';

interface EditParams {
  id?: string;
}

@Entry
@Component
struct EditHabit {
  @State name: string = '';
  @State emoji: string = HABIT_EMOJIS[0];
  @State color: string = HABIT_COLORS[0];
  @State editingId: string = '';
  private store: HabitStore = HabitStore.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as EditParams;
    if (params && params.id) {
      const h: Habit | undefined = this.store.getById(params.id);
      if (h !== undefined) {
        this.editingId = h.id;
        this.name = h.name;
        this.emoji = h.emoji;
        this.color = h.color;
      }
    }
  }

  isEditing(): boolean {
    return this.editingId.length > 0;
  }

  async save(): Promise<void> {
    if (this.name.trim().length === 0) {
      promptAction.showToast({ message: '请输入习惯名称' });
      return;
    }
    try {
      if (this.isEditing()) {
        const h: Habit | undefined = this.store.getById(this.editingId);
        if (h !== undefined) {
          h.name = this.name.trim();
          h.emoji = this.emoji;
          h.color = this.color;
          await this.store.update(h);
        }
      } else {
        const id: string = Date.now().toString();
        const habit: Habit = new Habit(id, this.name.trim(), this.emoji,
          this.color, todayStr(), []);
        await this.store.add(habit);
      }
      router.back();
    } catch (e) {
      promptAction.showToast({ message: '保存失败：' + JSON.stringify(e) });
    }
  }

  async confirmDelete(): Promise<void> {
    await this.store.remove(this.editingId);
    router.back();
  }

  @Builder
  NavBar() {
    Row() {
      Text('取消')
        .fontSize(16)
        .fontColor('#9AA0AC')
        .onClick(() => router.back())
      Text(this.isEditing() ? '编辑习惯' : '新建习惯')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('保存')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0A59F7')
        .onClick(() => this.save())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
  }

  @Builder
  SectionLabel(text: string) {
    Text(text)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor('#5A6072')
      .width('100%')
      .margin({ top: 20, bottom: 10 })
  }

  @Builder
  NameField() {
    Row() {
      Stack() {
        Circle().width(52).height(52).fill(this.color + '22')
        Text(this.emoji).fontSize(26)
      }
      .margin({ right: 14 })
      Text(this.name.length > 0 ? this.name : '习惯名称')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.name.length > 0 ? '#1A1A1A' : '#C5C8D0')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .margin({ top: 8 })

    this.SectionLabel('名称')
    TextInput({ text: this.name, placeholder: '例如：每天喝水 8 杯' })
      .fontSize(16)
      .height(52)
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .padding({ left: 16, right: 16 })
      .maxLength(20)
      .onChange((v: string) => this.name = v)
  }

  build() {
    Column() {
      this.NavBar()
      Scroll() {
        Column() {
          this.NameField()
          this.EmojiPicker()
          this.ColorPicker()
          if (this.isEditing()) {
            this.DeleteButton()
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6FA')
  }

  @Builder
  EmojiPicker() {
    this.SectionLabel('图标')
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(HABIT_EMOJIS, (e: string) => {
        Stack() {
          Circle()
            .width(46)
            .height(46)
            .fill(this.emoji === e ? this.color + '22' : '#FFFFFF')
            .stroke(this.emoji === e ? this.color : '#FFFFFF')
            .strokeWidth(2)
          Text(e).fontSize(22)
        }
        .margin({ right: 10, bottom: 10 })
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
        Stack() {
          Circle().width(40).height(40).fill(c)
          if (this.color === c) {
            Text('✓').fontSize(18).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
          }
        }
        .margin({ right: 14, bottom: 12 })
        .onClick(() => this.color = c)
      }, (c: string) => c)
    }
    .width('100%')
  }

  @Builder
  DeleteButton() {
    Button('删除习惯')
      .width('100%')
      .height(50)
      .fontSize(16)
      .fontColor('#F43F5E')
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .margin({ top: 28, bottom: 20 })
      .onClick(() => this.confirmDelete())
  }
}
