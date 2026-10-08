import crypto from 'node:crypto';
import { z } from 'zod';
import type { Tx } from './db.ts';
import { normalizePhone } from './phone.ts';

/**
 * Shared Ledger. One server-side entry per financial event between two parties; each party sees it
 * from its own side. Entries with another registered user start PENDING and only count once that
 * user CONFIRMS; entries with a person who has no account are the creator's own record and are
 * CONFIRMED straight away. Nothing is ever overwritten: changes are status transitions + audit rows.
 */

const ymd = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((s) => !Number.isNaN(Date.parse(s + 'T00:00:00Z')), 'invalid date');
const entryId = z.string().min(8).max(64);

export const ledgerOpSchema = z.discriminatedUnion('op', [
  z.object({
    op: z.literal('create'),
    id: entryId,
    kind: z.enum(['LOAN', 'ADVANCE', 'SETTLEMENT', 'OTHER']),
    direction: z.enum(['GAVE', 'RECEIVED']),
    amount: z.number().positive().max(1e11),
    currency: z.string().regex(/^[A-Z]{3}$/).default('EGP'),
    date: ymd,
    description: z.string().max(2000).nullable().optional(),
    personId: z.string().max(64).nullable().optional(),
    counterpartEmail: z.string().trim().toLowerCase().email().max(200).nullable().optional(),
    counterpartPhone: z.string().max(30).transform(normalizePhone).nullable().optional(),
    counterpartName: z.string().trim().max(200).nullable().optional(),
    settlesEntryId: entryId.nullable().optional(),
    paymentMethod: z.enum(['cash', 'bank', 'transfer', 'other']).nullable().optional(),
  }),
  z.object({ op: z.literal('confirm'), id: entryId }),
  z.object({ op: z.literal('reject'), id: entryId, reason: z.string().max(500).nullable().optional() }),
  z.object({ op: z.literal('cancel'), id: entryId }),
]);
export type LedgerOp = z.infer<typeof ledgerOpSchema>;

export interface OpResult {
  id: string;
  op: string;
  ok: boolean;
  status?: string;
  error?: string;
}

const PAGE = 500;
const flip = (d: string) => (d === 'GAVE' ? 'RECEIVED' : 'GAVE');

async function audit(tx: Tx, actor: string, entryId: string, action: string, payload: unknown = null) {
  await tx.query(
    'INSERT INTO audit_logs (actor_user_id, entity_type, entity_id, action, payload) VALUES ($1, $2, $3, $4, $5)',
    [actor, 'ledger_entry', entryId, action, payload === null ? null : JSON.stringify(payload)],
  );
}

async function notify(tx: Tx, userId: string, type: string, entry: { id: string; amount: number; currency: string }, actorName: string) {
  await tx.query(
    `INSERT INTO notifications (id, user_id, type, entry_id, actor_name, amount, currency) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [crypto.randomUUID(), userId, type, entry.id, actorName, entry.amount, entry.currency],
  );
}

async function displayName(tx: Tx, userId: string): Promise<string> {
  const u = (await tx.query('SELECT name, email, phone FROM users WHERE id = $1', [userId])).rows[0];
  return u ? (u.name || u.email || u.phone || '') : '';
}

/** The registered user an entry is shared with: by e-mail first, otherwise by mobile number. */
async function findCounterpart(tx: Tx, email?: string | null, phone?: string | null): Promise<{ id: string } | undefined> {
  if (email) {
    const u = (await tx.query('SELECT id FROM users WHERE lower(email) = $1', [email])).rows[0];
    if (u) return u;
  }
  if (phone) return (await tx.query('SELECT id FROM users WHERE phone = $1', [phone])).rows[0];
  return undefined;
}

/** Other registered users an op will touch – their locks are taken (in a fixed order) before any writes. */
export async function usersTouchedBy(tx: Tx, userId: string, ops: LedgerOp[]): Promise<string[]> {
  const ids = new Set<string>();
  for (const op of ops) {
    if (op.op === 'create') {
      const u = await findCounterpart(tx, op.counterpartEmail, op.counterpartPhone);
      if (u && u.id !== userId) ids.add(u.id);
    } else {
      const rows = (await tx.query('SELECT user_id FROM ledger_participants WHERE entry_id = $1 AND user_id IS NOT NULL', [op.id])).rows;
      for (const r of rows) if (r.user_id !== userId) ids.add(r.user_id);
    }
  }
  return [...ids];
}

export async function applyOp(tx: Tx, userId: string, op: LedgerOp): Promise<OpResult> {
  const base = { id: op.id, op: op.op };
  if (op.op === 'create') {
    const existing = (await tx.query('SELECT created_by, status FROM ledger_entries WHERE id = $1 FOR UPDATE', [op.id])).rows[0];
    if (existing) {
      // Same request sent twice (double tap, retry after a timeout): return the original result.
      return existing.created_by === userId ? { ...base, ok: true, status: existing.status } : { ...base, ok: false, error: 'id_taken' };
    }
    const other = await findCounterpart(tx, op.counterpartEmail, op.counterpartPhone);
    if (other?.id === userId) return { ...base, ok: false, error: 'self_counterparty' };
    if (op.settlesEntryId) {
      const ok = (await tx.query('SELECT 1 FROM ledger_participants WHERE entry_id = $1 AND user_id = $2', [op.settlesEntryId, userId])).rowCount;
      if (!ok) return { ...base, ok: false, error: 'settles_not_found' };
    }
    const status = other ? 'PENDING' : 'CONFIRMED';
    await tx.query(
      `INSERT INTO ledger_entries (id, kind, amount, currency, entry_date, description, status, settles_entry_id, created_by, confirmed_at, payment_method)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9, CASE WHEN $7 = 'CONFIRMED' THEN now() END, $10)`,
      [op.id, op.kind, op.amount, op.currency, op.date, op.description ?? null, status, op.settlesEntryId ?? null, userId, op.paymentMethod ?? null],
    );
    await tx.query(
      `INSERT INTO ledger_participants (entry_id, seat, role, user_id, person_id, display_name, direction)
       VALUES ($1, 1, 'CREATOR', $2, $3, NULL, $4), ($1, 2, 'COUNTERPARTY', $5, NULL, $6, $7)`,
      [op.id, userId, op.personId ?? null, op.direction, other?.id ?? null, op.counterpartName ?? op.counterpartEmail ?? op.counterpartPhone ?? null, flip(op.direction)],
    );
    await audit(tx, userId, op.id, 'CREATE', { kind: op.kind, amount: op.amount, currency: op.currency, direction: op.direction, shared: !!other });
    if (other) {
      await notify(tx, other.id, op.kind === 'SETTLEMENT' ? 'SETTLEMENT_RECEIVED' : 'NEW_ENTRY',
        { id: op.id, amount: op.amount, currency: op.currency }, await displayName(tx, userId));
    }
    return { ...base, ok: true, status };
  }

  const entry = (await tx.query('SELECT id, status, created_by, amount, currency FROM ledger_entries WHERE id = $1 FOR UPDATE', [op.id])).rows[0];
  const parts = (await tx.query('SELECT seat, role, user_id FROM ledger_participants WHERE entry_id = $1', [op.id])).rows as { seat: number; role: string; user_id: string | null }[];
  const mine = parts.find((p) => p.user_id === userId);
  if (!entry || !mine) return { ...base, ok: false, error: 'not_found' };
  const otherUser = parts.find((p) => p.user_id && p.user_id !== userId)?.user_id ?? null;
  const ent = { id: entry.id as string, amount: entry.amount as number, currency: entry.currency as string };
  const setStatus = async (status: string, extra = '', params: unknown[] = []) => {
    await tx.query(
      `UPDATE ledger_entries SET status = $2, updated_at = now(), seq = nextval('ledger_seq')${extra} WHERE id = $1`,
      [op.id, status, ...params],
    );
  };

  if (op.op === 'confirm' || op.op === 'reject') {
    if (mine.role !== 'COUNTERPARTY') return { ...base, ok: false, error: 'not_allowed' };
    const target = op.op === 'confirm' ? 'CONFIRMED' : 'REJECTED';
    if (entry.status === target) return { ...base, ok: true, status: target };
    if (entry.status !== 'PENDING') return { ...base, ok: false, error: 'invalid_state', status: entry.status };
    if (op.op === 'confirm') await setStatus('CONFIRMED', ', confirmed_at = now()');
    else await setStatus('REJECTED', ', reject_reason = $3', [op.reason ?? null]);
    await audit(tx, userId, op.id, target === 'CONFIRMED' ? 'CONFIRM' : 'REJECT', op.op === 'reject' ? { reason: op.reason ?? null } : null);
    if (entry.created_by) await notify(tx, entry.created_by, target, ent, await displayName(tx, userId));
    return { ...base, ok: true, status: target };
  }

  // cancel: the creator withdraws a pending entry, or voids their own one-sided record.
  if (mine.role !== 'CREATOR') return { ...base, ok: false, error: 'not_allowed' };
  if (entry.status === 'CANCELLED') return { ...base, ok: true, status: 'CANCELLED' };
  const allowed = entry.status === 'PENDING' || (entry.status === 'CONFIRMED' && !otherUser);
  if (!allowed) return { ...base, ok: false, error: 'invalid_state', status: entry.status };
  await setStatus('CANCELLED');
  await audit(tx, userId, op.id, 'CANCEL');
  if (otherUser) await notify(tx, otherUser, 'CANCELLED', ent, await displayName(tx, userId));
  return { ...base, ok: true, status: 'CANCELLED' };
}

type Row = Record<string, any>;

/** Entries the user takes part in that changed after `cursor`, from the user's own point of view. */
export async function ledgerFeed(tx: Tx, userId: string, cursor: number) {
  const rows = (
    await tx.query(
      `SELECT e.*, me.direction AS my_direction, me.person_id AS my_person_id, me.role AS my_role,
              o.user_id AS other_user_id, o.display_name AS other_display_name, ou.name AS other_name, ou.email AS other_email,
              ou.phone AS other_phone
         FROM ledger_entries e
         JOIN ledger_participants me ON me.entry_id = e.id AND me.user_id = $1
         LEFT JOIN ledger_participants o ON o.entry_id = e.id AND o.seat <> me.seat
         LEFT JOIN users ou ON ou.id = o.user_id
        WHERE e.seq > $2
        ORDER BY e.seq
        LIMIT ${PAGE + 1}`,
      [userId, cursor],
    )
  ).rows as Row[];
  const hasMore = rows.length > PAGE;
  const page = hasMore ? rows.slice(0, PAGE) : rows;
  return {
    hasMore,
    cursor: page.length ? (page[page.length - 1].seq as number) : cursor,
    entries: page.map((r) => ({
      id: r.id,
      kind: r.kind,
      amount: r.amount,
      currency: (r.currency as string).trim(),
      date: r.entry_date,
      description: r.description,
      status: r.status,
      rejectReason: r.reject_reason,
      settlesEntryId: r.settles_entry_id,
      paymentMethod: r.payment_method,
      createdByMe: r.my_role === 'CREATOR',
      direction: r.my_direction,
      personId: r.my_person_id,
      counterparty: {
        userId: r.other_user_id,
        name: r.other_name || r.other_display_name || r.other_email || r.other_phone || '',
        email: r.other_email,
        phone: r.other_phone,
      },
      createdAt: (r.created_at as Date).toISOString(),
      updatedAt: (r.updated_at as Date).toISOString(),
    })),
  };
}

export async function notificationFeed(tx: Tx, userId: string, cursor: number) {
  const rows = (
    await tx.query(`SELECT * FROM notifications WHERE user_id = $1 AND seq > $2 ORDER BY seq LIMIT ${PAGE + 1}`, [userId, cursor])
  ).rows as Row[];
  const hasMore = rows.length > PAGE;
  const page = hasMore ? rows.slice(0, PAGE) : rows;
  return {
    hasMore,
    cursor: page.length ? (page[page.length - 1].seq as number) : cursor,
    items: page.map((r) => ({
      id: r.id,
      type: r.type,
      entryId: r.entry_id,
      actorName: r.actor_name,
      amount: r.amount,
      currency: r.currency ? (r.currency as string).trim() : null,
      createdAt: (r.created_at as Date).toISOString(),
      readAt: r.read_at ? (r.read_at as Date).toISOString() : null,
    })),
  };
}

export async function markNotificationsRead(tx: Tx, userId: string, ids: string[]) {
  if (!ids.length) return;
  await tx.query(
    `UPDATE notifications SET read_at = now(), seq = nextval('ledger_seq')
      WHERE user_id = $1 AND id = ANY($2::uuid[]) AND read_at IS NULL`,
    [userId, ids],
  );
}

/**
 * Before an account is deleted: entries only this user can see go away; shared ones stay for the
 * other party, with this user's name kept as plain text.
 */
export async function detachUserFromLedger(tx: Tx, userId: string) {
  await tx.query(
    `DELETE FROM ledger_entries e
      WHERE EXISTS (SELECT 1 FROM ledger_participants p WHERE p.entry_id = e.id AND p.user_id = $1)
        AND NOT EXISTS (SELECT 1 FROM ledger_participants p WHERE p.entry_id = e.id AND p.user_id IS NOT NULL AND p.user_id <> $1)`,
    [userId],
  );
  await tx.query(
    `UPDATE ledger_participants p SET display_name = coalesce(nullif(u.name, ''), u.email, u.phone), person_id = NULL
       FROM users u WHERE u.id = p.user_id AND p.user_id = $1`,
    [userId],
  );
}
