import { createHash } from 'node:crypto';
import type { Tx } from './db.ts';

export type PostingReservation = 'reserved' | 'already_reserved' | 'already_committed';

export function postingPayloadHash(payload: unknown): string {
  return createHash('sha256').update(JSON.stringify(payload)).digest('hex');
}

/**
 * Must be called inside withTx with an authenticated userId.
 * This only reserves an immutable identity; it DOES NOT move money or
 * mark an event posted. Never expose it as successful posting.
 */
export async function reserveFinishingPosting(
  tx: Tx,
  userId: string,
  eventId: string,
  payloadHash: string,
): Promise<PostingReservation> {
  if (!userId.trim() || !eventId.trim() || !/^[a-f0-9]{64}$/.test(payloadHash)) {
    throw new Error('invalid posting reservation');
  }
  const inserted = await tx.query(
    `INSERT INTO finishing_posting_requests (user_id,event_id,payload_hash)
     VALUES ($1,$2,$3) ON CONFLICT (user_id,event_id) DO NOTHING`,
    [userId, eventId, payloadHash],
  );
  // Locks the row until the caller's transaction commits; serialises concurrent retries.
  const row = (await tx.query(
    `SELECT payload_hash,state FROM finishing_posting_requests
     WHERE user_id=$1 AND event_id=$2 FOR UPDATE`,
    [userId, eventId],
  )).rows[0] as { payload_hash: string; state: string } | undefined;
  if (!row) throw new Error('posting reservation missing');
  if (row.payload_hash !== payloadHash) {
    throw new Error('posting event id reused with different payload');
  }
  if (row.state === 'committed') return 'already_committed';
  // A reserved row may be retried; actual posting requires separate atomic server logic.
  return (inserted.rowCount ?? 0) > 0 ? 'reserved' : 'already_reserved';
}


/**
 * Transaction-scoped posting coordinator. Caller MUST invoke this from withTx,
 * and postCashMovements MUST write authoritative, uniquely keyed cash rows
 * using this same tx. Never call external services from the callback.
 *
 * A successful callback and committed marker are committed together by withTx.
 * If callback or marker fails, withTx rolls both back.
 */
export async function commitFinishingPosting(
  tx: Tx,
  userId: string,
  eventId: string,
  payloadHash: string,
  postCashMovements: (tx: Tx) => Promise<void>,
): Promise<'posted' | 'already_committed'> {
  const reservation = await reserveFinishingPosting(tx, userId, eventId, payloadHash);
  if (reservation === 'already_committed') return 'already_committed';

  await postCashMovements(tx);
  const result = await tx.query(
    `UPDATE finishing_posting_requests
     SET state='committed', committed_at=now()
     WHERE user_id=$1 AND event_id=$2 AND payload_hash=$3 AND state='reserved'`,
    [userId, eventId, payloadHash],
  );
  if (result.rowCount !== 1) throw new Error('posting commit marker failed');
  return 'posted';
}
