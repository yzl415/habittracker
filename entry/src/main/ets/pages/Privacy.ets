import { router } from '@kit.ArkUI';
import { getTheme, AppTheme } from '../model/Theme';

/** 隐私政策页：说明数据收集、存储、权限用途。上架合规必备。 */
@Entry
@Component
struct Privacy {
  @StorageProp('themeDark') themeDark: boolean = false;

  th(): AppTheme {
    return getTheme(this.themeDark);
  }

  build() {
    Column() {
      this.NavBar()
      Scroll() {
        Column() {
          this.Section('引言',
            '感谢你使用「萌芽打卡」。我们非常重视你的隐私与个人信息保护。本政策说明我们如何处理你的信息。简而言之：你的习惯数据全部保存在本机，我们不收集、不上传、不与任何第三方共享。')
          this.Section('我们收集的信息',
            '本应用不收集任何个人身份信息，不需要注册或登录。你创建的习惯名称、打卡记录、提醒设置等数据，仅保存在你的设备本地存储中，不会上传到任何服务器。')
          this.Section('权限说明',
            '通知/提醒权限：仅用于在你设定的时间提醒你完成习惯打卡。你可以随时在系统设置或应用内关闭。剪贴板：仅在你主动点击“导出备份/导入恢复”时读写，用于本地数据的备份与恢复，不会在后台访问。')
          this.Section('数据存储与安全',
            '所有数据使用系统提供的本地存储能力保存于设备内，受设备系统安全机制保护。卸载应用会一并删除这些数据，请在卸载前使用“导出备份”妥善保存。')
          this.Section('数据共享',
            '我们不会将你的任何数据出售、出租或共享给第三方。应用内无广告 SDK、无统计 SDK，不进行任何形式的网络数据传输。')
          this.Section('未成年人保护',
            '本应用适合所有年龄段使用。若你是未成年人，建议在监护人指导下使用。')
          this.Section('政策更新',
            '我们可能适时更新本政策，更新后会在应用内提示。继续使用即表示你接受更新后的政策。')
          this.Section('联系我们',
            '如对本隐私政策有任何疑问，可通过应用市场页面的开发者联系方式与我们联系。')
          Text('最后更新：2026年6月')
            .fontSize(12)
            .fontColor(this.th().textTertiary)
            .width('100%')
            .margin({ top: 20, bottom: 10 })
        }
        .width('100%')
        .padding({ left: 22, right: 22, bottom: 30 })
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
      Text('隐私政策')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.th().textPrimary)
      Blank().layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 10 })
  }

  @Builder
  Section(title: string, body: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.th().textPrimary)
        .width('100%')
        .margin({ bottom: 8 })
      Text(body)
        .fontSize(14)
        .lineHeight(22)
        .fontColor(this.th().textSecondary)
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .margin({ top: 18 })
  }
}
