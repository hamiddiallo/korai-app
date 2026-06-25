import type { Prisma } from '@prisma/client';
import { HttpError, notFound } from '../../common/errors/http-error.js';
import type { AuthenticatedUser } from '../../common/types.js';
import { aiService } from '../ai/ai.service.js';
import { chatDao } from './chat.dao.js';
import type { ChatConversationRecord, ChatMessageRecord } from './chat.types.js';

const defaultAssistantFailure =
  'Le service IA est momentanement indisponible. Votre question a ete conservee dans cette conversation.';

const pickString = (value: unknown): string | undefined => {
  if (typeof value === 'string' && value.trim()) return value.trim();
  return undefined;
};

const collectSources = (value: unknown): string[] => {
  if (!value || typeof value !== 'object') return [];
  const objectValue = value as Record<string, unknown>;
  const candidates = [objectValue.sources, objectValue.rag_sources, objectValue.references];
  return candidates.flatMap((candidate) => {
    if (!Array.isArray(candidate)) return [];
    return candidate.map(String).filter(Boolean);
  });
};

const extractAiChatResponse = (
  raw: unknown
): {
  content: string;
  sources: string[];
  externalConversationId?: string;
} => {
  const objectValue = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  return {
    content:
      pickString(objectValue.response) ??
      pickString(objectValue.answer) ??
      pickString(objectValue.message) ??
      pickString(objectValue.content) ??
      '',
    sources: collectSources(objectValue),
    externalConversationId:
      pickString(objectValue.conversation_id) ?? pickString(objectValue.conversationId)
  };
};

const toInputJson = (value: unknown): Prisma.InputJsonValue | undefined => {
  if (value === undefined) return undefined;
  return value as Prisma.InputJsonValue;
};

const buildEducationalPrompt = (message: string, user: AuthenticatedUser) => {
  const roleInstruction =
    user.role === 'PATIENT'
      ? 'Adapte le vocabulaire pour un patient. Encourage a consulter un professionnel en cas de symptomes inquietants.'
      : user.role === 'NURSE'
        ? 'Adapte le niveau a un infirmier ou medecin generaliste en soins primaires.'
        : 'Adapte le niveau a un professionnel de sante.';

  return [
    'Tu es KORAI, assistant medical educatif specialise en ORL.',
    'Reponds a des questions generales de formation et de comprehension clinique.',
    'Ne remplace jamais une consultation medicale et ne pose pas de diagnostic personnalise sur un patient precis.',
    'Si la question contient des informations patient identifiantes, rappelle de les anonymiser.',
    roleInstruction,
    '',
    `Question: ${message}`
  ].join('\n');
};

const fallbackTitle = (message: string) => {
  const compact = message.replace(/\s+/g, ' ').trim();
  if (!compact) return 'Nouvelle conversation';
  return compact.length <= 40 ? compact : `${compact.slice(0, 37)}...`;
};

const sanitizeGeneratedTitle = (rawTitle: string) => {
  const compact = rawTitle
    .replace(/^["'«\s]+|["'»\s.?!:;]+$/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (!compact) return undefined;
  const words = compact.split(' ').slice(0, 6).join(' ');
  return words.length <= 60 ? words : `${words.slice(0, 57)}...`;
};

const scheduleTitleGeneration = (
  conversation: ChatConversationRecord,
  firstUserMessage: string
) => {
  const fallback = fallbackTitle(firstUserMessage);

  void (async () => {
    try {
      const rawTitle = await aiService.chat({
        message: [
          'Resume cette question ORL en un titre francais de 4 mots maximum.',
          'Ne mets pas de ponctuation.',
          '',
          `Question: ${firstUserMessage}`
        ].join('\n'),
        showSources: false
      });
      const extracted = extractAiChatResponse(rawTitle);
      const title = sanitizeGeneratedTitle(extracted.content) ?? fallback;
      await chatDao.updateConversation(conversation.userId, conversation.id, { title });
    } catch {
      await chatDao.updateConversation(conversation.userId, conversation.id, { title: fallback });
    }
  })();
};

const applyInitialTitle = async (
  conversation: ChatConversationRecord,
  firstUserMessage: string
) => {
  const titled = await chatDao.updateConversation(conversation.userId, conversation.id, {
    title: fallbackTitle(firstUserMessage)
  });
  scheduleTitleGeneration(titled, firstUserMessage);
  return titled;
};

const ensureOwnedConversation = async (
  userId: string,
  conversationId: string,
  options?: { activeOnly?: boolean }
) => {
  const conversation = await chatDao.findConversationForUser(userId, conversationId);
  if (!conversation) throw notFound('Conversation introuvable');
  if (options?.activeOnly && conversation.status !== 'ACTIVE') {
    throw new HttpError(409, 'CONVERSATION_ARCHIVED', 'Cette conversation est archivee');
  }
  return conversation;
};

export const chatService = {
  listConversations(user: AuthenticatedUser, status: 'ACTIVE' | 'ARCHIVED') {
    return chatDao.listConversations(user.id, status);
  },

  createConversation(user: AuthenticatedUser, input?: { title?: string }) {
    return chatDao.createConversation(user.id, input?.title);
  },

  async getConversation(user: AuthenticatedUser, conversationId: string) {
    return ensureOwnedConversation(user.id, conversationId);
  },

  async listMessages(
    user: AuthenticatedUser,
    conversationId: string,
    input: { limit: number; beforeSequence?: number }
  ) {
    await ensureOwnedConversation(user.id, conversationId);
    return chatDao.listMessages({
      userId: user.id,
      conversationId,
      limit: input.limit,
      beforeSequence: input.beforeSequence
    });
  },

  async sendMessage(
    user: AuthenticatedUser,
    conversationId: string,
    input: { message: string; showSources: boolean }
  ): Promise<{
    conversation: ChatConversationRecord;
    messages: [ChatMessageRecord, ChatMessageRecord];
  }> {
    const created = await chatDao.createUserMessageForActiveConversation({
      userId: user.id,
      conversationId,
      content: input.message
    });
    if (!created) throw notFound('Conversation active introuvable');

    const wasFirstExchange = created.conversation.messageCount === 0;

    try {
      const raw = await aiService.chat({
        message: buildEducationalPrompt(input.message, user),
        conversationId: created.conversation.externalConversationId,
        showSources: input.showSources
      });
      const extracted = extractAiChatResponse(raw);
      const assistantContent =
        extracted.content || 'Le service IA n\'a pas renvoye de reponse exploitable.';

      const finalized = await chatDao.createAssistantMessageAndFinalize({
        userId: user.id,
        conversationId,
        sequence: created.userMessage.sequence + 1,
        content: assistantContent,
        sources: extracted.sources,
        deliveryStatus: 'COMPLETED',
        externalRawJson: toInputJson(raw),
        externalConversationId: extracted.externalConversationId
      });

      const conversation = wasFirstExchange
        ? await applyInitialTitle(finalized.conversation, input.message)
        : finalized.conversation;

      return {
        conversation,
        messages: [created.userMessage, finalized.assistantMessage]
      };
    } catch (error) {
      const err = error as Error;
      const detail = (err as any).details || err.message;
      let cleanDetail = String(detail);
      if (cleanDetail.includes('<!DOCTYPE html>') || cleanDetail.includes('<html')) {
        cleanDetail = "Le serveur d'analyse a renvoyé une page d'erreur (502).";
      }
      const finalized = await chatDao.createAssistantMessageAndFinalize({
        userId: user.id,
        conversationId,
        sequence: created.userMessage.sequence + 1,
        content: `${defaultAssistantFailure}\n\nCause : ${cleanDetail}`,
        sources: [],
        deliveryStatus: 'FAILED',
        errorCode: 'AI_UNAVAILABLE'
      });

      const conversation = wasFirstExchange
        ? await applyInitialTitle(finalized.conversation, input.message)
        : finalized.conversation;

      return {
        conversation,
        messages: [created.userMessage, finalized.assistantMessage]
      };
    }
  },

  async retryMessage(
    user: AuthenticatedUser,
    conversationId: string,
    messageId: string
  ): Promise<{
    conversation: ChatConversationRecord;
    message: ChatMessageRecord;
  }> {
    const retryTarget = await chatDao.findRetryTarget({
      userId: user.id,
      conversationId,
      messageId
    });
    if (!retryTarget) throw notFound('Message a reessayer introuvable');

    await chatDao.updateAssistantMessage({
      messageId,
      content: 'Nouvelle tentative en cours...',
      deliveryStatus: 'PENDING',
      errorCode: null,
      externalRawJson: null,
      sources: []
    });

    try {
      const raw = await aiService.chat({
        message: buildEducationalPrompt(retryTarget.userMessage.content, user),
        conversationId: retryTarget.conversation.externalConversationId,
        showSources: true
      });
      const extracted = extractAiChatResponse(raw);

      const message = await chatDao.updateAssistantMessage({
        messageId,
        content:
          extracted.content || 'Le service IA n\'a pas renvoye de reponse exploitable.',
        sources: extracted.sources,
        deliveryStatus: 'COMPLETED',
        errorCode: null,
        externalRawJson: toInputJson(raw)
      });
      const conversation = await chatDao.touchConversation({
        userId: user.id,
        conversationId,
        externalConversationId: extracted.externalConversationId
      });

      return { conversation, message };
    } catch (error) {
      const err = error as Error;
      const detail = (err as any).details || err.message;
      let cleanDetail = String(detail);
      if (cleanDetail.includes('<!DOCTYPE html>') || cleanDetail.includes('<html')) {
        cleanDetail = "Le serveur d'analyse a renvoyé une page d'erreur (502).";
      }
      const message = await chatDao.updateAssistantMessage({
        messageId,
        content: `${defaultAssistantFailure}\n\nCause : ${cleanDetail}`,
        sources: [],
        deliveryStatus: 'FAILED',
        errorCode: 'AI_UNAVAILABLE',
        externalRawJson: null
      });
      const conversation = await chatDao.touchConversation({
        userId: user.id,
        conversationId
      });
      return { conversation, message };
    }
  },

  async updateConversation(
    user: AuthenticatedUser,
    conversationId: string,
    patch: { title?: string; status?: 'ACTIVE' | 'ARCHIVED' }
  ) {
    await ensureOwnedConversation(user.id, conversationId);
    const archivedAt =
      patch.status === 'ARCHIVED' ? new Date() : patch.status === 'ACTIVE' ? null : undefined;
    return chatDao.updateConversation(user.id, conversationId, {
      title: patch.title,
      status: patch.status,
      archivedAt
    });
  },

  async markRead(user: AuthenticatedUser, conversationId: string) {
    await ensureOwnedConversation(user.id, conversationId);
    await chatDao.markAssistantMessagesRead(user.id, conversationId);
    return { ok: true };
  }
};
