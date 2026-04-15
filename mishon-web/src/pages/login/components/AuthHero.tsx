import { AuthBrandMark } from './AuthBrandMark';

export function AuthHero() {
  return (
    <section className="auth-hero-panel">
      <div className="auth-hero-panel__mark">
        <AuthBrandMark size="lg" />
      </div>

      <div className="auth-hero-panel__brand">
        <strong>Mishon</strong>
        <span>Социальная сеть</span>
      </div>
    </section>
  );
}
