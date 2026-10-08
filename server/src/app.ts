import crypto from 'node:crypto';
import fs from 'node:fs';
import express, { type NextFunction, type Request, type Response } from 'express';
import { z, ZodError } from 'zod';
import { config } from './config.ts';
import { pool, withTx } from './db.ts';
import { hashPassword, hashToken, newRefreshToken, rateLimit, requireAuth, signAccess, verifyPassword } from './auth.ts';
import { pushSchema } from './entities.ts';
import { createOtp, isValidPhone, normalizePhone, verifyOtp } from './phone.ts';
import { exportAll, sync } from './sync.ts';
import { applyOp, detachUserFromLedger, ledgerFeed, markNotificationsRead, notificationFeed, usersTouchedBy, type OpResult } from './ledger.ts';

const phoneField = z
  .string()
  .max(30)
  .transform(normalizePhone)
  .refine(isValidPhone, 'invalid phone');

/** Login with e-mail or mobile number (`login`); `email` is still accepted from older apps. */
const loginSchema = z
  .object({
    login: z.string().trim().min(3).max(200).optional(),
    email: z.string().trim().max(200).optional(),
    password: z.string().min(8).max(200),
  })
  .refine((b) => !!(b.login || b.email), { message: 'login required', path: ['login'] });

/** New accounts register with a mobile number + OTP; e-mail-only registration is kept for older apps. */
const registerSchema = z
  .object({
    phone: phoneField.optional(),
    otp: z.string().regex(/^\d{6}$/).optional(),
    email: z.string().trim().toLowerCase().email().max(200).optional().or(z.literal('').transform(() => undefined)),
    password: z.string().min(8).max(200),
    name: z.string().trim().max(100).default(''),
    signupCode: z.string().max(100).optional(),
  })
  .refine((b) => !!(b.phone || b.email), { message: 'phone or email required', path: ['phone'] })
  .refine((b) => !b.phone || !!b.otp, { message: 'otp required', path: ['otp'] });

interface UserRow {
  id: string;
  email: string | null;
  phone: string | null;
  name: string;
  password_hash: string;
}

const USER_COLS = 'id, email, phone, name, password_hash';

async function issueTokens(tx: import('./db.ts').Tx, user: UserRow, userAgent: string | undefined) {
  const refresh = newRefreshToken();
  await tx.query(
    `INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, user_agent)
     VALUES ($1, $2, $3, now() + ($4 || ' days')::interval, $5)`,
    [crypto.randomUUID(), user.id, hashToken(refresh), String(config.refreshTtlDays), userAgent?.slice(0, 300) ?? null],
  );
  return {
    user: { id: user.id, email: user.email, phone: user.phone, name: user.name },
    accessToken: signAccess(user.id),
    refreshToken: refresh,
    expiresIn: config.accessTtlSec,
  };
}

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', true);
  app.use(express.json({ limit: '8mb' }));

  app.use((req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    if (req.path.startsWith('/api')) res.setHeader('Cache-Control', 'no-store');
    const origin = req.header('origin');
    if (origin && config.corsOrigins.includes(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
      res.setHeader('Access-Control-Allow-Headers', 'authorization, content-type');
      res.setHeader('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS');
    }
    if (req.method === 'OPTIONS') {
      res.sendStatus(204);
      return;
    }
    next();
  });

  const api = express.Router();

  api.get('/health', async (_req, res) => {
    let db = false;
    try {
      await pool.query('SELECT 1');
      db = true;
    } catch {
      /* reported below */
    }
    res.status(db ? 200 : 503).json({ ok: db, db, version: config.version, time: new Date().toISOString() });
  });

  const byIp = (req: Request) => `${req.ip}`;
  const authLimiter = rateLimit(20, 15 * 60 * 1000, (req) => `${byIp(req)}|${String(req.body?.login ?? req.body?.email ?? req.body?.phone ?? '').toLowerCase()}`);
  const otpLimiter = rateLimit(5, 15 * 60 * 1000, (req) => `${byIp(req)}|${String(req.body?.phone ?? '')}`);

  /** Step 1 of mobile sign-up: send (in dev mode: return) a one-time code. */
  api.post('/auth/otp/request', otpLimiter, async (req, res) => {
    if (config.registration === 'closed') {
      res.status(403).json({ error: 'registration_closed' });
      return;
    }
    const { phone } = z.object({ phone: phoneField }).parse(req.body);
    const result = await withTx(async (tx) => {
      if ((await tx.query('SELECT 1 FROM users WHERE phone = $1', [phone])).rowCount) return null;
      return createOtp(tx, phone, 'register');
    });
    if (!result) {
      res.status(409).json({ error: 'phone_taken' });
      return;
    }
    res.json({ sent: true, phone, ...result });
  });

  api.post('/auth/register', authLimiter, async (req, res) => {
    if (config.registration === 'closed') {
      res.status(403).json({ error: 'registration_closed' });
      return;
    }
    const body = registerSchema.parse(req.body);
    if (config.registration === 'code' && (!config.signupCode || body.signupCode !== config.signupCode)) {
      res.status(403).json({ error: 'invalid_signup_code' });
      return;
    }
    const passwordHash = await hashPassword(body.password);
    const result = await withTx(async (tx) => {
      if (body.email && (await tx.query('SELECT 1 FROM users WHERE lower(email) = $1', [body.email])).rowCount) return 'email_taken';
      if (body.phone) {
        if ((await tx.query('SELECT 1 FROM users WHERE phone = $1', [body.phone])).rowCount) return 'phone_taken';
        const otpError = await verifyOtp(tx, body.phone, 'register', body.otp!);
        if (otpError) return otpError;
      }
      const user: UserRow = { id: crypto.randomUUID(), email: body.email ?? null, phone: body.phone ?? null, name: body.name, password_hash: passwordHash };
      await tx.query('INSERT INTO users (id, email, name, password_hash, phone, last_login_at) VALUES ($1,$2,$3,$4,$5, now())', [
        user.id, user.email, user.name, user.password_hash, user.phone,
      ]);
      return issueTokens(tx, user, req.header('user-agent'));
    });
    if (typeof result === 'string') {
      res.status(result === 'email_taken' || result === 'phone_taken' ? 409 : 400).json({ error: result });
      return;
    }
    res.status(201).json(result);
  });

  api.post('/auth/login', authLimiter, async (req, res) => {
    const body = loginSchema.parse(req.body);
    const login = (body.login ?? body.email)!.trim();
    const result = await withTx(async (tx) => {
      const row = (
        login.includes('@')
          ? await tx.query(`SELECT ${USER_COLS} FROM users WHERE lower(email) = $1`, [login.toLowerCase()])
          : await tx.query(`SELECT ${USER_COLS} FROM users WHERE phone = $1`, [normalizePhone(login)])
      ).rows[0] as UserRow | undefined;
      // Same work either way so response time does not reveal whether the email exists.
      const ok = row ? await verifyPassword(body.password, row.password_hash) : (await hashPassword(body.password), false);
      if (!row || !ok) return null;
      await tx.query('UPDATE users SET last_login_at = now() WHERE id = $1', [row.id]);
      return issueTokens(tx, row, req.header('user-agent'));
    });
    if (!result) {
      res.status(401).json({ error: 'invalid_credentials' });
      return;
    }
    res.json(result);
  });

  api.post('/auth/refresh', rateLimit(60, 15 * 60 * 1000, byIp), async (req, res) => {
    const { refreshToken } = z.object({ refreshToken: z.string().min(20).max(200) }).parse(req.body);
    const result = await withTx(async (tx) => {
      const row = (
        await tx.query(
          `UPDATE refresh_tokens SET revoked_at = now()
           WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > now() RETURNING user_id`,
          [hashToken(refreshToken)],
        )
      ).rows[0];
      if (!row) return null;
      const user = (await tx.query(`SELECT ${USER_COLS} FROM users WHERE id = $1`, [row.user_id])).rows[0] as UserRow;
      return issueTokens(tx, user, req.header('user-agent'));
    });
    if (!result) {
      res.status(401).json({ error: 'invalid_refresh_token' });
      return;
    }
    res.json(result);
  });

  api.post('/auth/logout', async (req, res) => {
    const { refreshToken } = z.object({ refreshToken: z.string().max(200).optional() }).parse(req.body ?? {});
    if (refreshToken) {
      await withTx((tx) => tx.query('UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1 AND revoked_at IS NULL', [hashToken(refreshToken)]));
    }
    res.json({ ok: true });
  });

  api.get('/me', requireAuth, async (req, res) => {
    const row = await withTx(async (tx) =>
      (await tx.query('SELECT id, email, phone, name, created_at FROM users WHERE id = $1', [req.userId])).rows[0],
    );
    if (!row) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }
    res.json(row);
  });

  /** Deletes the account and every row it owns (FKs cascade). Requires the password again. */
  api.delete('/me', requireAuth, async (req, res) => {
    const { password } = z.object({ password: z.string().min(1).max(200) }).parse(req.body);
    const done = await withTx(async (tx) => {
      const row = (await tx.query('SELECT password_hash FROM users WHERE id = $1', [req.userId])).rows[0];
      if (!row || !(await verifyPassword(password, row.password_hash))) return false;
      await detachUserFromLedger(tx, req.userId!);
      await tx.query('DELETE FROM users WHERE id = $1', [req.userId]);
      return true;
    });
    res.status(done ? 200 : 403).json(done ? { ok: true } : { error: 'invalid_credentials' });
  });

  api.post('/sync', requireAuth, async (req, res) => {
    const body = pushSchema.parse(req.body);
    const me = req.userId!;
    const result = await withTx(async (tx) => {
      // Lock every user this request writes for, always in the same order (no deadlocks), so a
      // feed cursor can never skip a row that commits late.
      const others = await usersTouchedBy(tx, me, body.ledgerOps);
      for (const id of [me, ...others].sort()) {
        await tx.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 77))', [id]);
      }
      const personal = await sync(tx, me, body.cursor, body.changes as never);
      const ledgerResults: OpResult[] = [];
      for (const op of body.ledgerOps) ledgerResults.push(await applyOp(tx, me, op));
      await markNotificationsRead(tx, me, body.readNotifications);
      const ledger = await ledgerFeed(tx, me, body.ledgerCursor);
      const notifications = await notificationFeed(tx, me, body.notificationCursor);
      return {
        ...personal,
        hasMore: personal.hasMore || ledger.hasMore || notifications.hasMore,
        ledgerResults,
        ledger,
        notifications,
      };
    });
    res.json(result);
  });

  /** Full JSON dump of the caller's live (non-deleted) data – handy for checking what the server holds. */
  api.get('/export', requireAuth, async (req, res) => {
    const data = await withTx((tx) => exportAll(tx, req.userId!));
    res.json({ exportedAt: new Date().toISOString(), data });
  });

  app.use('/api', api);

  // Optional download page: anything in ./public (index.html, the APKs) is served as-is.
  if (fs.existsSync(config.webDir)) {
    app.use(express.static(config.webDir, { index: 'index.html', dotfiles: 'ignore', maxAge: '5m' }));
  }
  app.get('/', (_req, res) => {
    res
      .type('html')
      .send('<!doctype html><meta charset="utf-8"><title>Masarefy server</title><body style="font-family:sans-serif;padding:2rem"><h1>Masarefy server</h1><p>OK – <a href="/api/health">/api/health</a></p>');
  });

  app.use((_req, res) => {
    res.status(404).json({ error: 'not_found' });
  });

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof ZodError) {
      res.status(400).json({ error: 'validation_failed', issues: err.issues.slice(0, 10).map((i) => ({ path: i.path.join('.'), message: i.message })) });
      return;
    }
    if ((err as { type?: string }).type === 'entity.too.large') {
      res.status(413).json({ error: 'payload_too_large' });
      return;
    }
    if (err instanceof SyntaxError) {
      res.status(400).json({ error: 'invalid_json' });
      return;
    }
    console.error('unhandled', err);
    res.status(500).json({ error: 'server_error' });
  });

  return app;
}
