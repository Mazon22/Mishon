import { AppIcon } from '../../shared/ui/AppIcon';
import type { NavIconName } from './types';

export function ShellIcon({ name }: { name: NavIconName }) {
  return <AppIcon className="shell-icon" name={name} />;
}
