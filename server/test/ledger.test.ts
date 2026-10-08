import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { after, before, describe, it } from 'node:test';
import type { AddressInfo } from 'node:net';

process.env.DATABASE_URL = process.env.TEST_DATABASE_URL ?? 'postgres://masarefy@127.0.0.1:5433/masarefy_test';
process.env.DB_SCHEMA = 'masarefy_ledger_t';
process.env.JWT_ACCESS_SECRET = 'test-secret-test-secret-test-secret-123';
process.env.REGISTRATION = 'open';
process.env.ENV_FILE = 'does-not-exist';

const { createApp } = await import('../src/app.ts');
const db = await import('../src/db.ts');

let base = '';
let server: ReturnType<ReturnType<typeof createApp>['listen']>;

async function call(method: string, path: string, body?: unknown, token?: string) {
  const res = await fetch(base + path, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: res.status, body: (await res.json().catch(() => null)) as any };
}

let n = 0;
async function user(name: string) {
  const email = `${name.toLowerCase()}_${Date.now()}_${n++}@example.com`;
  const r = await call('POST', '/api/auth/register', { email, password: 'password123', name });
  assert.equal(r.status, 201);
  return { email, token: r.body.accessToken as string };
}

const sync = (token: string, body: Record<string, unknown> = {}) =>
  call('POST', '/api/sync', { cursor: 0, ledgerCursor: 0, notificationCursor: 0, changes: {}, ...body }, token);

const create = (extra: Record<string, unknown>) => ({
  op: 'create', id: crypto.randomUUID(), kind: 'LOAN', direction: 'RECEIVED', amount: 100000, date: '2026-10-01', ...extra,
});

before(async () => {
  db.initPool();
  await db.pool.query('DROP SCHEMA IF EXISTS masarefy_ledger_t CASCADE');
  await db.migrate();
  server = createApp().listen(0);
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

after(async () => {
  server.close();
  await db.pool.query('DROP SCHEMA IF EXISTS masarefy_ledger_t CASCADE');
  await db.pool.end();
});

describe('shared ledger', () => {
  it('the document scenario: loan from Ahmed, repaid in three settlements', async () => {
    const me = await user('Me');
    const ahmed = await user('Ahmed');

    // Ahmed -> me 100,000 (I record it: I RECEIVED)
    const loan = create({ counterpartEmail: ahmed.email, personId: 'p-ahmed' });
    const r1 = await sync(me.token, { ledgerOps: [loan] });
    assert.equal(r1.status, 200);
    assert.deepEqual(r1.body.ledgerResults, [{ id: loan.id, op: 'create', ok: true, status: 'PENDING' }]);
    const mine = r1.body.ledger.entries[0];
    assert.equal(mine.direction, 'RECEIVED');
    assert.equal(mine.personId, 'p-ahmed');
    assert.equal(mine.counterparty.name, 'Ahmed');

    // Ahmed sees it from his side, with a notification, and confirms.
    const a1 = await sync(ahmed.token);
    const theirs = a1.body.ledger.entries[0];
    assert.equal(theirs.direction, 'GAVE');
    assert.equal(theirs.createdByMe, false);
    assert.equal(theirs.counterparty.name, 'Me');
    assert.equal(a1.body.notifications.items[0].type, 'NEW_ENTRY');
    const a2 = await sync(ahmed.token, { ledgerCursor: a1.body.ledger.cursor, ledgerOps: [{ op: 'confirm', id: loan.id }] });
    assert.equal(a2.body.ledgerResults[0].status, 'CONFIRMED');

    // Three repayments; Ahmed confirms them all.
    const pays = [20000, 15000, 65000].map((amount) =>
      create({ kind: 'SETTLEMENT', direction: 'GAVE', amount, counterpartEmail: ahmed.email, settlesEntryId: loan.id }));
    const r2 = await sync(me.token, { ledgerOps: pays });
    assert.ok(r2.body.ledgerResults.every((x: any) => x.ok && x.status === 'PENDING'));
    const a3 = await sync(ahmed.token, { ledgerOps: pays.map((p) => ({ op: 'confirm', id: p.id })) });
    assert.ok(a3.body.ledgerResults.every((x: any) => x.status === 'CONFIRMED'));
    assert.ok(a3.body.notifications.items.some((x: any) => x.type === 'SETTLEMENT_RECEIVED'));

    // My balance with Ahmed from confirmed entries: GAVE - RECEIVED = 0 (settled).
    const all = (await sync(me.token)).body.ledger.entries.filter((e: any) => e.status === 'CONFIRMED');
    const net = all.reduce((s: number, e: any) => s + (e.direction === 'GAVE' ? e.amount : -e.amount), 0);
    assert.equal(all.length, 4);
    assert.equal(net, 0);
    // I was told about each confirmation.
    assert.equal((await sync(me.token)).body.notifications.items.filter((x: any) => x.type === 'CONFIRMED').length, 4);
  });

  it('is idempotent: the same create sent twice makes one entry', async () => {
    const me = await user('Me');
    const op = create({ counterpartName: 'No account' });
    await sync(me.token, { ledgerOps: [op] });
    const again = await sync(me.token, { ledgerOps: [op] });
    assert.deepEqual(again.body.ledgerResults[0], { id: op.id, op: 'create', ok: true, status: 'CONFIRMED' });
    assert.equal(again.body.ledger.entries.length, 1);
  });

  it('a person without an account: one-sided, confirmed at once, can be voided by the creator', async () => {
    const me = await user('Me');
    const op = create({ counterpartEmail: 'not-registered@example.com', counterpartName: 'Khaled', direction: 'GAVE', amount: 500 });
    const r = await sync(me.token, { ledgerOps: [op] });
    assert.equal(r.body.ledgerResults[0].status, 'CONFIRMED');
    assert.equal(r.body.ledger.entries[0].counterparty.name, 'Khaled');
    assert.equal(r.body.ledger.entries[0].counterparty.userId, null);
    const v = await sync(me.token, { ledgerOps: [{ op: 'cancel', id: op.id }] });
    assert.equal(v.body.ledgerResults[0].status, 'CANCELLED');
  });

  it('enforces who may do what, and rejects carry a reason', async () => {
    const a = await user('A');
    const b = await user('B');
    const c = await user('C');
    const op = create({ counterpartEmail: b.email, amount: 50 });
    await sync(a.token, { ledgerOps: [op] });

    assert.equal((await sync(a.token, { ledgerOps: [{ op: 'confirm', id: op.id }] })).body.ledgerResults[0].error, 'not_allowed');
    assert.equal((await sync(c.token, { ledgerOps: [{ op: 'confirm', id: op.id }] })).body.ledgerResults[0].error, 'not_found');
    assert.equal((await sync(c.token)).body.ledger.entries.length, 0, 'outsiders never see the entry');

    const rej = await sync(b.token, { ledgerOps: [{ op: 'reject', id: op.id, reason: 'wrong amount' }] });
    assert.equal(rej.body.ledgerResults[0].status, 'REJECTED');
    const seenByA = (await sync(a.token)).body;
    assert.equal(seenByA.ledger.entries[0].status, 'REJECTED');
    assert.equal(seenByA.ledger.entries[0].rejectReason, 'wrong amount');
    assert.ok(seenByA.notifications.items.some((x: any) => x.type === 'REJECTED'));

    // Once rejected it cannot be confirmed or cancelled; a confirmed shared entry cannot be cancelled.
    assert.equal((await sync(b.token, { ledgerOps: [{ op: 'confirm', id: op.id }] })).body.ledgerResults[0].error, 'invalid_state');
    const op2 = create({ counterpartEmail: b.email, amount: 70 });
    await sync(a.token, { ledgerOps: [op2] });
    await sync(b.token, { ledgerOps: [{ op: 'confirm', id: op2.id }] });
    assert.equal((await sync(a.token, { ledgerOps: [{ op: 'cancel', id: op2.id }] })).body.ledgerResults[0].error, 'invalid_state');

    // A pending one can be withdrawn by its creator, and the other side is told.
    const op3 = create({ counterpartEmail: b.email, amount: 10 });
    await sync(a.token, { ledgerOps: [op3] });
    assert.equal((await sync(a.token, { ledgerOps: [{ op: 'cancel', id: op3.id }] })).body.ledgerResults[0].status, 'CANCELLED');
    assert.ok((await sync(b.token)).body.notifications.items.some((x: any) => x.type === 'CANCELLED'));
  });

  it('cannot record an entry with yourself', async () => {
    const a = await user('A');
    const r = await sync(a.token, { ledgerOps: [create({ counterpartEmail: a.email })] });
    assert.equal(r.body.ledgerResults[0].error, 'self_counterparty');
  });

  it('marks notifications read (and other devices learn it)', async () => {
    const a = await user('A');
    const b = await user('B');
    await sync(a.token, { ledgerOps: [create({ counterpartEmail: b.email, amount: 5 })] });
    const first = await sync(b.token);
    const n1 = first.body.notifications.items[0];
    assert.equal(n1.readAt, null);
    const after = await sync(b.token, { notificationCursor: first.body.notifications.cursor, readNotifications: [n1.id] });
    assert.ok(after.body.notifications.items[0].readAt);
  });

  it('account deletion keeps shared history for the other side only', async () => {
    const a = await user('Alice');
    const b = await user('Bob');
    const shared = create({ counterpartEmail: b.email, amount: 9 });
    const solo = create({ counterpartName: 'Cash friend', amount: 3 });
    await sync(a.token, { ledgerOps: [shared, solo] });
    await call('DELETE', '/api/me', { password: 'password123' }, a.token);
    const seen = (await sync(b.token)).body.ledger.entries;
    assert.equal(seen.length, 1);
    assert.equal(seen[0].counterparty.name, 'Alice');
    assert.equal(seen[0].counterparty.userId, null);
    const soloLeft = await db.pool.query('SELECT 1 FROM masarefy_ledger_t.ledger_entries WHERE id = $1', [solo.id]);
    assert.equal(soloLeft.rowCount, 0);
  });

  it('people sync like the other personal data', async () => {
    const a = await user('A');
    const r = await sync(a.token, {
      changes: { people: [{ id: 'p1', name: 'Ahmed', phone: '0100', email: null, notes: null, linkedUserId: null, updatedAt: new Date().toISOString() }] },
    });
    assert.equal(r.body.applied.people, 1);
    assert.equal((await call('GET', '/api/export', undefined, a.token)).body.data.people[0].name, 'Ahmed');
  });
});
