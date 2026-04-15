import { MishonMark } from '../../../shared/ui/MishonMark';

type AuthBrandMarkProps = {
  size?: 'sm' | 'md' | 'lg';
};

export function AuthBrandMark({ size = 'md' }: AuthBrandMarkProps) {
  return (
    <div className={`auth-brand-mark auth-brand-mark--${size}`} aria-hidden="true">
      <div className="auth-brand-mark__glow" />
      <div className="auth-brand-mark__tile">
        <MishonMark className="auth-brand-mark__glyph" />
      </div>
    </div>
  );
}
