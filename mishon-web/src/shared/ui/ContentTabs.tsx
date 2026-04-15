import { startTransition } from 'react';

type ContentTabItem<T extends string> = {
  value: T;
  label: string;
  disabled?: boolean;
};

type ContentTabsProps<T extends string> = {
  ariaLabel: string;
  value: T;
  items: ReadonlyArray<ContentTabItem<T>>;
  onChange: (value: T) => void;
  className?: string;
};

export function ContentTabs<T extends string>({
  ariaLabel,
  value,
  items,
  onChange,
  className = '',
}: ContentTabsProps<T>) {
  const countClass = `content-tabs--${Math.min(items.length, 4)}`;

  return (
    <div className={['content-tabs', countClass, className].filter(Boolean).join(' ')} role="tablist" aria-label={ariaLabel}>
      {items.map((item) => {
        const isActive = item.value === value;

        return (
          <button
            key={item.value}
            aria-selected={isActive}
            className={`content-tabs__item${isActive ? ' content-tabs__item--active' : ''}`}
            disabled={item.disabled}
            role="tab"
            type="button"
            onClick={() => startTransition(() => onChange(item.value))}
          >
            <span>{item.label}</span>
          </button>
        );
      })}
    </div>
  );
}
