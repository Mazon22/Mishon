import { useEffect, useMemo, useRef, useState } from 'react';

const MIN_VISIBLE_MS = 860;
const EXIT_DURATION_MS = 320;

export function useAppBootSplash(isReady: boolean) {
  const bootStartedAtRef = useRef<number>(0);
  const [isVisible, setIsVisible] = useState(true);
  const [isExiting, setIsExiting] = useState(false);

  useEffect(() => {
    if (!bootStartedAtRef.current) {
      bootStartedAtRef.current = performance.now();
    }
  }, []);

  useEffect(() => {
    if (!isReady || !isVisible) {
      return undefined;
    }

    const elapsed = performance.now() - bootStartedAtRef.current;
    const waitBeforeExit = Math.max(MIN_VISIBLE_MS - elapsed, 0);

    const exitTimer = window.setTimeout(() => {
      setIsExiting(true);
    }, waitBeforeExit);

    const hideTimer = window.setTimeout(() => {
      setIsVisible(false);
    }, waitBeforeExit + EXIT_DURATION_MS);

    return () => {
      window.clearTimeout(exitTimer);
      window.clearTimeout(hideTimer);
    };
  }, [isReady, isVisible]);

  return useMemo(
    () => ({
      isVisible,
      isExiting,
      isActive: isVisible || isExiting,
    }),
    [isExiting, isVisible],
  );
}
