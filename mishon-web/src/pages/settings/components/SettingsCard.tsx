import type { PropsWithChildren, ReactNode } from 'react';

type SettingsCardProps = PropsWithChildren<{
  title: string;
  description: string;
  icon?: ReactNode;
}>;

export function SettingsCard({ title, description, icon, children }: SettingsCardProps) {
  return (
    <section className="settings-card">
      <header className="settings-card__header">
        {icon ? <div className="settings-card__icon">{icon}</div> : null}
        <div className="settings-card__copy">
          <h3>{title}</h3>
          <p>{description}</p>
        </div>
      </header>
      <div className="settings-card__body">{children}</div>
    </section>
  );
}
