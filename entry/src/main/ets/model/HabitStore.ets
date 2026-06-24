/**
 * 习惯数据仓库：内存状态 + preferences 持久化（存 JSON）
 * 单例，全局共享同一份 habits 数组引用。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Habit, FrequencyType, TimeOfDay, todayStr } from '../model/Habit';

const STORE_NAME: string = 'habit_store';
const KEY_HABITS: string = 'habits';
const KEY_THEME_DARK: string = 'theme_dark';
const KEY_PRIVACY_AGREED: string = 'privacy_agreed';
const KEY_ONBOARDED: string = 'onboarded';

export class HabitStore {
  private static instance: HabitStore | null = null;
  private store: preferences.Preferences | null = null;
  habits: Habit[] = [];
  themeDark: boolean = false;
  privacyAgreed: boolean = false;
  onboarded: boolean = false;

  static getInstance(): HabitStore {
    if (HabitStore.instance === null) {
      HabitStore.instance = new HabitStore();
    }
    return HabitStore.instance;
  }

  /** 初始化：打开 preferences 并读取已有数据 */
  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.store !== null) {
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, STORE_NAME);
      const raw: string = await this.store.get(KEY_HABITS, '[]') as string;
      this.habits = this.parse(raw);
      this.themeDark = await this.store.get(KEY_THEME_DARK, false) as boolean;
      this.privacyAgreed = await this.store.get(KEY_PRIVACY_AGREED, false) as boolean;
      this.onboarded = await this.store.get(KEY_ONBOARDED, false) as boolean;
    } catch (e) {
      // 预览器等环境可能拿不到 preferences，降级为内存模式，UI 仍可用
      this.store = null;
      this.habits = [];
    }
  }

  private parse(raw: string): Habit[] {
    try {
      const arr: Habit[] = JSON.parse(raw) as Habit[];
      // 还原成 Habit 实例，补全可能缺失的字段（兼容旧数据）
      const list: Habit[] = arr.map((h: Habit, idx: number) => new Habit(
        h.id,
        h.name,
        h.emoji,
        h.color,
        h.createdAt,
        h.checkedDates !== undefined ? h.checkedDates : [],
        h.frequency !== undefined ? h.frequency : 'daily' as FrequencyType,
        h.weekdays !== undefined ? h.weekdays : [],
        h.reminderEnabled !== undefined ? h.reminderEnabled : false,
        h.reminderTime !== undefined ? h.reminderTime : '20:00',
        h.reminderId !== undefined ? h.reminderId : -1,
        h.archived !== undefined ? h.archived : false,
        h.sortOrder !== undefined ? h.sortOrder : idx,
        h.targetCount !== undefined && h.targetCount > 0 ? h.targetCount : 1,
        h.unit !== undefined ? h.unit : '',
        h.dailyValues !== undefined ? h.dailyValues : {},
        h.timeOfDay !== undefined ? h.timeOfDay : 'anytime' as TimeOfDay
      ));
      list.sort((a: Habit, b: Habit) => a.sortOrder - b.sortOrder);
      return list;
    } catch (e) {
      return [];
    }
  }

  /** 持久化当前 habits 到磁盘 */
  private async persist(): Promise<void> {
    if (this.store === null) {
      return;
    }
    await this.store.put(KEY_HABITS, JSON.stringify(this.habits));
    await this.store.flush();
  }

  getById(id: string): Habit | undefined {
    return this.habits.find((h: Habit) => h.id === id);
  }

  /** 活跃（未归档）习惯 */
  activeHabits(): Habit[] {
    return this.habits.filter((h: Habit) => !h.archived);
  }

  /** 已归档习惯 */
  archivedHabits(): Habit[] {
    return this.habits.filter((h: Habit) => h.archived);
  }

  /** 下一个排序权重 */
  private nextOrder(): number {
    let max: number = -1;
    this.habits.forEach((h: Habit) => {
      if (h.sortOrder > max) {
        max = h.sortOrder;
      }
    });
    return max + 1;
  }

  async add(habit: Habit): Promise<void> {
    habit.sortOrder = this.nextOrder();
    this.habits.push(habit);
    await this.persist();
  }

  async update(habit: Habit): Promise<void> {
    const idx: number = this.habits.findIndex((h: Habit) => h.id === habit.id);
    if (idx >= 0) {
      this.habits[idx] = habit;
      await this.persist();
    }
  }

  async remove(id: string): Promise<void> {
    this.habits = this.habits.filter((h: Habit) => h.id !== id);
    await this.persist();
  }

  /** 归档 / 取消归档 */
  async setArchived(id: string, archived: boolean): Promise<void> {
    const h: Habit | undefined = this.getById(id);
    if (h !== undefined) {
      h.archived = archived;
      await this.persist();
    }
  }

  /** 当日是否已打卡 */
  isCheckedOn(h: Habit, dateStr: string): boolean {
    return h.checkedDates.indexOf(dateStr) >= 0;
  }

  /** 设置某天的打卡状态（用于详情页补卡 / 取消）。量化习惯会同步进度值 */
  async setChecked(id: string, dateStr: string, checked: boolean): Promise<void> {
    const h: Habit | undefined = this.getById(id);
    if (h === undefined) {
      return;
    }
    const idx: number = h.checkedDates.indexOf(dateStr);
    const dates: string[] = h.checkedDates.slice();
    const dv: Record<string, number> = {};
    Object.keys(h.dailyValues).forEach((k: string) => {
      dv[k] = h.dailyValues[k];
    });
    if (checked && idx < 0) {
      dates.push(dateStr);
      dates.sort();
      dv[dateStr] = h.targetCount;
    } else if (!checked && idx >= 0) {
      dates.splice(idx, 1);
      dv[dateStr] = 0;
    }
    h.checkedDates = dates;
    h.dailyValues = dv;
    await this.persist();
  }

  /** 同步达标状态：value 达到目标则标记完成，否则取消。用整体重赋触发 @Observed 观测 */
  private syncChecked(h: Habit, dateStr: string): void {
    const reached: boolean = (h.dailyValues[dateStr] !== undefined ? h.dailyValues[dateStr] : 0) >= h.targetCount;
    const idx: number = h.checkedDates.indexOf(dateStr);
    if (reached && idx < 0) {
      const arr: string[] = h.checkedDates.slice();
      arr.push(dateStr);
      arr.sort();
      h.checkedDates = arr;
    } else if (!reached && idx >= 0) {
      const arr: string[] = h.checkedDates.slice();
      arr.splice(idx, 1);
      h.checkedDates = arr;
    }
  }

  /** 量化习惯：今日进度 +delta（可为负），自动同步达标状态 */
  async addValue(id: string, delta: number): Promise<void> {
    const h: Habit | undefined = this.getById(id);
    if (h === undefined) {
      return;
    }
    const today: string = todayStr();
    const cur: number = h.dailyValues[today] !== undefined ? h.dailyValues[today] : 0;
    let next: number = cur + delta;
    if (next < 0) {
      next = 0;
    }
    if (next > h.targetCount) {
      next = h.targetCount;
    }
    // 整体重赋 dailyValues，触发 @Observed/@ObjectLink 观测，使量化环原地平滑更新
    const dv: Record<string, number> = {};
    Object.keys(h.dailyValues).forEach((k: string) => {
      dv[k] = h.dailyValues[k];
    });
    dv[today] = next;
    h.dailyValues = dv;
    this.syncChecked(h, today);
    await this.persist();
  }

  /** 持久化（供 service 更新 reminderId 后调用） */
  async save(): Promise<void> {
    await this.persist();
  }

  /** 保存主题偏好 */
  async setThemeDark(dark: boolean): Promise<void> {
    this.themeDark = dark;
    if (this.store === null) {
      return;
    }
    await this.store.put(KEY_THEME_DARK, dark);
    await this.store.flush();
  }

  /** 记录已同意隐私政策 */
  async setPrivacyAgreed(): Promise<void> {
    this.privacyAgreed = true;
    if (this.store === null) {
      return;
    }
    await this.store.put(KEY_PRIVACY_AGREED, true);
    await this.store.flush();
  }

  /** 记录已看过欢迎页 */
  async setOnboarded(): Promise<void> {
    this.onboarded = true;
    if (this.store === null) {
      return;
    }
    await this.store.put(KEY_ONBOARDED, true);
    await this.store.flush();
  }

  /** 按给定的活跃习惯 id 顺序重新排序 */
  async setOrder(orderedIds: string[]): Promise<void> {
    orderedIds.forEach((id: string, idx: number) => {
      const h: Habit | undefined = this.getById(id);
      if (h !== undefined) {
        h.sortOrder = idx;
      }
    });
    this.habits.sort((a: Habit, b: Habit) => a.sortOrder - b.sortOrder);
    await this.persist();
  }

  /** 导出全部数据为 JSON 字符串 */
  exportJson(): string {
    return JSON.stringify(this.habits);
  }

  /** 从 JSON 字符串导入并覆盖现有数据 */
  async importFromJson(raw: string): Promise<boolean> {
    const list: Habit[] = this.parse(raw);
    if (list.length === 0 && raw.indexOf('"id"') < 0) {
      return false;
    }
    this.habits = list;
    await this.persist();
    return true;
  }

  /** 切换某习惯今天的打卡状态，返回切换后是否为已打卡。量化习惯直接置满/清零 */
  async toggleToday(id: string): Promise<boolean> {
    const habit: Habit | undefined = this.getById(id);
    if (habit === undefined) {
      return false;
    }
    const today: string = todayStr();
    const idx: number = habit.checkedDates.indexOf(today);
    const dates: string[] = habit.checkedDates.slice();
    const dv: Record<string, number> = {};
    Object.keys(habit.dailyValues).forEach((k: string) => {
      dv[k] = habit.dailyValues[k];
    });
    let checked: boolean;
    if (idx >= 0) {
      dates.splice(idx, 1);
      dv[today] = 0;
      checked = false;
    } else {
      dates.push(today);
      dates.sort();
      dv[today] = habit.targetCount;
      checked = true;
    }
    habit.checkedDates = dates;
    habit.dailyValues = dv;
    await this.persist();
    return checked;
  }
}
