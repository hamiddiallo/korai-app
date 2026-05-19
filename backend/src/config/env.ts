import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  CORS_ORIGIN: z.string().default('*'),
  JWT_ACCESS_SECRET: z.string().min(16).default('dev_access_secret_change_me'),
  JWT_REFRESH_SECRET: z.string().min(16).default('dev_refresh_secret_change_me'),
  AI_SERVICE_BASE_URL: z.string().url().default('http://localhost:8000'),
  AI_SERVICE_TIMEOUT_MS: z.coerce.number().default(60000)
});

export const env = envSchema.parse(process.env);
