let storage = new LocalStorage();

@Entry(storage)
@Component
struct WidgetCard {
  @LocalStorageProp('doneCount') doneCount: number = 0;
  @LocalStorageProp('totalCount') totalCount: number = 0;
  @LocalStorageProp('ratio') ratio: number = 0;
  @LocalStorageProp('dateLabel') dateLabel: string = '今日';
  @LocalStorageProp('emojis') emojis: string = '';
  @LocalStorageProp('allDone') allDone: boolean = false;

  // 点击卡片打开 App
  openApp(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility'
    });
  }

  build() {
    Column() {
      Row() {
        Text(this.dateLabel)
          .fontSize(12)
          .fontColor('#9AA0AC')
          .layoutWeight(1)
        Text('✅ 习惯')
          .fontSize(12)
          .fontColor('#0A59F7')
      }
      .width('100%')

      Row() {
        Text(this.totalCount > 0 ? this.doneCount.toString() : '—')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Text(this.totalCount > 0 ? ' / ' + this.totalCount : '')
          .fontSize(18)
          .fontColor('#9AA0AC')
          .margin({ bottom: 4 })
        Blank()
        if (this.allDone) {
          Text('🎉')
            .fontSize(26)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 8 })

      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(8)
          .borderRadius(4)
          .backgroundColor('#E3E7EF')
        Column()
          .width(this.ratio + '%')
          .height(8)
          .borderRadius(4)
          .backgroundColor(this.allDone ? '#22C55E' : '#0A59F7')
      }
      .width('100%')
      .margin({ top: 10 })

      Blank()

      Row() {
        Text(this.totalCount === 0 ? '还没有今日习惯' : this.emojis)
          .fontSize(16)
          .fontColor('#5A6072')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .onClick(() => this.openApp())
  }
}
