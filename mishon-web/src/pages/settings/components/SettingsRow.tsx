import type { ReactNode } from 'react';

import type { AppIconName } from '../../../shared/ui/AppIcon';
import { AppIcon } from '../../../shared/ui/AppIcon';

type SettingsRowProps = {
  icon: AppIconName;
  title: string;
  description: string;
  value?: string;
  expandable?: boolean;
  expanded?: boolean;
  onClick?: () => void;
  trailing?: ReactNode;
  children?: ReactNode;
};

export function SettingsRow({
  icon,
  title,
  description,
  value,
  expandable,
  expanded,
  onClick,
  trailing,
  children,
}: SettingsRowProps) {
  return (
    <div className={`settings-row${expanded ? ' settings-row--expanded' : ''}`}>
      <div
        aria-expanded={expandable ? expanded : undefined}
        className={`settings-row__main${onClick ? ' settings-row__main--button' : ''}`}
        role={onClick ? 'button' : undefined}
        tabIndex={onClick ? 0 : undefined}
        onClick={onClick}
        onKeyDown={
          onClick
            ? (event) => {
                if (event.key === 'Enter' || event.key === ' ') {
                  event.preventDefault();
                  onClick();
                }
              }
            : undefined
        }
      >
        <div className="settings-row__icon">
          <AppIcon className="app-icon" name={icon} />
        </div>
        <div className="settings-row__copy">
          <strong>{title}</strong>
          <span>{description}</span>
        </div>
        {value ? <div className="settings-row__value">{value}</div> : null}
        {trailing ? <div className="settings-row__trailing">{trailing}</div> : null}
        {expandable ? (
          <div className={`settings-row__chevron${expanded ? ' settings-row__chevron--expanded' : ''}`}>
            <AppIcon className="shell-icon shell-icon--sm" name="chevron-right" />
          </div>
        ) : null}
      </div>

      {expanded && children ? <div className="settings-row__panel">{children}</div> : null}
    </div>
  );
}
