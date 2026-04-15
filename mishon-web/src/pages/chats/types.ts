export type ForwardDestination = {
  conversationId: number | null;
  peerId: number;
  title: string;
  subtitle: string;
  avatarUrl?: string | null;
  avatarScale: number;
  avatarOffsetX: number;
  avatarOffsetY: number;
};
