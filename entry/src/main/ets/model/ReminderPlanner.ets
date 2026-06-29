import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { Habit } from './Habit';

export interface ReminderAlarmPlan {
  hour: number;
  minute: number;
  daysOfWeek: number[];
  title: string;
  content: string;
  notificationId: number;
  wantAgent?: ReminderWantAgent;
}

export interface ReminderWantAgent {
  pkgName: string;
  abilityName: string;
}

export function parseReminderTime(time: string): number[] {
  const parts: string[] = time.split(':');
  return [Number(parts[0]), Number(parts[1])];
}

export function buildReminderAlarm(habit: Habit, notificationId: number): ReminderAlarmPlan {
  const hm: number[] = parseReminderTime(habit.reminderTime);
  let daysOfWeek: number[] = [];
  if (habit.frequency === 'weekly' && habit.weekdays.length > 0) {
    daysOfWeek = habit.weekdays.map((d: number) => d === 0 ? 7 : d);
  } else {
    daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
  }
  return {
    hour: hm[0],
    minute: hm[1],
    daysOfWeek: daysOfWeek,
    title: habit.emoji + ' ' + habit.name,
    content: '别忘了今天的习惯打卡哦',
    notificationId: notificationId
  };
}

export function toReminderRequest(plan: ReminderAlarmPlan): reminderAgentManager.ReminderRequestAlarm {
  const request: reminderAgentManager.ReminderRequestAlarm = {
    reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
    hour: plan.hour,
    minute: plan.minute,
    daysOfWeek: plan.daysOfWeek,
    title: plan.title,
    content: plan.content,
    notificationId: plan.notificationId,
    snoozeTimes: 0,
    ringDuration: 0,
    actionButton: []
  };
  if (plan.wantAgent !== undefined) {
    request.wantAgent = plan.wantAgent;
  }
  return request;
}
