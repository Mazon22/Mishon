import { UserAvatar } from '../../../shared/ui/UserAvatar';
import type { ForwardDestination } from '../types';

type ForwardSheetProps = {
  destinations: ForwardDestination[];
  busy: boolean;
  onClose: () => void;
  onSelect: (destination: ForwardDestination) => void | Promise<void>;
};

export function ForwardSheet({ destinations, busy, onClose, onSelect }: ForwardSheetProps) {
  return (
    <div className="forward-sheet">
      <div className="forward-sheet__card">
        <div className="forward-sheet__header">
          <div>
            <div className="section-title">Переслать сообщение</div>
            <div className="section-subtitle">Выберите чат или Saved Messages.</div>
          </div>
          <button className="text-button" type="button" onClick={onClose}>
            Закрыть
          </button>
        </div>

        <div className="forward-sheet__list">
          {destinations.map((destination) => (
            <button
              key={`${destination.peerId}-${destination.conversationId ?? 'new'}`}
              className="forward-row"
              disabled={busy}
              type="button"
              onClick={() => void onSelect(destination)}
            >
              <UserAvatar
                imageUrl={destination.avatarUrl}
                name={destination.title}
                offsetX={destination.avatarOffsetX}
                offsetY={destination.avatarOffsetY}
                scale={destination.avatarScale}
                size="md"
              />
              <div className="forward-row__body">
                <strong>{destination.title}</strong>
                <span>{destination.subtitle}</span>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
