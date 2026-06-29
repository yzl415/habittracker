import { describe, it, expect } from '@ohos/hypium';
import { Habit } from '../../../main/ets/model/Habit';
import { buildReminderAlarm } from '../../../main/ets/model/ReminderPlanner';

export default function test() {
  describe('ReminderPlannerOhos', () => {
    it('test_buildReminderAlarm_maps_weekdays_to_alarm_days', 0, () => {
      const habit: Habit = new Habit('2', '运动', '🏃', '#22C55E', '2026-06-29', [], 'weekly', [0, 6], true,
        '06:30', -1, false, 0, 1, '', {}, 'morning');

      const plan = buildReminderAlarm(habit, 100);

      expect(plan.daysOfWeek).assertDeepEquals([7, 6]);
    });
  });
}
