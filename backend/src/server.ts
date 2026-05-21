import { createApp } from './app.js';
import { runSeed } from './common/seed.js';
import { env } from './config/env.js';

await runSeed();

const app = createApp();

app.listen(env.PORT, () => {
  console.log(`Korai backend listening on http://localhost:${env.PORT}`);
  console.log('Demo nurse: nurse@korai.local / Password123!');
  console.log('Demo specialist: orl@korai.local / Password123!');
  console.log('Demo admin: admin@korai.local / Password123!');
});
