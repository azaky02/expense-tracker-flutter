import fs from 'node:fs';
import path from 'node:path';
import pg from 'pg';
import { config } from './config.ts';

// Return numbers/dates as plain values instead of strings/Date objects.
pg.types.setTypeParser(1082, (v) => v); // date → 'YYYY-MM-DD' (no timezone shifting)
pg.types.setTypeParser(1700, (v) => parseFloat(v)); // numeric
pg.types.setTypeParser(20, (v) => Number(v)); // bigint (seq)

export let pool: pg.Pool;

export function initPool() {
  // No startup 'options' (PgBouncer rejects them): the schema is set inside every transaction instead.
  pool = new pg.Pool({ connectionString: config.databaseUrl, max: 8, idleTimeoutMillis: 30_000, connectionTimeoutMillis: 15_000 });
  pool.on('error', (e) => console.error('pg pool error', e.message));
  return pool;
}

export type Tx = pg.PoolClient;

/** Runs `fn` in a transaction with the app schema on the search_path. Reads use it too (pooler-safe). */
export async function withTx<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    await c.query(`SET LOCAL search_path TO "${config.schema}"`);
    const out = await fn(c);
    await c.query('COMMIT');
    return out;
  } catch (e) {
    await c.query('ROLLBACK').catch(() => {});
    throw e;
  } finally {
    c.release();
  }
}

export async function migrate() {
  const c = await pool.connect();
  try {
    // Hosts like SmarterASP put PgBouncer (transaction pooling) in front of Postgres, where session
    // state (SET, session advisory locks) does not survive between statements: do everything in one
    // transaction instead. A failing migration rolls back the whole batch.
    try {
      await c.query(`CREATE SCHEMA IF NOT EXISTS "${config.schema}"`);
    } catch (e) {
      console.warn(`could not create schema "${config.schema}" (${(e as Error).message}); assuming it exists`);
    }
    await c.query('BEGIN');
    await c.query(`SET LOCAL search_path TO "${config.schema}"`);
    await c.query('SELECT pg_advisory_xact_lock(7731001)');
    await c.query('CREATE TABLE IF NOT EXISTS schema_migrations (name text primary key, applied_at timestamptz not null default now())');
    const done = new Set((await c.query('SELECT name FROM schema_migrations')).rows.map((r) => r.name as string));
    const files = fs.readdirSync(config.migrationsDir).filter((f) => f.endsWith('.sql')).sort();
    for (const f of files) {
      if (done.has(f)) continue;
      try {
        await c.query(fs.readFileSync(path.join(config.migrationsDir, f), 'utf8'));
        await c.query('INSERT INTO schema_migrations (name) VALUES ($1)', [f]);
        console.log(`migration applied: ${f}`);
      } catch (e) {
        throw new Error(`migration ${f} failed: ${(e as Error).message}`);
      }
    }
    await c.query('COMMIT');
  } catch (e) {
    await c.query('ROLLBACK').catch(() => {});
    throw e;
  } finally {
    c.release();
  }
}
