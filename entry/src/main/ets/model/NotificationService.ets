/**
 * 提醒服务：基于 reminderAgentManager 的本地定时提醒（每周重复）。
 * 失败时静默降级，不影响主流程。
 */
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Habit } from '../model/Habit';

export class NotificationService {
  /** 请求通知授权 */
  static async requestEnable(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification(context);
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.warn(`requestEnableNotification failed: ${err.code} ${err.message}`);
      return false;
    }
  }

  /** 把 "HH:mm" 解析成 [hour, minute] */
  private static parseTime(time: string): number[] {
    const parts: string[] = time.split(':');
    return [Number(parts[0]), Number(parts[1])];
  }

  /**
   * 为习惯创建/更新提醒。返回系统分配的 reminderId（失败返回 -1）。
   * weekly 习惯按选中的星期重复；daily 习惯每天重复。
   */
  static async schedule(habit: Habit): Promise<number> {
    // 先撤销旧的，避免重复
    if (habit.reminderId >= 0) {
      await NotificationService.cancel(habit.reminderId);
    }
    if (!habit.reminderEnabled) {
      return -1;
    }
    const hm: number[] = NotificationService.parseTime(habit.reminderTime);
    // daysOfWeek 中 1=周一 ... 7=周日（reminderAgentManager 约定）
    let daysOfWeek: number[] = [];
    if (habit.frequency === 'weekly' && habit.weekdays.length > 0) {
      daysOfWeek = habit.weekdays.map((d: number) => d === 0 ? 7 : d);
    } else {
      daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
    }
    const reminder: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
      hour: hm[0],
      minute: hm[1],
      daysOfWeek: daysOfWeek,
      title: habit.emoji + ' ' + habit.name,
      content: '别忘了今天的习惯打卡哦',
      notificationId: Math.floor(Math.random() * 1000000),
      snoozeTimes: 0,
      ringDuration: 0,
      actionButton: [],
      wantAgent: { pkgName: '', abilityName: '' }
    };
    try {
      const id: number = await reminderAgentManager.publishReminder(reminder);
      return id;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.warn(`publishReminder failed: ${err.code} ${err.message}`);
      return -1;
    }
  }

  /** 取消提醒 */
  static async cancel(reminderId: number): Promise<void> {
    if (reminderId < 0) {
      return;
    }
    try {
      await reminderAgentManager.cancelReminder(reminderId);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.warn(`cancelReminder failed: ${err.code} ${err.message}`);
    }
  }
}
