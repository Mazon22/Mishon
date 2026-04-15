import { ContentTabs } from '../../../shared/ui/ContentTabs';
import type { NotificationTab } from '../lib/notificationMeta';

type NotificationTabsProps = {
  value: NotificationTab;
  onChange: (value: NotificationTab) => void;
};

const tabs: Array<{ value: NotificationTab; label: string }> = [
  { value: 'all', label: 'Все' },
  { value: 'mentions', label: 'Упоминания' },
];

export function NotificationTabs({ value, onChange }: NotificationTabsProps) {
  return <ContentTabs ariaLabel="Фильтр уведомлений" items={tabs} value={value} onChange={onChange} />;
}
