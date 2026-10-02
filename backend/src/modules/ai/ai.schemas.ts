import { z } from 'zod';
import { booleanish } from '../../common/utils/zod.js';

export const chatSchema = z.object({
  message: z.string().min(1),
  conversation_id: z.string().optional(),
  show_sources: booleanish(true)
});

export const ragAnalyzeSchema = z.object({
  symptoms: z.string().min(3),
  show_sources: booleanish(true)
});
