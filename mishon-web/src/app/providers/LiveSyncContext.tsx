import {
  createContext,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type PropsWithChildren,
} from 'react';

import { useAuth } from './useAuth';
import type { LiveSyncContextValue, LiveSyncEventEnvelope, LiveSyncListener, LiveSyncStatus } from './live-sync-context';

const LiveSyncContext = createContext<LiveSyncContextValue | null>(null);

const syncURL = (import.meta.env.VITE_API_URL ?? '/api/v1').replace(/\/+$/, '') + '/sync/stream';

type ParsedSSEEvent = {
  id: number;
  payload: LiveSyncEventEnvelope;
};

function parseSSEChunk(buffer: string) {
  const events: ParsedSSEEvent[] = [];
  let remainder = buffer;

  while (true) {
    const boundary = remainder.indexOf('\n\n');
    if (boundary === -1) {
      break;
    }

    const rawEvent = remainder.slice(0, boundary);
    remainder = remainder.slice(boundary + 2);

    const lines = rawEvent.split(/\r?\n/);
    let currentId = 0;
    const dataLines: string[] = [];

    for (const line of lines) {
      if (!line || line.startsWith(':')) {
        continue;
      }

      if (line.startsWith('id:')) {
        currentId = Number(line.slice(3).trim()) || 0;
        continue;
      }

      if (line.startsWith('data:')) {
        dataLines.push(line.slice(5).trimStart());
      }
    }

    if (dataLines.length === 0) {
      continue;
    }

    try {
      const payload = JSON.parse(dataLines.join('\n')) as LiveSyncEventEnvelope;
      events.push({ id: currentId || payload.id || 0, payload });
    } catch {
      // Ignore malformed frames and keep the stream alive.
    }
  }

  return { events, remainder };
}

export function LiveSyncProvider({ children }: PropsWithChildren) {
  const { session, isAuthenticated, logout } = useAuth();
  const [status, setStatus] = useState<LiveSyncStatus>('idle');
  const [lastEventId, setLastEventId] = useState(0);
  const listenersRef = useRef(new Set<LiveSyncListener>());
  const abortRef = useRef<AbortController | null>(null);
  const reconnectTimerRef = useRef<number | null>(null);
  const reconnectAttemptsRef = useRef(0);
  const lastEventIdRef = useRef(0);
  const tokenRef = useRef<string | null>(session?.token ?? null);

  useEffect(() => {
    tokenRef.current = session?.token ?? null;
  }, [session?.token]);

  const subscribe = useCallback((listener: LiveSyncListener) => {
    listenersRef.current.add(listener);
    return () => {
      listenersRef.current.delete(listener);
    };
  }, []);

  const dispatch = useCallback((event: LiveSyncEventEnvelope) => {
    for (const listener of listenersRef.current) {
      listener(event);
    }
  }, []);

  const clearReconnectTimer = useCallback(() => {
    if (reconnectTimerRef.current !== null) {
      window.clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }
  }, []);

  const disconnect = useCallback(() => {
    clearReconnectTimer();
    abortRef.current?.abort();
    abortRef.current = null;
  }, [clearReconnectTimer]);

  const connect = useCallback(() => {
    const token = tokenRef.current;
    if (!token) {
      disconnect();
      setStatus('idle');
      return;
    }

    disconnect();
    const controller = new AbortController();
    abortRef.current = controller;
    setStatus(lastEventIdRef.current > 0 ? 'reconnecting' : 'connecting');

    void (async () => {
      try {
        const response = await fetch(`${syncURL}?lastEventId=${lastEventIdRef.current}`, {
          method: 'GET',
          headers: {
            Accept: 'text/event-stream',
            Authorization: `Bearer ${token}`,
          },
          signal: controller.signal,
          cache: 'no-store',
        });

        if (!response.ok || !response.body) {
          if (response.status === 401 || response.status === 403) {
            await logout();
            return;
          }
          throw new Error(`Sync stream failed with status ${response.status}`);
        }

        reconnectAttemptsRef.current = 0;
        setStatus('connected');

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';

        while (true) {
          const { done, value } = await reader.read();
          if (done) {
            break;
          }

          buffer += decoder.decode(value, { stream: true });
          const parsed = parseSSEChunk(buffer);
          buffer = parsed.remainder;

          for (const frame of parsed.events) {
            const nextId = frame.id || frame.payload.id || 0;
            if (nextId > 0 && nextId <= lastEventIdRef.current) {
              continue;
            }
            if (nextId > 0) {
              lastEventIdRef.current = nextId;
              setLastEventId(nextId);
            }
            dispatch(frame.payload);
          }
        }

        if (!controller.signal.aborted) {
          throw new Error('Sync stream closed');
        }
      } catch {
        if (controller.signal.aborted || !tokenRef.current) {
          return;
        }

        reconnectAttemptsRef.current += 1;
        setStatus('error');
        const delay = Math.min(1000 * 2 ** Math.min(reconnectAttemptsRef.current, 3), 10000);
        reconnectTimerRef.current = window.setTimeout(() => {
          reconnectTimerRef.current = null;
          connect();
        }, delay);
      }
    })();
  }, [disconnect, dispatch, logout]);

  useEffect(() => {
    if (!isAuthenticated || !session?.token) {
      disconnect();
      setStatus('idle');
      return;
    }

    connect();

    return () => {
      disconnect();
    };
  }, [connect, disconnect, isAuthenticated, session?.token]);

  const value = useMemo<LiveSyncContextValue>(
    () => ({
      status,
      lastEventId,
      subscribe,
      reconnect: connect,
    }),
    [connect, lastEventId, status, subscribe],
  );

  return <LiveSyncContext.Provider value={value}>{children}</LiveSyncContext.Provider>;
}

export { LiveSyncContext };
