export type LiveSyncEventEnvelope<T = unknown> = {
  id: number;
  type: string;
  occurredAt: string;
  data?: T;
};

export type LiveSyncStatus = 'idle' | 'connecting' | 'connected' | 'reconnecting' | 'error';

export type LiveSyncListener = (event: LiveSyncEventEnvelope) => void;

export type LiveSyncContextValue = {
  status: LiveSyncStatus;
  lastEventId: number;
  subscribe: (listener: LiveSyncListener) => () => void;
  reconnect: () => void;
};
