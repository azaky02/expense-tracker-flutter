import { ENTITIES, type Entity } from './entities.ts';
import type { Tx } from './db.ts';

const PAGE = 1000;
// A client clock running ahead must not win every future conflict.
const MAX_FUTURE_MS = 5 * 60 * 1000;

type Rec = Record<string, unknown>;

function clampTs(iso: string): string {
  const t = Date.parse(iso);
  return new Date(Math.min(t, Date.now() + MAX_FUTURE_MS)).toISOString();
}

/** Insert or update one record; last-writer-wins on updatedAt (older/equal writes are ignored). */
async function upsert(tx: Tx, userId: string, e: Entity, r: Rec): Promise<boolean> {
  const isTombstone = !!r.deletedAt && e.cols.some((c) => !c.nullable && r[c.api] === undefined);
  if (isTombstone) {
    // Only marks an existing row deleted; a delete for a row the server never saw is a no-op.
    const keyWhere = e.keys.map((c, i) => `${c.db} = $${i + 3}`).join(' AND ');
    const res = await tx.query(
      `UPDATE ${e.table} SET deleted_at = $2, updated_at = $2, seq = nextval('change_seq')
       WHERE user_id = $1 AND ${keyWhere} AND updated_at < $2`,
      [userId, clampTs(r.deletedAt as string), ...e.keys.map((c) => r[c.api])],
    );
    return (res.rowCount ?? 0) > 0;
  }
  const cols = [...e.keys, ...e.cols];
  const names = ['user_id', ...cols.map((c) => c.db), 'updated_at', 'deleted_at', 'seq'];
  const vals: unknown[] = [
    userId,
    ...cols.map((c) => (r[c.api] === undefined ? null : r[c.api])),
    clampTs(r.updatedAt as string),
    r.deletedAt ? clampTs(r.deletedAt as string) : null,
  ];
  const placeholders = vals.map((_, i) => `$${i + 1}`).concat("nextval('change_seq')");
  const keyCols = ['user_id', ...e.keys.map((c) => c.db)];
  const setCols = [...e.cols.map((c) => c.db), 'updated_at', 'deleted_at'];
  const sql = `INSERT INTO ${e.table} (${names.join(',')}) VALUES (${placeholders.join(',')})
    ON CONFLICT (${keyCols.join(',')}) DO UPDATE
      SET ${setCols.map((c) => `${c} = EXCLUDED.${c}`).join(', ')}, seq = nextval('change_seq')
      WHERE ${e.table}.updated_at < EXCLUDED.updated_at`;
  const res = await tx.query(sql, vals);
  return (res.rowCount ?? 0) > 0;
}

function toApi(e: Entity, row: Rec): Rec {
  const out: Rec = {};
  for (const c of [...e.keys, ...e.cols]) {
    let v = row[c.db];
    if (v instanceof Date) v = v.toISOString();
    out[c.api] = v ?? null;
  }
  out.updatedAt = (row.updated_at as Date).toISOString();
  out.deletedAt = row.deleted_at ? (row.deleted_at as Date).toISOString() : null;
  return out;
}

const maxSeqSql = () => ENTITIES.map((e) => `SELECT max(seq) AS m FROM ${e.table} WHERE user_id = $1`).join(' UNION ALL ');

export interface SyncResult {
  applied: Record<string, number>;
  cursor: number;
  hasMore: boolean;
  changes: Record<string, Rec[]>;
}

/**
 * One round trip: apply the client's changes (last-writer-wins on updatedAt), then return everything
 * that changed on the server after `cursor`. A per-user advisory lock serialises a user's syncs so the
 * seq cursor can never skip a row that commits late.
 */
export async function sync(
  tx: Tx,
  userId: string,
  cursor: number,
  changes: Record<string, Rec[] | undefined>,
): Promise<SyncResult> {
  await tx.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 77))', [userId]);

  const before = (await tx.query(`SELECT coalesce(max(m), 0) AS m FROM (${maxSeqSql()}) s`, [userId])).rows[0].m as number;
  // Our own writes below get seq values above this mark, so (cursor, mark] is other devices' history only.
  const mark = Math.max(before, cursor);

  const applied: Record<string, number> = {};
  for (const e of ENTITIES) {
    let n = 0;
    for (const r of changes[e.name] ?? []) if (await upsert(tx, userId, e, r)) n++;
    applied[e.name] = n;
  }

  const union = ENTITIES.map(
    (e) => `SELECT '${e.name}' AS entity, seq FROM ${e.table} WHERE user_id = $1 AND seq > $2 AND seq <= $3`,
  ).join(' UNION ALL ');
  const page = (
    await tx.query(`SELECT entity, seq FROM (${union}) u ORDER BY seq LIMIT ${PAGE + 1}`, [userId, cursor, mark])
  ).rows as { entity: string; seq: number }[];
  const hasMore = page.length > PAGE;
  const slice = hasMore ? page.slice(0, PAGE) : page;

  let newCursor = cursor;
  const out: Record<string, Rec[]> = {};
  if (slice.length) {
    newCursor = slice[slice.length - 1].seq;
    const used = new Set(slice.map((s) => s.entity));
    for (const e of ENTITIES) {
      if (!used.has(e.name)) continue;
      const rows = (
        await tx.query(`SELECT * FROM ${e.table} WHERE user_id = $1 AND seq > $2 AND seq <= $3 ORDER BY seq`, [userId, cursor, newCursor])
      ).rows;
      out[e.name] = rows.map((r) => toApi(e, r));
    }
  }
  if (!hasMore) {
    // Caught up: skip past this request's own writes too, so they are not echoed back next time.
    const after = (await tx.query(`SELECT coalesce(max(m), 0) AS m FROM (${maxSeqSql()}) s`, [userId])).rows[0].m as number;
    newCursor = Math.max(newCursor, after);
  }
  return { applied, cursor: newCursor, hasMore, changes: out };
}

export async function exportAll(tx: Tx, userId: string): Promise<Record<string, Rec[]>> {
  const out: Record<string, Rec[]> = {};
  for (const e of ENTITIES) {
    const rows = (await tx.query(`SELECT * FROM ${e.table} WHERE user_id = $1 AND deleted_at IS NULL ORDER BY seq`, [userId])).rows;
    out[e.name] = rows.map((r) => toApi(e, r));
  }
  return out;
}
