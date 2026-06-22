/**
 * 习惯数据模型与日期工具
 */

/** 单个习惯 */
export class Habit {
  id: string;
  name: string;
  emoji: string;
  color: string;
  createdAt: string;        // YYYY-MM-DD
  checkedDates: string[];   // 已打卡日期，YYYY-MM-DD，升序

  constructor(id: string, name: string, emoji: string, color: string,
    createdAt: string, checkedDates: string[]) {
    this.id = id;
    this.name = name;
    this.emoji = emoji;
    this.color = color;
    this.createdAt = createdAt;
    this.checkedDates = checkedDates;
  }
}

/** 预设主题色 */
export const HABIT_COLORS: string[] = [
  '#0A59F7', '#FF7B54', '#22C55E', '#F43F5E',
  '#A855F7', '#06B6D4', '#F59E0B', '#EC4899'
];

/** 预设 emoji */
export const HABIT_EMOJIS: string[] = [
  '💪', '📚', '🏃', '💧', '🧘', '🍎', '😴', '✍️',
  '🎯', '🦷', '🌱', '🎸', '💊', '🚭', '🧹', '☀️'
];

/** 把 Date 格式化为 YYYY-MM-DD（本地时区） */
export function toDateStr(d: Date): string {
  const y: number = d.getFullYear();
  const m: number = d.getMonth() + 1;
  const day: number = d.getDate();
  const mm: string = m < 10 ? '0' + m : '' + m;
  const dd: string = day < 10 ? '0' + day : '' + day;
  return `${y}-${mm}-${dd}`;
}

/** 今天的日期字符串 */
export function todayStr(): string {
  return toDateStr(new Date());
}

/** 在某日期字符串基础上加 n 天，返回新字符串 */
export function addDays(dateStr: string, n: number): string {
  const parts: string[] = dateStr.split('-');
  const d: Date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  d.setDate(d.getDate() + n);
  return toDateStr(d);
}

/** 计算当前连续打卡天数（从今天或昨天往前连续） */
export function currentStreak(checked: string[]): number {
  if (checked.length === 0) {
    return 0;
  }
  const set: Set<string> = new Set(checked);
  const today: string = todayStr();
  // 若今天没打卡，从昨天开始算，保证连续不被当天未打卡打断
  let cursor: string = set.has(today) ? today : addDays(today, -1);
  if (!set.has(cursor)) {
    return 0;
  }
  let count: number = 0;
  while (set.has(cursor)) {
    count++;
    cursor = addDays(cursor, -1);
  }
  return count;
}

/** 历史最长连续天数 */
export function longestStreak(checked: string[]): number {
  if (checked.length === 0) {
    return 0;
  }
  const sorted: string[] = checked.slice().sort();
  let best: number = 1;
  let cur: number = 1;
  for (let i = 1; i < sorted.length; i++) {
    if (addDays(sorted[i - 1], 1) === sorted[i]) {
      cur++;
      if (cur > best) {
        best = cur;
      }
    } else {
      cur = 1;
    }
  }
  return best;
}

/** 近 n 天完成率（含今天），返回 0~100 整数 */
export function completionRate(checked: string[], days: number): number {
  const set: Set<string> = new Set(checked);
  let hit: number = 0;
  let cursor: string = todayStr();
  for (let i = 0; i < days; i++) {
    if (set.has(cursor)) {
      hit++;
    }
    cursor = addDays(cursor, -1);
  }
  return Math.round(hit / days * 100);
}
