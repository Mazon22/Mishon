import { MishonMark } from '../../shared/ui/MishonMark';

type AppSplashProps = {
  exiting?: boolean;
  variant?: 'overlay' | 'fallback';
};

export function AppSplash({ exiting = false, variant = 'overlay' }: AppSplashProps) {
  return (
    <div
      aria-hidden="true"
      className={`app-splash app-splash--${variant}${exiting ? ' app-splash--exiting' : ''}`}
    >
      <div className="app-splash__core">
        <div className="app-splash__halo" />
        <MishonMark className="app-splash__mark" />
      </div>
    </div>
  );
}
