import assert from 'node:assert/strict';
import test from 'node:test';
import { closeFinishingProject } from '../src/finishing_project_closure.ts';

type Balance = { financial_status: string; closed_at: string | null; custody_piasters: number; receivable_piasters: number };
function mockDb(balance: Balance, pending = false, unknown = false) {
  let updates = 0;
  const tx = {
    async query(sql: string) {
      if (sql.includes('SELECT financial_status,closed_at')) return { rowCount: 1, rows: [balance] };
      if (sql.includes('project_id=$2 AND state')) return { rowCount: pending ? 1 : 0, rows: [] };
      if (sql.includes('project_id IS NULL')) return { rowCount: unknown ? 1 : 0, rows: [] };
      if (sql.includes('UPDATE finishing_project_balances')) {
        updates++;
        balance.financial_status = 'closed';
        balance.closed_at = '2026-11-09T00:00:00.000Z';
        return { rowCount: 1, rows: [{ closed_at: balance.closed_at }] };
      }
      throw new Error('unexpected SQL');
    },
  };
  return { tx, getUpdates: () => updates };
}
const initial = (): Balance => ({
  financial_status: 'open', closed_at: null, custody_piasters: 0, receivable_piasters: 0,
});

test('closes settled project exactly once', async () => {
  const db = mockDb(initial());
  assert.equal((await closeFinishingProject(db.tx as never, 'u', 'p')).status, 'closed');
  assert.equal((await closeFinishingProject(db.tx as never, 'u', 'p')).status, 'already_closed');
  assert.equal(db.getUpdates(), 1);
});

test('blocks outstanding custody and personal receivable', async () => {
  for (const balances of [{ custody_piasters: 1 }, { receivable_piasters: 1 }]) {
    const db = mockDb({ ...initial(), ...balances });
    await assert.rejects(() => closeFinishingProject(db.tx as never, 'u', 'p'), /outstanding/);
    assert.equal(db.getUpdates(), 0);
  }
});

test('blocks pending and unscoped reservations', async () => {
  for (const [pending, unknown] of [[true, false], [false, true]]) {
    const db = mockDb(initial(), pending, unknown);
    await assert.rejects(() => closeFinishingProject(db.tx as never, 'u', 'p'));
    assert.equal(db.getUpdates(), 0);
  }
});
