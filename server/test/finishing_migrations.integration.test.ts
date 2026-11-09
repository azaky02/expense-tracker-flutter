import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import pg from 'pg';

const url = process.env.FINISHING_TEST_DATABASE_URL;
const migrationsDir = path.resolve(import.meta.dirname, '../migrations');

test('actual server migrations apply in order and finishing tables exist', {
  skip: !url ? 'FINISHING_TEST_DATABASE_URL is not configured' : false,
}, async () => {
  const pool = new pg.Pool({ connectionString: url, max: 1 });
  const client = await pool.connect();
  const schema = 'finishing_migrate_' + Math.random().toString(36).slice(2, 11);
  try {
    await client.query('CREATE SCHEMA "' + schema + '"');
    await client.query('BEGIN');
    await client.query('SET LOCAL search_path TO "' + schema + '"');
    const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
    assert.ok(files.includes('0007_finishing_closure.sql'));
    for (const file of files) {
      await client.query(fs.readFileSync(path.join(migrationsDir, file), 'utf8'));
    }
    const columns = await client.query(
      `SELECT column_name FROM information_schema.columns
       WHERE table_schema=$1 AND table_name='finishing_project_balances'`, [schema],
    );
    const names = new Set(columns.rows.map((row: { column_name: string }) => row.column_name));
    for (const required of ['custody_piasters','receivable_piasters','cost_piasters','financial_status','closed_at']) {
      assert.ok(names.has(required), 'missing column: ' + required);
    }
    const reservations = await client.query(
      `SELECT column_name FROM information_schema.columns
       WHERE table_schema=$1 AND table_name='finishing_posting_requests'`, [schema],
    );
    assert.ok(reservations.rows.some((row: { column_name: string }) => row.column_name === 'project_id'));
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
    await pool.query('DROP SCHEMA IF EXISTS "' + schema + '" CASCADE');
    await pool.end();
  }
});
