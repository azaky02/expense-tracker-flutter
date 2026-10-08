import { createApp } from './app.ts';
import { assertConfig, config } from './config.ts';
import { initPool, migrate, pool } from './db.ts';

assertConfig();
initPool();
if (config.autoMigrate) await migrate();

const app = createApp();
const server = app.listen(config.port, () => console.log(`masarefy server v${config.version} on :${config.port}`));

for (const sig of ['SIGINT', 'SIGTERM'] as const) {
  process.on(sig, () => {
    server.close(() => pool.end().finally(() => process.exit(0)));
  });
}
