import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { Habit, isScheduledToday, todayStr } from '../model/Habit';

const STORE_NAME: string = 'habit_store';
const KEY_HABITS: string = 'habits';

/** 卡片展示数据 */
class CardData {
  doneCount: number = 0;
  totalCount: number = 0;
  ratio: number = 0;      // 0~100
  dateLabel: string = '';
  emojis: string = '';    // 今日待办前几个 emoji 拼接
  allDone: boolean = false;
}

/** 读取习惯数据并计算今日卡片展示内容 */
async function buildCardData(context: Context): Promise<CardData> {
  const data: CardData = new CardData();
  const d: Date = new Date();
  const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  data.dateLabel = `${d.getMonth() + 1}月${d.getDate()}日 ${week[d.getDay()]}`;
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const raw: string = await store.get(KEY_HABITS, '[]') as string;
    const arr: Habit[] = JSON.parse(raw) as Habit[];
    const today: string = todayStr();
    const due: Habit[] = arr.filter((h: Habit) =>
      (h.archived === undefined || !h.archived) && isScheduledToday(h));
    let done: number = 0;
    const icons: string[] = [];
    due.forEach((h: Habit) => {
      const checked: boolean = h.checkedDates !== undefined && h.checkedDates.indexOf(today) >= 0;
      if (checked) {
        done++;
      }
      if (icons.length < 5) {
        icons.push(h.emoji);
      }
    });
    data.doneCount = done;
    data.totalCount = due.length;
    data.ratio = due.length === 0 ? 0 : Math.round(done / due.length * 100);
    data.emojis = icons.join(' ');
    data.allDone = due.length > 0 && done === due.length;
  } catch (e) {
    const err: BusinessError = e as BusinessError;
    console.warn(`widget buildCardData failed: ${err.code} ${err.message}`);
  }
  return data;
}

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    // 同步先返回占位，随后异步刷新真实数据
    const placeholder: formBindingData.FormBindingData =
      formBindingData.createFormBindingData(new CardData());
    const formId: string = want.parameters?.['ohos.extra.param.key.form_identity'] as string;
    if (formId !== undefined) {
      this.refresh(formId);
    }
    return placeholder;
  }

  onUpdateForm(formId: string): void {
    this.refresh(formId);
  }

  // 卡片可见性变化时刷新（回到桌面等）
  onChangeFormVisibility(newStatus: Record<string, number>): void {
    Object.keys(newStatus).forEach((formId: string) => {
      this.refresh(formId);
    });
  }

  private refresh(formId: string): void {
    buildCardData(this.context).then((data: CardData) => {
      const binding: formBindingData.FormBindingData = formBindingData.createFormBindingData(data);
      formProvider.updateForm(formId, binding).catch((err: BusinessError) => {
        console.warn(`updateForm failed: ${err.code} ${err.message}`);
      });
    });
  }

  onRemoveForm(formId: string): void {
  }
}
