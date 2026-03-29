import { useState } from 'react';

type PostComposerProps = {
  onSubmit: (payload: { content: string; imageUrl?: string }) => Promise<void>;
  busy?: boolean;
};

export function PostComposer({ onSubmit, busy }: PostComposerProps) {
  const [content, setContent] = useState('');
  const [imageUrl, setImageUrl] = useState('');

  async function handleSubmit() {
    const trimmed = content.trim();
    if (!trimmed) {
      return;
    }

    await onSubmit({ content: trimmed, imageUrl: imageUrl.trim() || undefined });
    setContent('');
    setImageUrl('');
  }

  return (
    <section className="panel panel--composer">
      <div className="panel__header">
        <div>
          <h3>Новая запись</h3>
          <p className="panel__note">
            Короткая мысль, фото или обновление статуса. Для быстрого постинга можно нажать `Ctrl + Enter`.
          </p>
        </div>
      </div>
      <textarea
        className="input input--area"
        value={content}
        placeholder="Что нового в Mishon?"
        rows={4}
        onChange={(event) => setContent(event.target.value)}
        onKeyDown={(event) => {
          if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
            event.preventDefault();
            void handleSubmit();
          }
        }}
      />
      <div className="composer-grid">
        <input
          className="input"
          value={imageUrl}
          placeholder="Ссылка на изображение (необязательно)"
          onChange={(event) => setImageUrl(event.target.value)}
        />
        <button className="primary-button" disabled={busy} type="button" onClick={() => void handleSubmit()}>
          {busy ? 'Публикуем...' : 'Опубликовать'}
        </button>
      </div>
    </section>
  );
}
