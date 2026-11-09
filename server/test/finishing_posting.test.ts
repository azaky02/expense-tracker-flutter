import assert from 'node:assert/strict';
import test from 'node:test';
import { commitFinishingPosting, postingPayloadHash } from '../src/finishing_posting.ts';

type Row = { payload_hash: string; state: 'reserved' | 'committed' };
function fakeTx() {
  const rows = new Map<string, Row>();
  const movements: string[] = [];
  const tx = {
    async query(sql: string, params: unknown[] = []) {
      const key = String(params[0]) + ':' + String(params[1]);
      if (sql.includes('INSERT INTO finishing_posting_requests')) {
        if (rows.has(key)) return { rowCount: 0, rows: [] };
        rows.set(key, { payload_hash: String(params[2]), state: 'reserved' });
        return { rowCount: 1, rows: [] };
      }
      if (sql.includes('SELECT payload_hash,state')) {
        const row = rows.get(key);
        return { rowCount: row ? 1 : 0, rows: row ? [row] : [] };
      }
      if (sql.includes('UPDATE finishing_posting_requests')) {
        const row = rows.get(key);
        if (!row || row.state !== 'reserved' || row.payload_hash !== params[2])
          return { rowCount: 0, rows: [] };
        row.state = 'committed';
        return { rowCount: 1, rows: [] };
      }
      throw new Error('unexpected SQL');
    },
  };
  return { tx, rows, movements };
}

test('same payload is posted only once in sequential retries', async () => {
  const { tx, movements } = fakeTx();
  const hash = postingPayloadHash({ amountPiasters: 12345 });
  const callback = async () => { movements.push('cash-leg'); };
  assert.equal(await commitFinishingPosting(tx as never, 'u1', 'e1', hash, callback), 'posted');
  assert.equal(await commitFinishingPosting(tx as never, 'u1', 'e1', hash, callback), 'already_committed');
  assert.deepEqual(movements, ['cash-leg']);
});

test('changed payload is rejected before a second cash movement', async () => {
  const { tx, movements } = fakeTx();
  await commitFinishingPosting(tx as never, 'u1', 'e1', postingPayloadHash({ a: 1 }),
    async () => { movements.push('first'); });
  await assert.rejects(() => commitFinishingPosting(tx as never, 'u1', 'e1',
    postingPayloadHash({ a: 2 }), async () => { movements.push('second'); }));
  assert.deepEqual(movements, ['first']);
});

test('callback failure never marks the request committed', async () => {
  const { tx, rows } = fakeTx();
  await assert.rejects(() => commitFinishingPosting(tx as never, 'u1', 'e1',
    postingPayloadHash({ a: 1 }), async () => { throw new Error('cash write failed'); }));
  assert.equal(rows.get('u1:e1')?.state, 'reserved');
});
