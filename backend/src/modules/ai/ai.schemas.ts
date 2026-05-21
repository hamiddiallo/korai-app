import { z } from 'zod';

export const chatSchema = z.object({
  message: z.string().min(1),
  conversation_id: z.string().optional(),
  show_sources: z.coerce.boolean().default(true)
});

export const ragAnalyzeSchema = z.object({
  symptoms: z.string().min(3),
  show_sources: z.coerce.boolean().default(true)
});
