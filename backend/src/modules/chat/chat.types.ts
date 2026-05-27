import type {
  ChatConversationStatus,
  ChatDeliveryStatus,
  ChatMessageRole,
  Prisma
} from '@prisma/client';

export type ChatConversationRecord = {
  id: string;
  userId: string;
  title: string;
  status: ChatConversationStatus;
  externalConversationId?: string;
  messageCount: number;
  lastMessageAt: string;
  archivedAt?: string;
  createdAt: string;
  updatedAt: string;
};

export type ChatMessageRecord = {
  id: string;
  conversationId: string;
  role: ChatMessageRole;
  content: string;
  sources: string[];
  sequence: number;
  deliveryStatus: ChatDeliveryStatus;
  isRead: boolean;
  errorCode?: string;
  externalRawJson?: Prisma.JsonValue;
  createdAt: string;
  updatedAt: string;
};
