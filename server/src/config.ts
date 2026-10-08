import fs from 'node:fs';
import path from 'node:path';

/** Minimal .env loader (no dependency): KEY=VALUE lines, # comments, optional quotes. Real env vars win. */
function loadDotEnv(file: string) {
  if (!fs.existsSync(file)) return;
  for (const raw of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const i = line.indexOf('=');
    if (i < 1) continue;
    const key = line.slice(0, i).trim();
    let val = line.slice(i + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) val = val.slice(1, -1);
    if (process.env[key] === undefined) process.env[key] = val;
  }
}
loadDotEnv(path.resolve(process.env.ENV_FILE ?? '.env'));

const env = process.env;
const registration = (env.REGISTRATION ?? 'open') as 'open' | 'code' | 'closed';

export const config = {
  port: Number(env.PORT ?? 4200),
  databaseUrl: env.DATABASE_URL ?? '',
  schema: env.DB_SCHEMA ?? 'masarefy',
  autoMigrate: (env.AUTO_MIGRATE ?? 'on') === 'on',
  migrationsDir: path.resolve(env.MIGRATIONS_DIR ?? 'migrations'),
  jwtSecret: env.JWT_ACCESS_SECRET ?? '',
  registration,
  signupCode: env.SIGNUP_CODE ?? '',
  corsOrigins: (env.CORS_ORIGIN ?? '').split(',').map((s) => s.trim()).filter(Boolean),
  accessTtlSec: 15 * 60,
  refreshTtlDays: 60,
  version: '1.0.0',
};

export function assertConfig() {
  if (!config.databaseUrl) throw new Error('DATABASE_URL is not set');
  if (config.jwtSecret.length < 32) throw new Error('JWT_ACCESS_SECRET must be at least 32 characters');
  if (!/^[a-z_][a-z0-9_]*$/i.test(config.schema)) throw new Error('DB_SCHEMA must be a simple identifier');
}
