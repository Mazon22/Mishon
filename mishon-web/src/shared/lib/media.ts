import type { CSSProperties } from 'react';

const configuredApiUrl = import.meta.env.VITE_API_URL as string | undefined;

function apiOrigin() {
  if (!configuredApiUrl) {
    return window.location.origin;
  }

  try {
    return new URL(configuredApiUrl, window.location.origin).origin;
  } catch {
    return window.location.origin;
  }
}

function isLoopbackHost(hostname: string) {
  const normalized = hostname.trim().toLowerCase();
  return normalized === 'localhost' || normalized === '127.0.0.1' || normalized === '0.0.0.0' || normalized === '::1';
}

export function resolveMediaUrl(raw?: string | null) {
  const trimmed = raw?.trim();
  if (!trimmed) {
    return null;
  }

  try {
    const parsed = new URL(trimmed, window.location.origin);
    if (isLoopbackHost(parsed.hostname) && parsed.pathname.startsWith('/uploads/')) {
      return `${apiOrigin()}${parsed.pathname}`;
    }

    if (trimmed.startsWith('/')) {
      return `${apiOrigin()}${parsed.pathname}${parsed.search}${parsed.hash}`;
    }

    return parsed.toString();
  } catch {
    return trimmed;
  }
}

export function buildMediaTransformStyle(
  scale = 1,
  offsetX = 0,
  offsetY = 0,
): CSSProperties {
  const safeScale = Number.isFinite(scale) && scale > 0 ? scale : 1;
  const safeOffsetX = Number.isFinite(offsetX) ? offsetX : 0;
  const safeOffsetY = Number.isFinite(offsetY) ? offsetY : 0;

  return {
    transform: `translate(${safeOffsetX * 35}%, ${safeOffsetY * 35}%) scale(${safeScale})`,
    transformOrigin: 'center center',
  };
}
