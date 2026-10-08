import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { after, before, describe, it } from 'node:test';
import type { AddressInfo } from 'node:net';

process.env.DATABASE_URL = process.env.TEST_DATABASE_URL ?? 'postgres://masarefy@127.0.0.1:5433/masarefy_test';
process.env.DB_SCHEMA = 'masarefy_phone_t';
process.env.JWT_ACCESS_SECRET = 'test-secret-test-secret-test-secret-123';
process.env.REGISTRATION = 'open';
process.env.OTP_DEV_MODE = 'on';
process.env.ENV_FILE = 'does-not-exist';

const { createApp } = await import('../src/app.ts');
const db = await import('../src/db.ts');
const { normalizePhone } = await import('../src/phone.ts');

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

const phone = () => `010${String(crypto.randomInt(0, 1e8)).padStart(8, '0')}`;

before(async () => {
  db.initPool();
  await db.pool.query('DROP SCHEMA IF EXISTS masarefy_phone_t CASCADE');
  await db.migrate();
  server = createApp().listen(0);
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

after(async () => {
  server.close();
  await db.pool.query('DROP SCHEMA IF EXISTS masarefy_phone_t CASCADE');
  await db.pool.end();
});

describe('phone numbers', () => {
  it('normalises the common Egyptian forms to one value', () => {
    for (const p of ['01001234567', '0100 123 4567', '+201001234567', '00201001234567', '٠١٠٠١٢٣٤٥٦٧']) {
      assert.equal(normalizePhone(p), '01001234567');
    }
  });
});

describe('mobile sign-up with OTP', () => {
  it('requests a code (shown in dev mode), registers with it, then logs in by phone', async () => {
    const p = phone();
    const otp = await call('POST', '/api/auth/otp/request', { phone: p });
    assert.equal(otp.status, 200);
    assert.match(otp.body.devCode, /^\d{6}$/);

    const wrong = await call('POST', '/api/auth/register', { phone: p, otp: otp.body.devCode === '000000' ? '111111' : '000000', password: 'password123', name: 'Amr' });
    assert.equal(wrong.status, 400);
    assert.equal(wrong.body.error, 'invalid_otp');

    const ok = await call('POST', '/api/auth/register', { phone: p, otp: otp.body.devCode, password: 'password123', name: 'Amr' });
    assert.equal(ok.status, 201);
    assert.equal(ok.body.user.phone, p);
    assert.equal(ok.body.user.email, null);

    // The code is single-use, and the number is now taken.
    assert.equal((await call('POST', '/api/auth/register', { phone: p, otp: otp.body.devCode, password: 'password123' })).status, 409);
    assert.equal((await call('POST', '/api/auth/otp/request', { phone: p })).body.error, 'phone_taken');

    const login = await call('POST', '/api/auth/login', { login: '+2' + p, password: 'password123' });
    assert.equal(login.status, 200);
    assert.equal(login.body.user.id, ok.body.user.id);
  });

  it('rejects a missing code, a bad number, and keeps e-mail sign-up for older apps', async () => {
    assert.equal((await call('POST', '/api/auth/register', { phone: phone(), password: 'password123' })).status, 400);
    assert.equal((await call('POST', '/api/auth/otp/request', { phone: '12' })).status, 400);
    const email = `old_${crypto.randomUUID()}@example.com`;
    assert.equal((await call('POST', '/api/auth/register', { email, password: 'password123' })).status, 201);
    assert.equal((await call('POST', '/api/auth/login', { email, password: 'password123' })).status, 200);
  });

  it('shares a ledger entry with a person found by mobile number', async () => {
    const p = phone();
    const code = (await call('POST', '/api/auth/otp/request', { phone: p })).body.devCode;
    const ahmed = await call('POST', '/api/auth/register', { phone: p, otp: code, password: 'password123', name: 'Ahmed' });
    const me = await call('POST', '/api/auth/register', { email: `me_${crypto.randomUUID()}@example.com`, password: 'password123', name: 'Me' });
    const op = { op: 'create', id: crypto.randomUUID(), kind: 'LOAN', direction: 'RECEIVED', amount: 100, date: '2026-10-08', counterpartPhone: '+2' + p };
    const r = await call('POST', '/api/sync', { cursor: 0, changes: {}, ledgerOps: [op] }, me.body.accessToken);
    assert.equal(r.body.ledgerResults[0].status, 'PENDING');
    const theirs = await call('POST', '/api/sync', { cursor: 0, changes: {} }, ahmed.body.accessToken);
    assert.equal(theirs.body.ledger.entries[0].counterparty.name, 'Me');
    assert.equal(r.body.ledger.entries[0].counterparty.phone, p);
  });
});
