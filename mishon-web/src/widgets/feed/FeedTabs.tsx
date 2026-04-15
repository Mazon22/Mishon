import { ContentTabs } from '../../shared/ui/ContentTabs';

type FeedTabsProps = {
  value: 'for-you' | 'following';
  onChange: (value: 'for-you' | 'following') => void;
};

const items = [
  { value: 'for-you', label: 'Для вас' },
  { value: 'following', label: 'Подписки' },
] as const;

export function FeedTabs({ value, onChange }: FeedTabsProps) {
  return <ContentTabs ariaLabel="Режимы ленты" items={items} value={value} onChange={onChange} />;
}
