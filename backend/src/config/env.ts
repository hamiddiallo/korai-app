import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

/** Valeurs d'exemple ou de développement : interdites en production. */
const WEAK_SECRET = /change_me|replace_with|dev_|secret$/i;

const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().default(4000),
    /** Origines autorisées, séparées par des virgules ; `*` réservé au développement. */
    CORS_ORIGIN: z.string().default('*'),
    // Pas de valeur par défaut : un secret connu permettrait de forger des jetons.
    JWT_ACCESS_SECRET: z.string().min(16, 'JWT_ACCESS_SECRET : 16 caractères minimum'),
    JWT_REFRESH_SECRET: z.string().min(16, 'JWT_REFRESH_SECRET : 16 caractères minimum'),
    /** Comptes de démonstration : par défaut en développement uniquement. */
    SEED_DEMO: z.enum(['true', 'false']).optional(),
    /** Nombre de proxys de confiance devant l'API (adresse IP réelle du client). */
    TRUST_PROXY: z.coerce.number().int().min(0).default(0),
    /** URL publique du service FastAPI (tunnel ngrok), sans slash final. */
    AI_SERVICE_BASE_URL: z.string().url({
      message:
        'Definir AI_SERVICE_BASE_URL dans .env (URL ngrok du service IA, ex. https://xxxx.ngrok-free.app)'
    }),
    AI_SERVICE_TIMEOUT_MS: z.coerce.number().default(120000),
    /**
     * Clé de chiffrement des photos du tympan (AES-256-GCM) : 32 octets en
     * base64. Sans elle, les photos stockées sont illisibles : la conserver
     * précieusement (sauvegarde du serveur).
     */
    IMAGE_ENCRYPTION_KEY: z
      .string({ required_error: 'IMAGE_ENCRYPTION_KEY manquante (voir .env.example)' })
      .refine((value) => Buffer.from(value, 'base64').length === 32, {
        message: 'IMAGE_ENCRYPTION_KEY : 32 octets encodés en base64 requis'
      }),
    /** Dossier des photos chiffrées (hors du dépôt). */
    IMAGE_STORAGE_DIR: z.string().default('storage/otoscopic-images')
  })
  .superRefine((e, ctx) => {
    if (e.NODE_ENV !== 'production') return;
    for (const key of ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET'] as const) {
      if (e[key].length < 32 || WEAK_SECRET.test(e[key])) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: [key],
          message: `${key} : secret aléatoire d'au moins 32 caractères requis en production`
        });
      }
    }
    if (e.JWT_ACCESS_SECRET === e.JWT_REFRESH_SECRET) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['JWT_REFRESH_SECRET'], message: 'Les deux secrets JWT doivent être différents' });
    }
    if (e.CORS_ORIGIN.trim() === '*') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['CORS_ORIGIN'],
        message: 'CORS_ORIGIN doit lister les origines autorisées en production (pas « * »)'
      });
    }
  });

export const parseEnv = (source: NodeJS.ProcessEnv) => envSchema.parse(source);

export const env = parseEnv(process.env);

/** Comptes de démonstration créés au démarrage ? (jamais en production, sauf demande explicite) */
export const shouldSeedDemo = env.SEED_DEMO ? env.SEED_DEMO === 'true' : env.NODE_ENV === 'development';

/** Origines CORS : `true` = toutes (développement), sinon liste explicite. */
export const corsOrigins = (value: string): true | string[] =>
  value.trim() === '*' ? true : value.split(',').map((origin) => origin.trim()).filter(Boolean);
