import type { SVGProps } from 'react';

type MishonMarkProps = SVGProps<SVGSVGElement> & {
  monochrome?: boolean;
};

export function MishonMark({ monochrome = false, ...props }: MishonMarkProps) {
  const background = monochrome ? '#111827' : '#0F1728';
  const stroke = monochrome ? '#F8FAFC' : '#F8FAFC';
  const accent = monochrome ? '#CBD5E1' : '#5B7CFF';

  return (
    <svg aria-hidden="true" viewBox="0 0 128 128" {...props}>
      <rect x="8" y="8" width="112" height="112" rx="30" fill={background} />
      <rect x="8.5" y="8.5" width="111" height="111" rx="29.5" stroke="#FFFFFF" strokeOpacity="0.08" />

      <path
        d="M35 92V36h10.6L64 60.2 82.4 36H93v56H80.3V58.15L67.5 75h-7L47.7 58.15V92H35Z"
        fill={stroke}
      />
      <circle cx="92" cy="36" r="5" fill={accent} />
    </svg>
  );
}
