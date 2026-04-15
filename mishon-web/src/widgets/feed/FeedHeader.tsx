import type { PropsWithChildren } from 'react';

export function FeedHeader({ children }: PropsWithChildren) {
  return <section className="timeline-header timeline-header--feed">{children}</section>;
}
