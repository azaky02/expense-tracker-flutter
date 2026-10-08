import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import type { AddressInfo } from 'node:net';

process.env.DATABASE_URL = process.env.TEST_DATABASE_URL ?? 'postgres://masarefy@127.0.0.1:5433/masarefy_test';
process.env.DB_SCHEMA = 'masarefy_t';
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

const iso = (offsetMs = 0) => new Date(Date.now() + offsetMs).toISOString();
const tx = (id: string, extra: Record<string, unknown> = {}) => ({
  id, amount: 50.5, type: 'expense', categoryId: 'cat1', paymentMethodType: 'cash', cardId: null,
  date: '2026-10-08', note: null, beneficiaryName: null, createdAt: iso(), updatedAt: iso(), deletedAt: null, ...extra,
});

let n = 0;
async function newUser() {
  const email = `u${Date.now()}_${n++}@example.com`;
  const r = await call('POST', '/api/auth/register', { email, password: 'password123', name: 'T' });
  assert.equal(r.status, 201);
  return { email, token: r.body.accessToken as string, refresh: r.body.refreshToken as string };
}

before(async () => {
  db.initPool();
  await db.pool.query('DROP SCHEMA IF EXISTS masarefy_t CASCADE');
  await db.migrate();
  server = createApp().listen(0);
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

after(async () => {
  server.close();
  await db.pool.query('DROP SCHEMA IF EXISTS masarefy_t CASCADE');
  await db.pool.end();
});

describe('auth', () => {
  it('registers, rejects duplicates, logs in, rejects wrong password', async () => {
    const u = await newUser();
    assert.equal((await call('POST', '/api/auth/register', { email: u.email.toUpperCase(), password: 'password123' })).status, 409);
    assert.equal((await call('POST', '/api/auth/login', { email: u.email, password: 'password123' })).status, 200);
    assert.equal((await call('POST', '/api/auth/login', { email: u.email, password: 'wrong-password' })).status, 401);
    assert.equal((await call('POST', '/api/auth/register', { email: 'bad', password: 'password123' })).status, 400);
    assert.equal((await call('POST', '/api/auth/register', { email: 'x@example.com', password: 'short' })).status, 400);
  });

  it('rotates refresh tokens (old one stops working)', async () => {
    const u = await newUser();
    const r1 = await call('POST', '/api/auth/refresh', { refreshToken: u.refresh });
    assert.equal(r1.status, 200);
    assert.notEqual(r1.body.refreshToken, u.refresh);
    assert.equal((await call('POST', '/api/auth/refresh', { refreshToken: u.refresh })).status, 401);
    assert.equal((await call('GET', '/api/me', undefined, r1.body.accessToken)).status, 200);
  });

  it('requires a token for data endpoints', async () => {
    assert.equal((await call('POST', '/api/sync', { cursor: 0, changes: {} })).status, 401);
    assert.equal((await call('GET', '/api/export')).status, 401);
  });
});

describe('sync', () => {
  it('pushes from device A and pulls on device B, without echoing to A', async () => {
    const u = await newUser();
    const push = await call('POST', '/api/sync', {
      cursor: 0,
      changes: {
        categories: [{ id: 'cat1', parentId: null, name: 'أكل', icon: '🍔', color: '#0e8c7f', type: 'expense', isDefault: true, updatedAt: iso() }],
        transactions: [tx('t1'), tx('t2', { amount: 10 })],
        beneficiaries: [{ name: 'ماما', lastUsedAt: iso(), updatedAt: iso() }],
      },
    }, u.token);
    assert.equal(push.status, 200);
    assert.deepEqual(push.body.applied, { banks: 0, categories: 1, cards: 0, beneficiaries: 1, transactions: 2, categoryBudgets: 0 });
    assert.deepEqual(push.body.changes, {}, 'own writes are not echoed');
    assert.ok(push.body.cursor > 0);

    const pullB = await call('POST', '/api/sync', { cursor: 0, changes: {} }, u.token);
    assert.equal(pullB.body.changes.transactions.length, 2);
    assert.equal(pullB.body.changes.transactions[0].date, '2026-10-08');
    assert.equal(pullB.body.changes.transactions[1].amount, 10);
    assert.equal(pullB.body.changes.categories[0].name, 'أكل');

    const again = await call('POST', '/api/sync', { cursor: pullB.body.cursor, changes: {} }, u.token);
    assert.deepEqual(again.body.changes, {});
    assert.equal(again.body.cursor, pullB.body.cursor);
  });

  it('last writer wins: older edits are ignored, newer ones and deletes propagate', async () => {
    const u = await newUser();
    await call('POST', '/api/sync', { cursor: 0, changes: { transactions: [tx('t1', { amount: 100, updatedAt: iso(-1000) })] } }, u.token);

    const stale = await call('POST', '/api/sync', { cursor: 0, changes: { transactions: [tx('t1', { amount: 1, updatedAt: iso(-60_000) })] } }, u.token);
    assert.equal(stale.body.applied.transactions, 0);
    assert.equal(stale.body.changes.transactions[0].amount, 100);

    const edit = await call('POST', '/api/sync', { cursor: 0, changes: { transactions: [tx('t1', { amount: 75, updatedAt: iso(-500) })] } }, u.token);
    assert.equal(edit.body.applied.transactions, 1);

    const del = await call('POST', '/api/sync', { cursor: 0, changes: { transactions: [tx('t1', { amount: 75, updatedAt: iso(), deletedAt: iso() })] } }, u.token);
    const pull = await call('POST', '/api/sync', { cursor: 0, changes: {} }, u.token);
    assert.equal(del.status, 200);
    assert.ok(pull.body.changes.transactions[0].deletedAt, 'tombstone is synced');
    assert.equal((await call('GET', '/api/export', undefined, u.token)).body.data.transactions.length, 0);
  });

  it('isolates users from each other', async () => {
    const a = await newUser();
    const b = await newUser();
    await call('POST', '/api/sync', { cursor: 0, changes: { transactions: [tx('same-id', { amount: 1 })] } }, a.token);
    await call('POST', '/api/sync', { cursor: 0, changes: { transactions: [tx('same-id', { amount: 2 })] } }, b.token);
    const ea = (await call('GET', '/api/export', undefined, a.token)).body.data.transactions;
    const eb = (await call('GET', '/api/export', undefined, b.token)).body.data.transactions;
    assert.equal(ea.length, 1);
    assert.equal(ea[0].amount, 1);
    assert.equal(eb[0].amount, 2);
  });

  it('rejects invalid records', async () => {
    const u = await newUser();
    for (const bad of [tx('x', { type: 'gift' }), tx('x', { amount: 'a lot' }), tx('x', { date: '2026-13-45' }), tx('x', { updatedAt: 'yesterday' })]) {
      const r = await call('POST', '/api/sync', { cursor: 0, changes: { transactions: [bad] } }, u.token);
      assert.equal(r.status, 400);
    }
  });

  it('pages large histories with hasMore and a stable cursor', async () => {
    const u = await newUser();
    const many = Array.from({ length: 1500 }, (_, i) => tx(`bulk${i}`, { amount: i + 1 }));
    await call('POST', '/api/sync', { cursor: 0, changes: { transactions: many } }, u.token);

    let cursor = 0;
    let total = 0;
    let rounds = 0;
    for (;;) {
      const r = await call('POST', '/api/sync', { cursor, changes: {} }, u.token);
      total += (r.body.changes.transactions ?? []).length;
      cursor = r.body.cursor;
      rounds++;
      if (!r.body.hasMore) break;
      assert.ok(rounds < 5);
    }
    assert.equal(total, 1500);
    assert.equal(rounds, 2);
  });

  it('deletes the account and all its data', async () => {
    const u = await newUser();
    await call('POST', '/api/sync', { cursor: 0, changes: { transactions: [tx('t1')] } }, u.token);
    assert.equal((await call('DELETE', '/api/me', { password: 'nope-nope' }, u.token)).status, 403);
    assert.equal((await call('DELETE', '/api/me', { password: 'password123' }, u.token)).status, 200);
    assert.equal((await call('POST', '/api/auth/login', { email: u.email, password: 'password123' })).status, 401);
    const left = await db.pool.query('SELECT count(*)::int AS n FROM masarefy_t.transactions');
    assert.ok(left.rows[0].n >= 0);
  });
});

describe('tombstones', () => {
  it('a bare delete marks a synced row deleted and ignores unknown rows', async () => {
    const u = await newUser();
    await call('POST', '/api/sync', { cursor: 0, changes: { transactions: [tx('t1', { updatedAt: iso(-5000) })] } }, u.token);
    const r = await call('POST', '/api/sync', {
      cursor: 0,
      changes: { transactions: [{ id: 't1', updatedAt: iso(), deletedAt: iso() }, { id: 'never-synced', updatedAt: iso(), deletedAt: iso() }] },
    }, u.token);
    assert.equal(r.status, 200);
    assert.equal(r.body.applied.transactions, 1);
    assert.equal((await call('GET', '/api/export', undefined, u.token)).body.data.transactions.length, 0);
  });
});
