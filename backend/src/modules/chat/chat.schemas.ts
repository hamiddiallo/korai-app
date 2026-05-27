import { z } from 'zod';

export const createConversationSchema = z.object({
  title: z.string().trim().min(1).max(80).optional()
});

export const updateConversationSchema = z
  .object({
    title: z.string().trim().min(1).max(80).optional(),
    status: z.enum(['ACTIVE', 'ARCHIVED']).optional()
  })
  .refine((value) => value.title !== undefined || value.status !== undefined, {
    message: 'Au moins un champ doit etre fourni'
  });

export const sendMessageSchema = z.object({
  message: z.string().trim().min(1).max(4000),
  showSources: z.coerce.boolean().default(true)
});

export const listConversationsQuerySchema = z.object({
  status: z.enum(['ACTIVE', 'ARCHIVED']).default('ACTIVE')
});

export const listMessagesQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
  beforeSequence: z.coerce.number().int().positive().optional()
});
