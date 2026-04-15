import { useEffect, useMemo, useRef, useState } from 'react';

import { useAuth } from '../../app/providers/useAuth';
import { AppIcon } from '../../shared/ui/AppIcon';
import { UserAvatar } from '../../shared/ui/UserAvatar';

type PostComposerProps = {
  onSubmit: (payload: { content: string; imageUrl?: string; imageFile?: File | null }) => Promise<void>;
  busy?: boolean;
  variant?: 'inline' | 'modal';
  autoFocus?: boolean;
  onSubmitted?: () => void;
};

const MIN_TEXTAREA_HEIGHT = 96;
const MAX_TEXTAREA_HEIGHT = 320;
const POST_LIMIT = 1000;

export function PostComposer({
  onSubmit,
  busy,
  variant = 'inline',
  autoFocus = false,
  onSubmitted,
}: PostComposerProps) {
  const { profile } = useAuth();
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const [content, setContent] = useState('');
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!autoFocus || !textareaRef.current) {
      return;
    }

    const frameId = window.requestAnimationFrame(() => {
      textareaRef.current?.focus({ preventScroll: true });
    });

    return () => window.cancelAnimationFrame(frameId);
  }, [autoFocus]);

  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) {
      return;
    }

    textarea.style.height = `${MIN_TEXTAREA_HEIGHT}px`;
    const nextHeight = Math.min(textarea.scrollHeight, MAX_TEXTAREA_HEIGHT);
    textarea.style.height = `${Math.max(nextHeight, MIN_TEXTAREA_HEIGHT)}px`;
    textarea.style.overflowY = textarea.scrollHeight > MAX_TEXTAREA_HEIGHT ? 'auto' : 'hidden';
  }, [content]);

  const charactersLeft = POST_LIMIT - content.length;
  const submitDisabled = busy || !content.trim() || content.length > POST_LIMIT;
  const displayName = profile?.displayName || profile?.username || 'Mishon';
  const composerTone = useMemo(() => {
    if (charactersLeft < 0) {
      return 'danger';
    }
    if (charactersLeft <= 120) {
      return 'warning';
    }
    return 'muted';
  }, [charactersLeft]);

  async function handleSubmit() {
    const trimmed = content.trim();
    if (!trimmed || busy || trimmed.length > POST_LIMIT) {
      return;
    }

    setError(null);

    try {
      await onSubmit({
        content: trimmed,
        imageFile,
      });
      setContent('');
      setImageFile(null);
      onSubmitted?.();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : 'Не удалось опубликовать пост.');
    }
  }

  return (
    <section className={`composer composer--feed${variant === 'modal' ? ' composer--modal' : ''}`}>
      <div className="composer__body">
        <div className="composer__row">
          <UserAvatar
            className="composer__avatar"
            imageUrl={profile?.avatarUrl}
            name={displayName}
            offsetX={profile?.avatarOffsetX}
            offsetY={profile?.avatarOffsetY}
            scale={profile?.avatarScale}
            size="md"
          />

          <div className="composer__fields">
            <textarea
              ref={textareaRef}
              className="input input--area composer__textarea"
              value={content}
              placeholder="Что происходит?"
              rows={1}
              onChange={(event) => {
                setContent(event.target.value);
                if (error) {
                  setError(null);
                }
              }}
              onKeyDown={(event) => {
                if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
                  event.preventDefault();
                  void handleSubmit();
                }
              }}
            />

            <div className="composer__footer">
              <div className="composer__attachments">
                <label className="icon-button icon-button--ghost composer__tool" aria-label="Добавить фото">
                  <AppIcon className="button-icon" name="image" />
                  <input
                    hidden
                    accept="image/*"
                    type="file"
                    onChange={(event) => {
                      setImageFile(event.target.files?.[0] ?? null);
                      if (error) {
                        setError(null);
                      }
                    }}
                  />
                </label>

                {imageFile ? (
                  <span className="composer__attachment-pill">
                    <AppIcon className="button-icon" name="image" />
                    <span className="composer__attachment-name">{imageFile.name}</span>
                    <button
                      aria-label="Убрать фото"
                      className="composer__attachment-clear"
                      type="button"
                      onClick={() => setImageFile(null)}
                    >
                      <AppIcon className="button-icon" name="close" />
                    </button>
                  </span>
                ) : null}
              </div>

              <div className="composer__actions">
                <span className={`composer__counter composer__counter--${composerTone}`}>{charactersLeft}</span>
                <button className="primary-button primary-button--sm" disabled={submitDisabled} type="button" onClick={() => void handleSubmit()}>
                  {busy ? 'Публикуем...' : 'Опубликовать'}
                </button>
              </div>
            </div>

            {error ? <div className="composer__error">{error}</div> : null}
          </div>
        </div>
      </div>
    </section>
  );
}
