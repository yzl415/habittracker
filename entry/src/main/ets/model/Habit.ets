/**
 * 习惯数据模型与日期工具
 */

/** 频率类型：每天 / 每周指定星期几 */
export type FrequencyType = 'daily' | 'weekly';

/** 时段：随时 / 早 / 午 / 晚 */
export type TimeOfDay = 'anytime' | 'morning' | 'afternoon' | 'evening';

/** 单个习惯 */
@Observed
export class Habit {
  id: string;
  name: string;
  emoji: string;
  color: string;
  createdAt: string;          // YYYY-MM-DD
  checkedDates: string[];     // 已“完成”的日期（达标日），YYYY-MM-DD，升序
  frequency: FrequencyType;   // 频率类型
  weekdays: number[];         // frequency=weekly 时生效，0=周日 ... 6=周六
  reminderEnabled: boolean;   // 是否开启提醒
  reminderTime: string;       // 提醒时间 HH:mm
  reminderId: number;         // 系统提醒 id，-1 表示无
  archived: boolean;          // 是否归档
  sortOrder: number;          // 排序权重，越小越靠前
  targetCount: number;        // 每日目标次数/数量，1=普通打卡
  unit: string;               // 计量单位，如 杯/分钟/页，空串表示纯打卡
  dailyValues: Record<string, number>; // 量化习惯每日累计进度
  timeOfDay: TimeOfDay;       // 时段分组

  constructor(id: string, name: string, emoji: string, color: string,
    createdAt: string, checkedDates: string[], frequency: FrequencyType,
    weekdays: number[], reminderEnabled: boolean, reminderTime: string,
    reminderId: number, archived: boolean, sortOrder: number,
    targetCount: number, unit: string, dailyValues: Record<string, number>,
    timeOfDay: TimeOfDay) {
    this.id = id;
    this.name = name;
    this.emoji = emoji;
    this.color = color;
    this.createdAt = createdAt;
    this.checkedDates = checkedDates;
    this.frequency = frequency;
    this.weekdays = weekdays;
    this.reminderEnabled = reminderEnabled;
    this.reminderTime = reminderTime;
    this.reminderId = reminderId;
    this.archived = archived;
    this.sortOrder = sortOrder;
    this.targetCount = targetCount;
    this.unit = unit;
    this.dailyValues = dailyValues;
    this.timeOfDay = timeOfDay;
  }
}

/** 习惯模板（热门预设，用于快速创建） */
export class HabitTemplate {
  name: string;
  emoji: string;
  color: string;
  targetCount: number;
  unit: string;

  constructor(name: string, emoji: string, color: string, targetCount: number, unit: string) {
    this.name = name;
    this.emoji = emoji;
    this.color = color;
    this.targetCount = targetCount;
    this.unit = unit;
  }
}

/** 预设模板列表（参考热门习惯 App 常见项） */
export const HABIT_TEMPLATES: HabitTemplate[] = [
  new HabitTemplate('喝水', '💧', '#06B6D4', 8, '杯'),
  new HabitTemplate('阅读', '📚', '#F59E0B', 30, '分钟'),
  new HabitTemplate('运动', '🏃', '#22C55E', 1, ''),
  new HabitTemplate('冥想', '🧘', '#A855F7', 10, '分钟'),
  new HabitTemplate('早起', '☀️', '#FF7B54', 1, ''),
  new HabitTemplate('背单词', '✍️', '#0A59F7', 20, '个'),
  new HabitTemplate('俯卧撑', '💪', '#F43F5E', 30, '个'),
  new HabitTemplate('早睡', '😴', '#6366F1', 1, ''),
  new HabitTemplate('喝水提醒', '🥤', '#06B6D4', 6, '次'),
  new HabitTemplate('走路', '🚶', '#22C55E', 6000, '步'),
  new HabitTemplate('护肤', '🧴', '#EC4899', 1, ''),
  new HabitTemplate('记账', '💰', '#F59E0B', 1, '')
];

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

/** 星期短名（0=周日） */
export const WEEK_SHORT: string[] = ['日', '一', '二', '三', '四', '五', '六'];

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

/** 把 YYYY-MM-DD 解析为 Date（本地零点） */
export function parseDate(dateStr: string): Date {
  const parts: string[] = dateStr.split('-');
  return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
}

/** 在某日期字符串基础上加 n 天，返回新字符串 */
export function addDays(dateStr: string, n: number): string {
  const d: Date = parseDate(dateStr);
  d.setDate(d.getDate() + n);
  return toDateStr(d);
}

/** 某日期是星期几（0=周日） */
export function weekdayOf(dateStr: string): number {
  return parseDate(dateStr).getDay();
}

/** 该习惯在某天是否需要执行（按频率判断） */
export function isScheduledOn(h: Habit, dateStr: string): boolean {
  if (h.frequency === 'weekly') {
    if (h.weekdays.length === 0) {
      return true;
    }
    return h.weekdays.indexOf(weekdayOf(dateStr)) >= 0;
  }
  return true;
}

/** 今天是否需要执行 */
export function isScheduledToday(h: Habit): boolean {
  return isScheduledOn(h, todayStr());
}

/** 频率的中文描述 */
export function frequencyLabel(h: Habit): string {
  if (h.frequency === 'daily' || h.weekdays.length === 0 || h.weekdays.length === 7) {
    return '每天';
  }
  const sorted: number[] = h.weekdays.slice().sort((a: number, b: number) => a - b);
  // 工作日 / 周末快捷描述
  if (sorted.length === 5 && sorted.join() === '1,2,3,4,5') {
    return '工作日';
  }
  if (sorted.length === 2 && sorted.join() === '0,6') {
    return '周末';
  }
  return '每周 ' + sorted.map((d: number) => WEEK_SHORT[d]).join(' ');
}

/**
 * 计算当前连续打卡天数（按计划日计算，跳过非计划日）。
 * 从今天（若今天是计划日且已打卡）或最近一个计划日往前推。
 */
export function currentStreak(h: Habit): number {
  if (h.checkedDates.length === 0) {
    return 0;
  }
  const set: Set<string> = new Set(h.checkedDates);
  let cursor: string = todayStr();
  // 找到今天或之前最近的一个计划日作为起点
  let guard: number = 0;
  while (!isScheduledOn(h, cursor) && guard < 400) {
    cursor = addDays(cursor, -1);
    guard++;
  }
  // 若起点（最近计划日）尚未打卡，则连续从上一个计划日往前算
  if (!set.has(cursor)) {
    cursor = addDays(cursor, -1);
  }
  let count: number = 0;
  guard = 0;
  while (guard < 4000) {
    guard++;
    if (!isScheduledOn(h, cursor)) {
      cursor = addDays(cursor, -1);
      continue;
    }
    if (set.has(cursor)) {
      count++;
      cursor = addDays(cursor, -1);
    } else {
      break;
    }
  }
  return count;
}

/** 历史最长连续天数（按计划日，连续的计划日均打卡） */
export function longestStreak(h: Habit): number {
  if (h.checkedDates.length === 0) {
    return 0;
  }
  const set: Set<string> = new Set(h.checkedDates);
  const sorted: string[] = h.checkedDates.slice().sort();
  let best: number = 0;
  let cur: number = 0;
  let cursor: string = sorted[0];
  const last: string = sorted[sorted.length - 1];
  let guard: number = 0;
  while (cursor <= last && guard < 8000) {
    guard++;
    if (isScheduledOn(h, cursor)) {
      if (set.has(cursor)) {
        cur++;
        if (cur > best) {
          best = cur;
        }
      } else {
        cur = 0;
      }
    }
    cursor = addDays(cursor, 1);
  }
  return best;
}

/** 该习惯是否为量化型（目标 > 1 或带单位） */
export function isQuantifiable(h: Habit): boolean {
  return h.targetCount > 1;
}

/** 取某天的进度值 */
export function valueOn(h: Habit, dateStr: string): number {
  if (h.dailyValues === undefined) {
    return 0;
  }
  const v: number | undefined = h.dailyValues[dateStr];
  return v !== undefined ? v : 0;
}

/** 今日进度值 */
export function valueToday(h: Habit): number {
  return valueOn(h, todayStr());
}

/** 时段中文名 */
export function timeOfDayLabel(t: TimeOfDay): string {
  if (t === 'morning') {
    return '上午';
  }
  if (t === 'afternoon') {
    return '下午';
  }
  if (t === 'evening') {
    return '晚上';
  }
  return '全天';
}

/** 时段对应的 emoji */
export function timeOfDayIcon(t: TimeOfDay): string {
  if (t === 'morning') {
    return '🌅';
  }
  if (t === 'afternoon') {
    return '☀️';
  }
  if (t === 'evening') {
    return '🌙';
  }
  return '📋';
}

/** 近 n 个“计划日”的完成率，返回 0~100 整数 */
export function completionRate(h: Habit, days: number): number {
  const set: Set<string> = new Set(h.checkedDates);
  let scheduled: number = 0;
  let hit: number = 0;
  let cursor: string = todayStr();
  let guard: number = 0;
  while (scheduled < days && guard < days * 8 + 30) {
    guard++;
    // 不早于创建日
    if (cursor < h.createdAt) {
      break;
    }
    if (isScheduledOn(h, cursor)) {
      scheduled++;
      if (set.has(cursor)) {
        hit++;
      }
    }
    cursor = addDays(cursor, -1);
  }
  if (scheduled === 0) {
    return 0;
  }
  return Math.round(hit / scheduled * 100);
}
