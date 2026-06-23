/**
 * 成就徽章系统：根据习惯数据计算解锁状态与进度。
 */
import { Habit, longestStreak, isScheduledOn, addDays, todayStr } from './Habit';

/** 成就指标类型 */
export type AchievementMetric = 'checkins' | 'streak' | 'count' | 'perfect';

/** 成就定义 */
export class AchievementDef {
  id: string;
  emoji: string;
  title: string;
  desc: string;
  metric: AchievementMetric;
  target: number;

  constructor(id: string, emoji: string, title: string, desc: string,
    metric: AchievementMetric, target: number) {
    this.id = id;
    this.emoji = emoji;
    this.title = title;
    this.desc = desc;
    this.metric = metric;
    this.target = target;
  }
}

/** 成就状态（含当前进度） */
export class AchievementStatus {
  def: AchievementDef;
  current: number;
  unlocked: boolean;

  constructor(def: AchievementDef, current: number, unlocked: boolean) {
    this.def = def;
    this.current = current;
    this.unlocked = unlocked;
  }
}

/** 全部成就定义（按解锁难度递增） */
export const ACHIEVEMENTS: AchievementDef[] = [
  new AchievementDef('start', '✨', '开始改变', '创建第一个习惯', 'count', 1),
  new AchievementDef('first', '🌟', '初次启程', '完成第一次打卡', 'checkins', 1),
  new AchievementDef('streak3', '🌱', '三日之约', '任意习惯连续 3 天', 'streak', 3),
  new AchievementDef('check10', '💧', '小有所成', '累计打卡 10 次', 'checkins', 10),
  new AchievementDef('multi3', '🎯', '多线并进', '同时拥有 3 个习惯', 'count', 3),
  new AchievementDef('streak7', '📅', '一周坚持', '任意习惯连续 7 天', 'streak', 7),
  new AchievementDef('perfect1', '☀️', '完美一天', '某天完成全部习惯', 'perfect', 1),
  new AchievementDef('check50', '🔥', '渐入佳境', '累计打卡 50 次', 'checkins', 50),
  new AchievementDef('multi5', '🚀', '自律达人', '同时拥有 5 个习惯', 'count', 5),
  new AchievementDef('streak30', '🏅', '月度冠军', '任意习惯连续 30 天', 'streak', 30),
  new AchievementDef('perfect7', '🌈', '完美一周', '累计 7 个完美日', 'perfect', 7),
  new AchievementDef('check100', '💯', '百炼成钢', '累计打卡 100 次', 'checkins', 100),
  new AchievementDef('streak100', '🏆', '百日传奇', '任意习惯连续 100 天', 'streak', 100),
  new AchievementDef('check365', '👑', '持之以恒', '累计打卡 365 次', 'checkins', 365)
];

/** 累计打卡次数 */
function totalCheckins(habits: Habit[]): number {
  let n: number = 0;
  habits.forEach((h: Habit) => n += h.checkedDates.length);
  return n;
}

/** 历史最佳连续 */
function bestStreak(habits: Habit[]): number {
  let best: number = 0;
  habits.forEach((h: Habit) => {
    const s: number = longestStreak(h);
    if (s > best) {
      best = s;
    }
  });
  return best;
}

/** 完美日数量：某天所有“当天应打卡且已存在”的习惯都完成 */
function perfectDays(habits: Habit[]): number {
  if (habits.length === 0) {
    return 0;
  }
  // 找最早创建日
  let earliest: string = todayStr();
  habits.forEach((h: Habit) => {
    if (h.createdAt < earliest) {
      earliest = h.createdAt;
    }
  });
  const checkedSets: Set<string>[] = habits.map((h: Habit) => new Set(h.checkedDates));
  let count: number = 0;
  let cursor: string = earliest;
  const today: string = todayStr();
  let guard: number = 0;
  while (cursor <= today && guard < 4000) {
    guard++;
    let due: number = 0;
    let done: number = 0;
    for (let i = 0; i < habits.length; i++) {
      const h: Habit = habits[i];
      if (cursor >= h.createdAt && isScheduledOn(h, cursor)) {
        due++;
        if (checkedSets[i].has(cursor)) {
          done++;
        }
      }
    }
    if (due > 0 && done === due) {
      count++;
    }
    cursor = addDays(cursor, 1);
  }
  return count;
}

/** 计算全部成就状态 */
export function evaluateAchievements(habits: Habit[]): AchievementStatus[] {
  const checkins: number = totalCheckins(habits);
  const streak: number = bestStreak(habits);
  const count: number = habits.length;
  const perfect: number = perfectDays(habits);
  return ACHIEVEMENTS.map((def: AchievementDef) => {
    let cur: number = 0;
    if (def.metric === 'checkins') {
      cur = checkins;
    } else if (def.metric === 'streak') {
      cur = streak;
    } else if (def.metric === 'count') {
      cur = count;
    } else {
      cur = perfect;
    }
    return new AchievementStatus(def, cur, cur >= def.target);
  });
}

/** 已解锁数量 */
export function unlockedCount(habits: Habit[]): number {
  let n: number = 0;
  evaluateAchievements(habits).forEach((s: AchievementStatus) => {
    if (s.unlocked) {
      n++;
    }
  });
  return n;
}
