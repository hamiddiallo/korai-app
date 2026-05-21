import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  CORS_ORIGIN: z.string().default('*'),
  JWT_ACCESS_SECRET: z.string().min(16).default('dev_access_secret_change_me'),
  JWT_REFRESH_SECRET: z.string().min(16).default('dev_refresh_secret_change_me'),
  /** URL publique du service FastAPI (tunnel ngrok), sans slash final. */
  AI_SERVICE_BASE_URL: z.string().url({
    message:
      'Definir AI_SERVICE_BASE_URL dans .env (URL ngrok du service IA, ex. https://xxxx.ngrok-free.app)'
  }),
  AI_SERVICE_TIMEOUT_MS: z.coerce.number().default(120000)
});

export const env = envSchema.parse(process.env);
