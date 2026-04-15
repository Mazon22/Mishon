import { ContentTabs } from '../../../shared/ui/ContentTabs';

export type PeopleTab = 'for-you' | 'requests' | 'friends' | 'discover';

type PeopleTabsProps = {
  value: PeopleTab;
  onChange: (value: PeopleTab) => void;
};

const items: Array<{ value: PeopleTab; label: string }> = [
  { value: 'for-you', label: 'Для вас' },
  { value: 'requests', label: 'Запросы' },
  { value: 'friends', label: 'Друзья' },
  { value: 'discover', label: 'Рекомендации' },
];

export function PeopleTabs({ value, onChange }: PeopleTabsProps) {
  return <ContentTabs ariaLabel="Разделы людей" items={items} value={value} onChange={onChange} />;
}
