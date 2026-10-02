import { createApp } from './app.js';
import { prisma } from './common/prisma.js';
import { runSeed } from './common/seed.js';
import { env, shouldSeedDemo } from './config/env.js';

if (shouldSeedDemo) await runSeed();

const app = createApp();

const server = app.listen(env.PORT, () => {
  console.log(`Korai backend (${env.NODE_ENV}) listening on http://localhost:${env.PORT}`);
  if (env.NODE_ENV !== 'production') console.log(`AI service (proxy): ${env.AI_SERVICE_BASE_URL}`);
  if (shouldSeedDemo) {
    // Comptes de démonstration : mot de passe dans src/common/seed.ts (jamais en production).
    console.log('Demo accounts: nurse@korai.local, orl@korai.local, admin@korai.local, patient@korai.local');
  }
});

// Arrêt propre (déploiement, redémarrage) : fin des requêtes en cours, puis base fermée.
for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  process.once(signal, () => {
    setTimeout(() => process.exit(1), 10_000).unref();
    server.close(() => {
      void prisma.$disconnect().finally(() => process.exit(0));
    });
  });
}
