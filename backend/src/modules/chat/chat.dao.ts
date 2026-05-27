import type {
  ChatConversationStatus,
  ChatDeliveryStatus,
  ChatMessageRole
} from '@prisma/client';
import { Prisma } from '@prisma/client';
import { prisma } from '../../common/prisma.js';
import type { ChatConversationRecord, ChatMessageRecord } from './chat.types.js';

const nullable = <T>(value: T | null): T | undefined => value ?? undefined;

const mapConversation = (row: {
  id: string;
  userId: string;
  title: string;
  status: ChatConversationStatus;
  externalConversationId: string | null;
  messageCount: number;
  lastMessageAt: Date;
  archivedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}): ChatConversationRecord => ({
  id: row.id,
  userId: row.userId,
  title: row.title,
  status: row.status,
  externalConversationId: nullable(row.externalConversationId),
  messageCount: row.messageCount,
  lastMessageAt: row.lastMessageAt.toISOString(),
  archivedAt: row.archivedAt?.toISOString(),
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString()
});

const mapMessage = (row: {
  id: string;
  conversationId: string;
  role: ChatMessageRole;
  content: string;
  sources: string[];
  sequence: number;
  deliveryStatus: ChatDeliveryStatus;
  isRead: boolean;
  errorCode: string | null;
  externalRawJson: Prisma.JsonValue;
  createdAt: Date;
  updatedAt: Date;
}): ChatMessageRecord => ({
  id: row.id,
  conversationId: row.conversationId,
  role: row.role,
  content: row.content,
  sources: row.sources,
  sequence: row.sequence,
  deliveryStatus: row.deliveryStatus,
  isRead: row.isRead,
  errorCode: nullable(row.errorCode),
  externalRawJson: row.externalRawJson ?? undefined,
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString()
});

export const chatDao = {
  async listConversations(userId: string, status: ChatConversationStatus) {
    const rows = await prisma.chatConversation.findMany({
      where: { userId, status },
      orderBy: [{ lastMessageAt: 'desc' }, { createdAt: 'desc' }]
    });
    return rows.map(mapConversation);
  },

  async createConversation(userId: string, title?: string) {
    const row = await prisma.chatConversation.create({
      data: {
        userId,
        title: title ?? 'Nouvelle conversation'
      }
    });
    return mapConversation(row);
  },

  async findConversationForUser(userId: string, conversationId: string) {
    const row = await prisma.chatConversation.findFirst({
      where: {
        id: conversationId,
        userId
      }
    });
    return row ? mapConversation(row) : undefined;
  },

  async listMessages(input: {
    userId: string;
    conversationId: string;
    limit: number;
    beforeSequence?: number;
  }) {
    const rows = await prisma.chatMessage.findMany({
      where: {
        conversationId: input.conversationId,
        conversation: { userId: input.userId },
        ...(input.beforeSequence ? { sequence: { lt: input.beforeSequence } } : {})
      },
      orderBy: { sequence: 'desc' },
      take: input.limit
    });

    return rows.reverse().map(mapMessage);
  },

  async updateConversation(
    userId: string,
    conversationId: string,
    patch: Partial<{
      title: string;
      status: ChatConversationStatus;
      archivedAt: Date | null;
      externalConversationId: string;
      messageCount: number;
      lastMessageAt: Date;
    }>
  ) {
    const result = await prisma.chatConversation.updateMany({
      where: { id: conversationId, userId },
      data: patch
    });
    if (result.count === 0) throw new Error('Conversation ownership mismatch');
    const row = await prisma.chatConversation.findUniqueOrThrow({
      where: { id: conversationId }
    });
    return mapConversation(row);
  },

  async markAssistantMessagesRead(userId: string, conversationId: string) {
    await prisma.chatMessage.updateMany({
      where: {
        conversationId,
        role: 'ASSISTANT',
        isRead: false,
        conversation: { userId }
      },
      data: { isRead: true }
    });
  },

  async createUserMessageForActiveConversation(input: {
    userId: string;
    conversationId: string;
    content: string;
  }) {
    return prisma.$transaction(async (tx) => {
      const conversation = await tx.chatConversation.findFirst({
        where: {
          id: input.conversationId,
          userId: input.userId,
          status: 'ACTIVE'
        }
      });
      if (!conversation) return undefined;

      const lastMessage = await tx.chatMessage.findFirst({
        where: { conversationId: input.conversationId },
        orderBy: { sequence: 'desc' },
        select: { sequence: true }
      });
      const sequence = (lastMessage?.sequence ?? 0) + 1;

      const userMessage = await tx.chatMessage.create({
        data: {
          conversationId: input.conversationId,
          role: 'USER',
          content: input.content,
          sequence,
          deliveryStatus: 'COMPLETED',
          isRead: true
        }
      });

      return {
        conversation: mapConversation(conversation),
        userMessage: mapMessage(userMessage)
      };
    });
  },

  async createAssistantMessageAndFinalize(input: {
    userId: string;
    conversationId: string;
    sequence: number;
    content: string;
    sources: string[];
    deliveryStatus: ChatDeliveryStatus;
    errorCode?: string;
    externalRawJson?: Prisma.InputJsonValue;
    externalConversationId?: string;
  }) {
    return prisma.$transaction(async (tx) => {
      const assistantMessage = await tx.chatMessage.create({
        data: {
          conversationId: input.conversationId,
          role: 'ASSISTANT',
          content: input.content,
          sources: input.sources,
          sequence: input.sequence,
          deliveryStatus: input.deliveryStatus,
          errorCode: input.errorCode,
          externalRawJson: input.externalRawJson
        }
      });

      const updateResult = await tx.chatConversation.updateMany({
        where: { id: input.conversationId, userId: input.userId },
        data: {
          ...(input.externalConversationId
            ? { externalConversationId: input.externalConversationId }
            : {}),
          messageCount: { increment: 2 },
          lastMessageAt: new Date()
        }
      });
      if (updateResult.count === 0) {
        throw new Error('Conversation ownership mismatch');
      }
      const conversation = await tx.chatConversation.findUniqueOrThrow({
        where: { id: input.conversationId }
      });

      return {
        conversation: mapConversation(conversation),
        assistantMessage: mapMessage(assistantMessage)
      };
    });
  },

  async findRetryTarget(input: {
    userId: string;
    conversationId: string;
    messageId: string;
  }) {
    const assistantMessage = await prisma.chatMessage.findFirst({
      where: {
        id: input.messageId,
        conversationId: input.conversationId,
        role: 'ASSISTANT',
        deliveryStatus: 'FAILED',
        conversation: {
          userId: input.userId,
          status: 'ACTIVE'
        }
      },
      include: {
        conversation: true
      }
    });
    if (!assistantMessage) return undefined;

    const userMessage = await prisma.chatMessage.findFirst({
      where: {
        conversationId: input.conversationId,
        role: 'USER',
        sequence: assistantMessage.sequence - 1
      }
    });
    if (!userMessage) return undefined;

    return {
      conversation: mapConversation(assistantMessage.conversation),
      userMessage: mapMessage(userMessage),
      assistantMessage: mapMessage(assistantMessage)
    };
  },

  async updateAssistantMessage(input: {
    messageId: string;
    content?: string;
    sources?: string[];
    deliveryStatus: ChatDeliveryStatus;
    errorCode?: string | null;
    externalRawJson?: Prisma.InputJsonValue | null;
  }) {
    const row = await prisma.chatMessage.update({
      where: { id: input.messageId },
      data: {
        content: input.content,
        sources: input.sources,
        deliveryStatus: input.deliveryStatus,
        errorCode: input.errorCode,
        externalRawJson:
          input.externalRawJson === null ? Prisma.JsonNull : input.externalRawJson
      }
    });
    return mapMessage(row);
  },

  async touchConversation(input: {
    userId: string;
    conversationId: string;
    externalConversationId?: string;
  }) {
    const result = await prisma.chatConversation.updateMany({
      where: { id: input.conversationId, userId: input.userId },
      data: {
        ...(input.externalConversationId
          ? { externalConversationId: input.externalConversationId }
          : {}),
        lastMessageAt: new Date()
      }
    });
    if (result.count === 0) throw new Error('Conversation ownership mismatch');
    const row = await prisma.chatConversation.findUniqueOrThrow({
      where: { id: input.conversationId }
    });
    return mapConversation(row);
  }
};
