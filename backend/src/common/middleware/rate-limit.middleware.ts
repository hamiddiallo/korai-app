import type { Request, RequestHandler } from 'express';
import { HttpError } from '../errors/http-error.js';

type Bucket = { count: number; resetAt: number };

/**
 * Limitation de débit en mémoire (une instance d'API). Freine la force brute
 * sur les mots de passe, le spam d'inscriptions et l'énumération des
 * matricules. Au-delà de `max` requêtes par fenêtre : 429 avec Retry-After.
 */
export const rateLimit = (options: {
  name: string;
  windowMs: number;
  max: number;
  /** Clé de comptage (par défaut : adresse IP). */
  key?: (req: Request) => string;
  message?: string;
  now?: () => number;
}): RequestHandler => {
  const buckets = new Map<string, Bucket>();
  const now = options.now ?? Date.now;

  return (req, res, next) => {
    const t = now();
    if (buckets.size > 10_000) {
      for (const [k, b] of buckets) if (b.resetAt <= t) buckets.delete(k);
    }
    const key = `${options.name}:${options.key ? options.key(req) : req.ip ?? 'inconnu'}`;
    let bucket = buckets.get(key);
    if (!bucket || bucket.resetAt <= t) {
      bucket = { count: 0, resetAt: t + options.windowMs };
      buckets.set(key, bucket);
    }
    bucket.count += 1;
    if (bucket.count > options.max) {
      const retryAfterSeconds = Math.max(1, Math.ceil((bucket.resetAt - t) / 1000));
      res.setHeader('Retry-After', String(retryAfterSeconds));
      const minutes = Math.ceil(retryAfterSeconds / 60);
      return next(
        new HttpError(
          429,
          'TOO_MANY_REQUESTS',
          options.message ??
            `Trop de tentatives. Réessayez dans ${minutes} minute${minutes > 1 ? 's' : ''}.`
        )
      );
    }
    return next();
  };
};
