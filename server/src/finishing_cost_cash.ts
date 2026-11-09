import type { Tx } from './db.ts';
import { commitFinishingPosting, postingPayloadHash } from './finishing_posting.ts';
import { applyFinishingCostToLedger } from './finishing_project_ledger.ts';

export interface FinishingCostPost {
  eventId: string;
  projectId: string;
  accountId: string;
  custodyCategoryId: string;
  expenseCategoryId: string;
  custodyPiasters: number;
  personalPiasters: number;
  occurredOn: string;
}

function assertPiasters(value: number) {
  if (!Number.isSafeInteger(value) || value < 0 || value > 100_000_000_000) {
    throw new Error('invalid integer piasters');
  }
}

/**
 * Server-owned cash posting. Call ONLY through withTx, with the authenticated
 * user id. This is not an HTTP endpoint and must not accept arbitrary user ids.
 *
 * This writes two uniquely keyed account transactions and a commit marker in
 * the same PostgreSQL transaction. Project custody/receivable reconciliation
 * and authoritative project event validation are NOT implemented yet.
 */
export async function postFinishingCostCash(
  tx: Tx,
  userId: string,
  input: FinishingCostPost,
): Promise<'posted' | 'already_committed'> {
  for (const value of [input.custodyPiasters, input.personalPiasters]) assertPiasters(value);
  const total = input.custodyPiasters + input.personalPiasters;
  if (!Number.isSafeInteger(total) || total <= 0) throw new Error('empty or excessive cost');
  if (!/^[a-zA-Z0-9_-]{1,100}$/.test(input.eventId) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(input.occurredOn) ||
      !Number.isFinite(Date.parse(input.occurredOn + 'T00:00:00Z'))) {
    throw new Error('invalid event id or date');
  }
  const hash = postingPayloadHash(input);
  return commitFinishingPosting(tx, userId, input.eventId, hash, async (t) => {
    const account = await t.query(
      'SELECT 1 FROM accounts WHERE user_id=$1 AND id=$2 AND is_active=true AND deleted_at IS NULL FOR UPDATE',
      [userId, input.accountId],
    );
    if (account.rowCount !== 1) throw new Error('account unavailable');
    const categories = await t.query(
      'SELECT id,type FROM categories WHERE user_id=$1 AND id=ANY($2::text[]) AND deleted_at IS NULL',
      [userId, [input.custodyCategoryId, input.expenseCategoryId]],
    );
    const types = new Map<string, string>(
      (categories.rows as { id: string; type: string }[]).map((r) => [r.id, r.type]),
    );
    if (types.get(input.custodyCategoryId) !== 'trust' ||
        types.get(input.expenseCategoryId) !== 'expense') {
      throw new Error('category mismatch');
    }
    await applyFinishingCostToLedger(t, userId, {
      projectId: input.projectId,
      eventId: input.eventId,
      custodyPiasters: input.custodyPiasters,
      personalPiasters: input.personalPiasters,
    });
    for (const leg of [
      { suffix: 'custody', amount: input.custodyPiasters, type: 'trustOut', category: input.custodyCategoryId },
      { suffix: 'personal', amount: input.personalPiasters, type: 'expense', category: input.expenseCategoryId },
    ]) {
      if (leg.amount === 0) continue;
      const id = `finishing:${input.eventId}:${leg.suffix}`;
      const result = await t.query(
        `INSERT INTO transactions
         (user_id,id,amount,type,category_id,payment_method_type,date,note,
          created_at,updated_at,account_id)
         VALUES ($1,$2,$3,$4,$5,'cash',$6,$7,now(),now(),$8)
         ON CONFLICT (user_id,id) DO NOTHING`,
        [userId, id, (leg.amount / 100).toFixed(2), leg.type, leg.category,
          input.occurredOn, `Finishing cost ${input.eventId}`, input.accountId],
      );
      if (result.rowCount !== 1) throw new Error('cash leg id collision');
    }
  }, input.projectId);
}
