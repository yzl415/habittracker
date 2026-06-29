/**
 * 提醒服务：基于 reminderAgentManager 的本地定时提醒（每周重复）。
 * 失败时静默降级，不影响主流程。
 */
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Habit } from '../model/Habit';
import { buildReminderAlarm, ReminderAlarmPlan, toReminderRequest } from './ReminderPlanner';

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

  static async ensureNotificationAndSchedule(habit: Habit, context: common.UIAbilityContext): Promise<number> {
    if (!habit.reminderEnabled) {
      if (habit.reminderId >= 0) {
        await NotificationService.cancel(habit.reminderId);
      }
      return -1;
    }
    const hasPermission: boolean = await NotificationService.requestEnable(context);
    if (!hasPermission) {
      return -1;
    }
    // 先拿到权限，再替换旧提醒，避免用户拒绝权限时误删原有提醒
    if (habit.reminderId >= 0) {
      await NotificationService.cancel(habit.reminderId);
    }
    const notificationId: number = Math.floor(Math.random() * 1000000);
    const plan: ReminderAlarmPlan = buildReminderAlarm(habit, notificationId);
    plan.wantAgent = {
      pkgName: context.abilityInfo.bundleName,
      abilityName: context.abilityInfo.name
    };
    const reminder: reminderAgentManager.ReminderRequestAlarm = toReminderRequest(plan);
    try {
      const id: number = await reminderAgentManager.publishReminder(reminder);
      return id;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.warn(`publishReminder failed: ${err.code} ${err.message}`);
      return -1;
    }
  }

  /**
   * 为习惯创建/更新提醒。返回系统分配的 reminderId（失败返回 -1）。
   * weekly 习惯按选中的星期重复；daily 习惯每天重复。
   */
  static async schedule(habit: Habit, context: common.UIAbilityContext): Promise<number> {
    return await NotificationService.ensureNotificationAndSchedule(habit, context);
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
