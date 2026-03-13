import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mishon_app/core/models/social_models.dart';

final chatConversationPreviewOverridesProvider = StateNotifierProvider<
  ChatConversationPreviewOverridesNotifier,
  Map<int, ConversationPreviewOverride>
>((ref) => ChatConversationPreviewOverridesNotifier());

class ConversationPreviewOverride {
  final int lastMessageId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageIsMine;
  final bool lastMessageIsDeliveredToPeer;
  final bool lastMessageIsReadByPeer;

  const ConversationPreviewOverride({
    required this.lastMessageId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageIsMine,
    required this.lastMessageIsDeliveredToPeer,
    required this.lastMessageIsReadByPeer,
  });

  ConversationPreviewOverride copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    bool? lastMessageIsMine,
    bool? lastMessageIsDeliveredToPeer,
    bool? lastMessageIsReadByPeer,
  }) {
    return ConversationPreviewOverride(
      lastMessageId: lastMessageId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageIsMine: lastMessageIsMine ?? this.lastMessageIsMine,
      lastMessageIsDeliveredToPeer:
          lastMessageIsDeliveredToPeer ?? this.lastMessageIsDeliveredToPeer,
      lastMessageIsReadByPeer:
          lastMessageIsReadByPeer ?? this.lastMessageIsReadByPeer,
    );
  }

  factory ConversationPreviewOverride.fromMessage(ChatMessageModel message) {
    return ConversationPreviewOverride(
      lastMessageId: message.id,
      lastMessage: _buildPreview(message),
      lastMessageAt: message.createdAt,
      lastMessageIsMine: message.isMine,
      lastMessageIsDeliveredToPeer: message.isDeliveredToPeer,
      lastMessageIsReadByPeer: message.isReadByPeer,
    );
  }

  static String _buildPreview(ChatMessageModel message) {
    final content = message.content.trim();
    if (content.isNotEmpty) {
      return content;
    }

    if (message.attachments.isEmpty) {
      return '';
    }

    final imageCount = message.attachments.where((item) => item.isImage).length;
    if (imageCount == message.attachments.length) {
      return imageCount > 1 ? 'Photos: $imageCount' : 'Photo';
    }

    return message.attachments.length > 1
        ? 'Files: ${message.attachments.length}'
        : 'File';
  }
}

class ChatConversationPreviewOverridesNotifier
    extends StateNotifier<Map<int, ConversationPreviewOverride>> {
  ChatConversationPreviewOverridesNotifier() : super(const {});

  void upsertFromMessage(ChatMessageModel message) {
    state = {
      ...state,
      message.conversationId: ConversationPreviewOverride.fromMessage(message),
    };
  }

  void markDelivered(int conversationId, int messageId, DateTime deliveredAt) {
    final current = state[conversationId];
    if (current == null || current.lastMessageId != messageId) {
      return;
    }

    state = {
      ...state,
      conversationId: current.copyWith(
        lastMessageIsDeliveredToPeer: true,
        lastMessageAt: current.lastMessageAt ?? deliveredAt,
      ),
    };
  }

  void markRead(int conversationId, DateTime readAt) {
    final current = state[conversationId];
    if (current == null || !current.lastMessageIsMine) {
      return;
    }
    final lastMessageAt = current.lastMessageAt;
    if (lastMessageAt != null && lastMessageAt.isAfter(readAt)) {
      return;
    }

    state = {
      ...state,
      conversationId: current.copyWith(
        lastMessageIsDeliveredToPeer: true,
        lastMessageIsReadByPeer: true,
      ),
    };
  }
}
