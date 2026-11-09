import assert from 'node:assert/strict';
import test from 'node:test';
import { initializeFinishingProjectBalance } from '../src/finishing_project_initialization.ts';

test('project ledger initializes once without overwriting an existing balance', async () => {
  const existing = new Set<string>();
  const tx = {
    async query(sql: string, params: unknown[]) {
      const key = params.join(':');
      if (sql.includes('INSERT INTO finishing_project_balances')) {
        if (existing.has(key)) return { rowCount: 0, rows: [] };
        existing.add(key);
        return { rowCount: 1, rows: [] };
      }
      if (sql.includes('SELECT 1 FROM finishing_project_balances')) {
        return { rowCount: existing.has(key) ? 1 : 0, rows: [] };
      }
      throw new Error('unexpected SQL');
    },
  };
  assert.equal(await initializeFinishingProjectBalance(tx as never, 'u1', { projectId: 'p1' }), 'created');
  assert.equal(await initializeFinishingProjectBalance(tx as never, 'u1', { projectId: 'p1' }), 'already_exists');
  assert.equal(existing.size, 1);
});

test('rejects invalid project identity before database mutation', async () => {
  const tx = { query: async () => { throw new Error('should not query'); } };
  await assert.rejects(
    () => initializeFinishingProjectBalance(tx as never, 'u1', { projectId: '../bad' }),
    /invalid project identity/,
  );
});
