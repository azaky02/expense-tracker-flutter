import crypto from 'node:crypto';
import fs from 'node:fs';
import express, { type NextFunction, type Request, type Response } from 'express';
import { z, ZodError } from 'zod';
import { config } from './config.ts';
import { pool, withTx } from './db.ts';
import { hashPassword, hashToken, newRefreshToken, rateLimit, requireAuth, signAccess, verifyPassword } from './auth.ts';
import { pushSchema } from './entities.ts';
import { exportAll, sync } from './sync.ts';

const credentials = z.object({
  email: z.string().trim().toLowerCase().email().max(200),
  password: z.string().min(8).max(200),
});
const registerSchema = credentials.extend({
  name: z.string().trim().max(100).default(''),
  signupCode: z.string().max(100).optional(),
});

interface UserRow {
  id: string;
  email: string;
  name: string;
  password_hash: string;
}

async function issueTokens(tx: import('./db.ts').Tx, user: UserRow, userAgent: string | undefined) {
  const refresh = newRefreshToken();
  await tx.query(
    `INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, user_agent)
     VALUES ($1, $2, $3, now() + ($4 || ' days')::interval, $5)`,
    [crypto.randomUUID(), user.id, hashToken(refresh), String(config.refreshTtlDays), userAgent?.slice(0, 300) ?? null],
  );
  return {
    user: { id: user.id, email: user.email, name: user.name },
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
  const authLimiter = rateLimit(20, 15 * 60 * 1000, (req) => `${byIp(req)}|${String(req.body?.email ?? '').toLowerCase()}`);

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
      const exists = await tx.query('SELECT 1 FROM users WHERE lower(email) = $1', [body.email]);
      if (exists.rowCount) return null;
      const user: UserRow = { id: crypto.randomUUID(), email: body.email, name: body.name, password_hash: passwordHash };
      await tx.query('INSERT INTO users (id, email, name, password_hash, last_login_at) VALUES ($1,$2,$3,$4, now())', [
        user.id, user.email, user.name, user.password_hash,
      ]);
      return issueTokens(tx, user, req.header('user-agent'));
    });
    if (!result) {
      res.status(409).json({ error: 'email_taken' });
      return;
    }
    res.status(201).json(result);
  });

  api.post('/auth/login', authLimiter, async (req, res) => {
    const body = credentials.parse(req.body);
    const result = await withTx(async (tx) => {
      const row = (await tx.query('SELECT id, email, name, password_hash FROM users WHERE lower(email) = $1', [body.email])).rows[0] as UserRow | undefined;
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
      const user = (await tx.query('SELECT id, email, name, password_hash FROM users WHERE id = $1', [row.user_id])).rows[0] as UserRow;
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
      (await tx.query('SELECT id, email, name, created_at FROM users WHERE id = $1', [req.userId])).rows[0],
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
      await tx.query('DELETE FROM users WHERE id = $1', [req.userId]);
      return true;
    });
    res.status(done ? 200 : 403).json(done ? { ok: true } : { error: 'invalid_credentials' });
  });

  api.post('/sync', requireAuth, async (req, res) => {
    const body = pushSchema.parse(req.body);
    const result = await withTx((tx) => sync(tx, req.userId!, body.cursor, body.changes as never));
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
