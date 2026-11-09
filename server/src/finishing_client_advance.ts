import type { Tx } from './db.ts';
import { commitFinishingPosting, postingPayloadHash } from './finishing_posting.ts';

export interface FinishingClientAdvance {
  eventId: string;
  projectId: string;
  accountId: string;
  trustCategoryId: string;
  amountPiasters: number;
  occurredOn: string;
}

export function validateClientAdvance(input: FinishingClientAdvance): void {
  if (!/^[a-zA-Z0-9_-]{1,100}$/.test(input.eventId) ||
      !input.projectId.trim() || !input.accountId.trim() || !input.trustCategoryId.trim()) {
    throw new Error('invalid advance identity');
  }
  if (!Number.isSafeInteger(input.amountPiasters) ||
      input.amountPiasters <= 0 || input.amountPiasters > 100_000_000_000) {
    throw new Error('invalid advance amount');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input.occurredOn) ||
      !Number.isFinite(Date.parse(input.occurredOn + 'T00:00:00Z')) ||
      new Date(input.occurredOn + 'T00:00:00Z').toISOString().slice(0, 10) !== input.occurredOn) {
    throw new Error('invalid advance date');
  }
}

/**
 * Call from withTx with the authenticated user ID. The ledger movement, account
 * receipt and idempotency marker share one PostgreSQL transaction.
 * Not exposed as API until project ownership/authorization is implemented.
 */
export async function postFinishingClientAdvance(
  tx: Tx,
  userId: string,
  input: FinishingClientAdvance,
): Promise<'posted' | 'already_committed'> {
  validateClientAdvance(input);
  return commitFinishingPosting(
    tx, userId, input.eventId, postingPayloadHash({ kind: 'client_advance', ...input }),
    async (t) => {
      const account = await t.query(
        'SELECT 1 FROM accounts WHERE user_id=$1 AND id=$2 AND is_active=true AND deleted_at IS NULL FOR UPDATE',
        [userId, input.accountId],
      );
      if (account.rowCount !== 1) throw new Error('account unavailable');
      const category = await t.query(
        "SELECT 1 FROM categories WHERE user_id=$1 AND id=$2 AND type='trust' AND deleted_at IS NULL",
        [userId, input.trustCategoryId],
      );
      if (category.rowCount !== 1) throw new Error('trust category unavailable');
      // Project row must already exist; project creation/ownership API is a separate prerequisite.
      const balance = await t.query(
        `SELECT 1 FROM finishing_project_balances WHERE user_id=$1 AND project_id=$2 FOR UPDATE`,
        [userId, input.projectId],
      );
      if (balance.rowCount !== 1) throw new Error('project balance not initialized');
      const movement = await t.query(
        `INSERT INTO finishing_project_movements
         (user_id,event_id,project_id,kind,amount_piasters)
         VALUES ($1,$2,$3,'client_advance',$4) ON CONFLICT (user_id,event_id) DO NOTHING`,
        [userId, input.eventId, input.projectId, input.amountPiasters],
      );
      if (movement.rowCount !== 1) throw new Error('duplicate project movement');
      const updated = await t.query(
        `UPDATE finishing_project_balances SET custody_piasters=custody_piasters+$3,updated_at=now()
         WHERE user_id=$1 AND project_id=$2`,
        [userId, input.projectId, input.amountPiasters],
      );
      if (updated.rowCount !== 1) throw new Error('project balance update failed');
      const cash = await t.query(
        `INSERT INTO transactions
         (user_id,id,amount,type,category_id,payment_method_type,date,note,
          created_at,updated_at,account_id)
         VALUES ($1,$2,$3,'trustIn',$4,'cash',$5,$6,now(),now(),$7)
         ON CONFLICT (user_id,id) DO NOTHING`,
        [userId, `finishing:${input.eventId}:advance`,
          (input.amountPiasters / 100).toFixed(2), input.trustCategoryId,
          input.occurredOn, `Finishing client advance ${input.eventId}`, input.accountId],
      );
      if (cash.rowCount !== 1) throw new Error('advance cash transaction collision');
    },
  );
}
