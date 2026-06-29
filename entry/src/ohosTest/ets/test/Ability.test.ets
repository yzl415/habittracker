import { describe, it, expect } from '@ohos/hypium';
import { parseReminderTime } from '../../../main/ets/model/ReminderPlanner';

export default function test() {
  describe('ReminderPlannerAbility', () => {
    it('test_parseReminderTime_returns_expected_parts', 0, () => {
      const parts: number[] = parseReminderTime('20:05');

      expect(parts[0]).assertEqual(20);
      expect(parts[1]).assertEqual(5);
    });
  }
}
