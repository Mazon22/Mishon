import { useContext } from 'react';

import { LiveSyncContext } from './LiveSyncContext';

export function useLiveSync() {
  const value = useContext(LiveSyncContext);
  if (!value) {
    throw new Error('useLiveSync must be used inside LiveSyncProvider');
  }
  return value;
}
