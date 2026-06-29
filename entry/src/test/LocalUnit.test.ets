import { describe, it, expect } from '@ohos/hypium';
import { Habit } from '../main/ets/model/Habit';
import { buildReminderAlarm, parseReminderTime, toReminderRequest } from '../main/ets/model/ReminderPlanner';

export default function localUnitTest() {
  describe('ReminderPlanner', () => {
    it('test_parseReminderTime_returns_hour_and_minute', 0, () => {
      const parts: number[] = parseReminderTime('07:30');

      expect(parts[0]).assertEqual(7);
      expect(parts[1]).assertEqual(30);
    });

    it('test_buildReminderAlarm_uses_weekly_days_when_weekly_habit', 0, () => {
      const habit: Habit = new Habit('1', '阅读', '📚', '#F59E0B', '2026-06-29', [], 'weekly', [1, 3, 5], true,
        '20:00', -1, false, 0, 1, '', {}, 'anytime');

      const plan = buildReminderAlarm(habit, 123);

      expect(plan.daysOfWeek).assertDeepEquals([1, 3, 5]);
    });

    it('test_toReminderRequest_keeps_notification_metadata', 0, () => {
      const request = toReminderRequest({
        hour: 20,
        minute: 0,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        title: '📚 阅读',
        content: '别忘了今天的习惯打卡哦',
        notificationId: 42
      });

      expect(request.notificationId).assertEqual(42);
    });

    it('test_toReminderRequest_uses_valid_want_agent_when_provided', 0, () => {
      const request = toReminderRequest({
        hour: 20,
        minute: 0,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        title: '📚 阅读',
        content: '别忘了今天的习惯打卡哦',
        notificationId: 43,
        wantAgent: {
          pkgName: 'com.example.habittracker',
          abilityName: 'EntryAbility'
        }
      });

      expect(request.wantAgent?.abilityName).assertEqual('EntryAbility');
    });
  });
}
