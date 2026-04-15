type AuthDividerProps = {
  label: string;
};

export function AuthDivider({ label }: AuthDividerProps) {
  return (
    <div className="auth-divider" aria-hidden="true">
      <span />
      <small>{label}</small>
      <span />
    </div>
  );
}
