import type { ChatAttachment } from '../../../shared/types/api';

export function MessageAttachment({ attachment }: { attachment: ChatAttachment }) {
  if (attachment.isImage) {
    return (
      <a
        className="message-attachment message-attachment--image"
        href={attachment.fileUrl}
        rel="noreferrer"
        target="_blank"
      >
        <img alt={attachment.fileName} src={attachment.fileUrl} />
      </a>
    );
  }

  return (
    <a className="message-attachment" href={attachment.fileUrl} rel="noreferrer" target="_blank">
      <span className="message-attachment__name">{attachment.fileName}</span>
      <span className="message-attachment__meta">{attachment.contentType}</span>
    </a>
  );
}
