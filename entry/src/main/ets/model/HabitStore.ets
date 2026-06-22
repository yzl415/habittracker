/**
 * 习惯数据仓库：内存状态 + preferences 持久化（存 JSON）
 * 单例，全局共享同一份 habits 数组引用。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Habit, todayStr } from '../model/Habit';

const STORE_NAME: string = 'habit_store';
const KEY_HABITS: string = 'habits';

export class HabitStore {
  private static instance: HabitStore | null = null;
  private store: preferences.Preferences | null = null;
  habits: Habit[] = [];

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
    } catch (e) {
      // 预览器等环境可能拿不到 preferences，降级为内存模式，UI 仍可用
      this.store = null;
      this.habits = [];
    }
  }

  private parse(raw: string): Habit[] {
    try {
      const arr: Habit[] = JSON.parse(raw) as Habit[];
      // 还原成 Habit 实例，补全可能缺失的字段
      return arr.map((h: Habit) => new Habit(
        h.id, h.name, h.emoji, h.color, h.createdAt,
        h.checkedDates !== undefined ? h.checkedDates : []
      ));
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

  async add(habit: Habit): Promise<void> {
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

  /** 切换某习惯今天的打卡状态，返回切换后是否为已打卡 */
  async toggleToday(id: string): Promise<boolean> {
    const habit: Habit | undefined = this.getById(id);
    if (habit === undefined) {
      return false;
    }
    const today: string = todayStr();
    const idx: number = habit.checkedDates.indexOf(today);
    let checked: boolean;
    if (idx >= 0) {
      habit.checkedDates.splice(idx, 1);
      checked = false;
    } else {
      habit.checkedDates.push(today);
      habit.checkedDates.sort();
      checked = true;
    }
    await this.persist();
    return checked;
  }
}
