import type { AppIconName } from '../../shared/ui/AppIcon';

export type NavIconName = Extract<
  AppIconName,
  'feed' | 'chats' | 'friends' | 'profile' | 'settings' | 'notifications' | 'shield' | 'bookmark'
>;

export type SidebarNavItem = {
  to: string;
  label: string;
  icon: NavIconName;
  badge?: number;
};
