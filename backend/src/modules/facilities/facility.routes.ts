import { Router } from 'express';
import { rateLimit } from '../../common/middleware/rate-limit.middleware.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { facilityDao } from './facility.dao.js';

/**
 * Liste publique des établissements (noms seulement), pour l'inscription des
 * soignants et des patients avant toute connexion.
 */
export const facilityRouter = Router();

facilityRouter.get(
  '/',
  rateLimit({ name: 'facilities', windowMs: 60 * 1000, max: 60 }),
  asyncHandler(async (_req, res) => {
    res.json({ facilities: await facilityDao.list() });
  })
);
