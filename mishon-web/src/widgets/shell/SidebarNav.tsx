import { AppIcon } from '../../shared/ui/AppIcon';
import type { SidebarNavItem as SidebarNavItemType } from './types';
import { SidebarNavItem } from './SidebarNavItem';

type SidebarNavProps = {
  items: SidebarNavItemType[];
  onCompose: () => void;
};

export function SidebarNav({ items, onCompose }: SidebarNavProps) {
  return (
    <>
      <nav className="shell__nav" aria-label="Основная навигация">
        {items.map((item) => (
          <SidebarNavItem key={item.to} item={item} />
        ))}
      </nav>

      <button aria-label="Создать пост" className="primary-button primary-button--wide shell-compose" type="button" onClick={onCompose}>
        <AppIcon className="button-icon" name="compose" />
        <span>Создать пост</span>
      </button>
    </>
  );
}
