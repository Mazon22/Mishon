import { NavLink } from 'react-router-dom';

import { ShellIcon } from './ShellIcon';
import type { SidebarNavItem as SidebarNavItemType } from './types';

export function SidebarNavItem({ item }: { item: SidebarNavItemType }) {
  return (
    <NavLink
      aria-label={item.label}
      to={item.to}
      className={({ isActive }) => `nav-link${isActive ? ' nav-link--active' : ''}`}
    >
      <span className="nav-link__icon">
        <ShellIcon name={item.icon} />
      </span>
      <span className="nav-link__label">{item.label}</span>
      {item.badge ? <span className="nav-link__badge">{item.badge > 99 ? '99+' : item.badge}</span> : null}
    </NavLink>
  );
}
