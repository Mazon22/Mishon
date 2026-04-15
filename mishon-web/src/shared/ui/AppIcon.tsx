import type { SVGProps } from 'react';

export type AppIconName =
  | 'feed'
  | 'chats'
  | 'friends'
  | 'profile'
  | 'settings'
  | 'notifications'
  | 'search'
  | 'compose'
  | 'comment'
  | 'heart'
  | 'share'
  | 'more'
  | 'image'
  | 'attach'
  | 'send'
  | 'spark'
  | 'sun'
  | 'moon'
  | 'logout'
  | 'bookmark'
  | 'message'
  | 'shield'
  | 'globe'
  | 'chevron-right'
  | 'lock'
  | 'clock'
  | 'mail'
  | 'ban'
  | 'devices'
  | 'eye'
  | 'eye-off'
  | 'user-plus'
  | 'close'
  | 'calendar'
  | 'reply'
  | 'edit'
  | 'trash'
  | 'verified'
  | 'check'
  | 'check-double';

type AppIconProps = SVGProps<SVGSVGElement> & {
  name: AppIconName;
  filled?: boolean;
};

function strokeProps(fill = false) {
  return {
    fill: fill ? 'currentColor' : 'none',
    stroke: 'currentColor',
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    strokeWidth: 1.95,
    vectorEffect: 'non-scaling-stroke' as const,
  };
}

export function AppIcon({ name, filled = false, className, ...props }: AppIconProps) {
  const shared = strokeProps(filled);

  switch (name) {
    case 'feed':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="m3.75 10.25 8.25-6.5 8.25 6.5v9a1.5 1.5 0 0 1-1.5 1.5H13.5v-7h-3v7H5.25a1.5 1.5 0 0 1-1.5-1.5Z" {...shared} />
        </svg>
      );
    case 'chats':
    case 'message':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M5 7.25A2.25 2.25 0 0 1 7.25 5h9.5A2.25 2.25 0 0 1 19 7.25v7.5A2.25 2.25 0 0 1 16.75 17H10.6L6 20v-3.02A2.25 2.25 0 0 1 5 15V7.25Z" {...shared} />
        </svg>
      );
    case 'friends':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M8.5 10.75a2.75 2.75 0 1 0 0-5.5 2.75 2.75 0 0 0 0 5.5Z" {...shared} />
          <path d="M16.75 10a2.25 2.25 0 1 0 0-4.5 2.25 2.25 0 0 0 0 4.5Z" {...shared} />
          <path d="M4.25 18.25a4.5 4.5 0 0 1 4.5-4.5h1.5a4.5 4.5 0 0 1 4.5 4.5" {...shared} />
          <path d="M14.35 14.5a3.85 3.85 0 0 1 5.4 3.75" {...shared} />
        </svg>
      );
    case 'profile':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M12 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z" {...shared} />
          <path d="M5 19.25a7 7 0 0 1 14 0" {...shared} />
        </svg>
      );
    case 'settings':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path
            d="M9.3 4.25h5.4l.52 2.04c.37.12.72.27 1.05.44l1.83-1.08 1.9 1.9-1.08 1.83c.17.33.32.68.44 1.05l2.04.52v2.1l-2.04.52c-.12.37-.27.72-.44 1.05l1.08 1.83-1.9 1.9-1.83-1.08c-.33.17-.68.32-1.05.44l-.52 2.04H9.3l-.52-2.04c-.37-.12-.72-.27-1.05-.44L5.9 18.35 4 16.45l1.08-1.83a5.6 5.6 0 0 1-.44-1.05l-2.04-.52v-2.1l2.04-.52c.12-.37.27-.72.44-1.05L4 7.55l1.9-1.9 1.83 1.08c.33-.17.68-.32 1.05-.44l.52-2.04Z"
            {...shared}
          />
          <circle cx="12" cy="12" r="3.05" {...shared} />
        </svg>
      );
    case 'notifications':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M12 4.5a4.25 4.25 0 0 1 4.25 4.25v2.05c0 .95.3 1.87.85 2.65l1.15 1.55H5.75L6.9 13.45a4.57 4.57 0 0 0 .85-2.65V8.75A4.25 4.25 0 0 1 12 4.5Z" {...shared} />
          <path d="M10.15 18a1.95 1.95 0 0 0 3.7 0" {...shared} />
        </svg>
      );
    case 'search':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <circle cx="11" cy="11" r="5.75" {...shared} />
          <path d="m16 16 3.5 3.5" {...shared} />
        </svg>
      );
    case 'compose':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M12 5v14M5 12h14" {...shared} />
        </svg>
      );
    case 'comment':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M5 7.25A2.25 2.25 0 0 1 7.25 5h9.5A2.25 2.25 0 0 1 19 7.25v6.5A2.25 2.25 0 0 1 16.75 16H11l-4 3v-3.25A2.25 2.25 0 0 1 5 13.5v-6.25Z" {...shared} />
        </svg>
      );
    case 'heart':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="m12 19.5-1.05-.96C6.1 14.1 3.25 11.45 3.25 8.25A4.25 4.25 0 0 1 7.5 4c1.67 0 3.12.77 4.05 1.97A5.03 5.03 0 0 1 15.6 4a4.15 4.15 0 0 1 4.15 4.25c0 3.2-2.85 5.85-7.7 10.29L12 19.5Z" {...shared} />
        </svg>
      );
    case 'share':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M14.5 5h4.5v4.5" {...shared} />
          <path d="M19 5 9.25 14.75" {...shared} />
          <path d="M19 12.5v4.25A2.25 2.25 0 0 1 16.75 19H7.25A2.25 2.25 0 0 1 5 16.75V7.25A2.25 2.25 0 0 1 7.25 5h4.25" {...shared} />
        </svg>
      );
    case 'more':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <circle cx="5.75" cy="12" r="1.5" fill="currentColor" />
          <circle cx="12" cy="12" r="1.5" fill="currentColor" />
          <circle cx="18.25" cy="12" r="1.5" fill="currentColor" />
        </svg>
      );
    case 'image':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <rect x="4.25" y="5.25" width="15.5" height="13.5" rx="2.25" {...shared} />
          <path d="m7.5 16.25 3.5-3.5 2.5 2.5 2.75-2.75 2.5 2.5" {...shared} />
          <circle cx="9" cy="9.5" r="1.25" {...shared} />
        </svg>
      );
    case 'attach':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="m9.3 12.75 6.55-6.55a3.25 3.25 0 1 1 4.6 4.6l-8.1 8.1a5.25 5.25 0 1 1-7.42-7.42l7.3-7.3a2.45 2.45 0 1 1 3.46 3.47l-6.45 6.45a1.15 1.15 0 0 1-1.63-1.63l5.62-5.62" {...shared} />
        </svg>
      );
    case 'send':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="m3.5 11.75 15.75-6.25-4.6 13-3.4-4.35-4.9-2.4H3.5Z" {...shared} />
          <path d="M10.95 14.15 19.25 5.5" {...shared} />
        </svg>
      );
    case 'spark':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M12 3.5 13.2 8l4.3 1.2-4.3 1.2L12 15l-1.2-4.6L6.5 9.2 10.8 8 12 3.5Z" {...shared} />
          <path d="m18.5 15 .7 2.3 2.3.7-2.3.7-.7 2.3-.7-2.3-2.3-.7 2.3-.7.7-2.3Z" {...shared} />
          <path d="m6 15.5.55 1.55L8.1 17.6l-1.55.55L6 19.7l-.55-1.55L3.9 17.6l1.55-.55L6 15.5Z" {...shared} />
        </svg>
      );
    case 'sun':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <circle cx="12" cy="12" r="4" {...shared} />
          <path d="M12 2.75v2.5M12 18.75v2.5M21.25 12h-2.5M5.25 12h-2.5M18.55 5.45l-1.77 1.77M7.22 16.78l-1.77 1.77M18.55 18.55l-1.77-1.77M7.22 7.22 5.45 5.45" {...shared} />
        </svg>
      );
    case 'moon':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M18.75 14.4A7.75 7.75 0 0 1 9.6 5.25 8 8 0 1 0 18.75 14.4Z" {...shared} />
        </svg>
      );
    case 'logout':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M10 5.25H6.75A1.75 1.75 0 0 0 5 7v10a1.75 1.75 0 0 0 1.75 1.75H10" {...shared} />
          <path d="M13.25 8.25 18 12l-4.75 3.75M18 12H9" {...shared} />
        </svg>
      );
    case 'bookmark':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M7.25 4.5h9.5A1.25 1.25 0 0 1 18 5.75V20l-6-3.75L6 20V5.75A1.25 1.25 0 0 1 7.25 4.5Z" {...shared} />
        </svg>
      );
    case 'shield':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M12 3.5c2.45 1.54 4.96 2.4 7.5 2.6v5.26c0 4.04-2.47 7.34-7.5 9.64-5.03-2.3-7.5-5.6-7.5-9.64V6.1c2.54-.2 5.05-1.06 7.5-2.6Z" {...shared} />
        </svg>
      );
    case 'globe':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <circle cx="12" cy="12" r="8.25" {...shared} />
          <path d="M3.9 9.25h16.2M3.9 14.75h16.2M12 3.9c2.2 2.28 3.38 5.06 3.38 8.1 0 3.04-1.18 5.82-3.38 8.1M12 3.9c-2.2 2.28-3.38 5.06-3.38 8.1 0 3.04 1.18 5.82 3.38 8.1" {...shared} />
        </svg>
      );
    case 'chevron-right':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="m9 6.75 5.25 5.25L9 17.25" {...shared} />
        </svg>
      );
    case 'lock':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <rect x="5.25" y="10" width="13.5" height="9.25" rx="2.25" {...shared} />
          <path d="M8.5 10V7.75a3.5 3.5 0 1 1 7 0V10" {...shared} />
        </svg>
      );
    case 'clock':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <circle cx="12" cy="12" r="8.25" {...shared} />
          <path d="M12 7.75V12l3 2.25" {...shared} />
        </svg>
      );
    case 'mail':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <rect x="4" y="6" width="16" height="12" rx="2.25" {...shared} />
          <path d="m5.75 7.75 6.25 5 6.25-5" {...shared} />
        </svg>
      );
    case 'ban':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <circle cx="12" cy="12" r="8.25" {...shared} />
          <path d="M8.3 15.7 15.7 8.3" {...shared} />
        </svg>
      );
    case 'devices':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <rect x="3.75" y="6" width="10.5" height="8.75" rx="1.75" {...shared} />
          <path d="M9 18.25h7.25A1.75 1.75 0 0 0 18 16.5v-8A1.75 1.75 0 0 0 16.25 6.75H16" {...shared} />
          <path d="M8 17.5h2" {...shared} />
        </svg>
      );
    case 'eye':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M2.75 12c1.48-2.7 4.94-5.75 9.25-5.75s7.77 3.05 9.25 5.75c-1.48 2.7-4.94 5.75-9.25 5.75S4.23 14.7 2.75 12Z" {...shared} />
          <circle cx="12" cy="12" r="3" {...shared} />
        </svg>
      );
    case 'eye-off':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M3.75 4.75 20.25 19.25" {...shared} />
          <path d="M6.8 7.02A13.47 13.47 0 0 1 12 6.25c4.31 0 7.77 3.05 9.25 5.75a13.05 13.05 0 0 1-3.05 3.6" {...shared} />
          <path d="M17.2 16.98A13.47 13.47 0 0 1 12 17.75c-4.31 0-7.77-3.05-9.25-5.75a13.02 13.02 0 0 1 3.05-3.6" {...shared} />
          <path d="M9.88 9.88A3 3 0 0 0 14.12 14.12" {...shared} />
        </svg>
      );
    case 'user-plus':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M9.5 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z" {...shared} />
          <path d="M4.25 18.5a5.25 5.25 0 0 1 10.5 0" {...shared} />
          <path d="M18 8v6M15 11h6" {...shared} />
        </svg>
      );
    case 'close':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="m6.75 6.75 10.5 10.5M17.25 6.75 6.75 17.25" {...shared} />
        </svg>
      );
    case 'calendar':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <rect x="4.25" y="5.25" width="15.5" height="14.5" rx="2.25" {...shared} />
          <path d="M8 3.75v3M16 3.75v3M4.25 9.25h15.5" {...shared} />
        </svg>
      );
    case 'reply':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="m10.75 7.25-5 4.75 5 4.75" {...shared} />
          <path d="M6.25 12H14a4.75 4.75 0 0 1 4.75 4.75v.5" {...shared} />
        </svg>
      );
    case 'edit':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="m15.1 5.35 3.55 3.55" {...shared} />
          <path d="m5.75 18.25 2.95-.35 8.9-8.9a1.75 1.75 0 0 0-2.47-2.47l-8.9 8.9-.48 2.82Z" {...shared} />
          <path d="M5.5 18.5h13" {...shared} />
        </svg>
      );
    case 'trash':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="M4.75 7.25h14.5" {...shared} />
          <path d="M9.25 4.75h5.5" {...shared} />
          <path d="M7.25 7.25v10a2 2 0 0 0 2 2h5.5a2 2 0 0 0 2-2v-10" {...shared} />
          <path d="M10 10.5v5.25M14 10.5v5.25" {...shared} />
        </svg>
      );
    case 'check':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="m6.25 12.4 3.05 3.05 8-8" {...shared} />
        </svg>
      );
    case 'check-double':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path d="m2.9 12.35 2.55 2.55 4.7-4.7" {...shared} />
          <path d="m7.15 12.4 3.05 3.05 8-8" {...shared} />
        </svg>
      );
    case 'verified':
      return (
        <svg aria-hidden="true" className={className} viewBox="0 0 24 24" {...props}>
          <path
            d="M12 1.5 14.98 3.68 18.64 3.08 19.6 6.66 22.5 8.96 20.98 12l1.52 3.04-2.9 2.3-.96 3.58-3.66-.6L12 22.5l-2.98-2.18-3.66.6-.96-3.58-2.9-2.3L3.02 12 1.5 8.96l2.9-2.3.96-3.58 3.66.6L12 1.5Z"
            fill="currentColor"
          />
          <path d="m7.75 12.2 2.7 2.72 5.82-5.97 1.72 1.68-7.54 7.72-4.42-4.47 1.72-1.68Z" fill="#fff" />
        </svg>
      );
  }
}
