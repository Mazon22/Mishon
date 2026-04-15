type SettingsSwitchProps = {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label: string;
};

export function SettingsSwitch({ checked, onChange, label }: SettingsSwitchProps) {
  return (
    <button
      aria-checked={checked}
      aria-label={label}
      className={`settings-switch${checked ? ' settings-switch--checked' : ''}`}
      role="switch"
      type="button"
      onClick={(event) => {
        event.stopPropagation();
        onChange(!checked);
      }}
    >
      <span className="settings-switch__thumb" />
    </button>
  );
}
