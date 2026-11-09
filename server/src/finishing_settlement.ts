import type { Tx } from './db.ts';
import { commitFinishingPosting, postingPayloadHash } from './finishing_posting.ts';

export type FinishingSettlementKind =
  | 'reimburse_from_custody'
  | 'client_repay_personal'
  | 'return_custody';

export interface FinishingSettlement {
  eventId: string;
  projectId: string;
  kind: FinishingSettlementKind;
  amountPiasters: number;
  // Required for physical money movement; not used for an internal reclassification.
  accountId?: string;
  categoryId?: string;
  occurredOn: string;
}

export function validateFinishingSettlement(input: FinishingSettlement): void {
  if (!/^[a-zA-Z0-9_-]{1,100}$/.test(input.eventId) || !input.projectId.trim()) {
    throw new Error('invalid settlement identity');
  }
  if (!['reimburse_from_custody', 'client_repay_personal', 'return_custody'].includes(input.kind)) {
    throw new Error('invalid settlement kind');
  }
  if (!Number.isSafeInteger(input.amountPiasters) ||
      input.amountPiasters <= 0 || input.amountPiasters > 100_000_000_000) {
    throw new Error('invalid settlement amount');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input.occurredOn) ||
      !Number.isFinite(Date.parse(input.occurredOn + 'T00:00:00Z')) ||
      new Date(input.occurredOn + 'T00:00:00Z').toISOString().slice(0, 10) !== input.occurredOn) {
    throw new Error('invalid settlement date');
  }
  if (input.kind !== 'reimburse_from_custody' &&
      (!input.accountId?.trim() || !input.categoryId?.trim())) {
    throw new Error('account and category required for cash settlement');
  }
  if (input.kind === 'reimburse_from_custody' && (input.accountId || input.categoryId)) {
    throw new Error('internal reimbursement cannot specify a cash leg');
  }
}

/**
 * Call inside withTx with authenticated userId. The project ledger and any
 * account transaction must commit with the idempotency marker.
 *
 * Internal reimbursement reclassifies custody to personal receivable; no
 * account movement occurs because funds already reside in the same account.
 * This is not a transfer between distinct bank accounts.
 */
export async function postFinishingSettlement(
  tx: Tx, userId: string, input: FinishingSettlement,
): Promise<'posted' | 'already_committed'> {
  validateFinishingSettlement(input);
  return commitFinishingPosting(
    tx, userId, input.eventId, postingPayloadHash({ settlement: input }),
    async (t) => {
      const balanceResult = await t.query(
        `SELECT custody_piasters,receivable_piasters FROM finishing_project_balances
         WHERE user_id=$1 AND project_id=$2 AND financial_status='open' FOR UPDATE`,
        [userId, input.projectId],
      );
      if (balanceResult.rowCount !== 1) throw new Error('project balance not initialized');
      const balance = balanceResult.rows[0] as {
        custody_piasters: string | number; receivable_piasters: string | number;
      };
      const custody = Number(balance.custody_piasters);
      const receivable = Number(balance.receivable_piasters);
      if (![custody, receivable].every(Number.isSafeInteger)) throw new Error('invalid stored balance');
      if (input.kind !== 'client_repay_personal' && custody < input.amountPiasters) {
        throw new Error('insufficient custody');
      }
      if (input.kind !== 'return_custody' && receivable < input.amountPiasters) {
        throw new Error('settlement exceeds personal receivable');
      }

      if (input.kind !== 'reimburse_from_custody') {
        const account = await t.query(
          'SELECT 1 FROM accounts WHERE user_id=$1 AND id=$2 AND is_active=true AND deleted_at IS NULL FOR UPDATE',
          [userId, input.accountId],
        );
        if (account.rowCount !== 1) throw new Error('account unavailable');
        const category = await t.query(
          "SELECT 1 FROM categories WHERE user_id=$1 AND id=$2 AND type='trust' AND deleted_at IS NULL",
          [userId, input.categoryId],
        );
        if (category.rowCount !== 1) throw new Error('trust category unavailable');
      }

      const movement = await t.query(
        `INSERT INTO finishing_project_movements
         (user_id,event_id,project_id,kind,amount_piasters)
         VALUES ($1,$2,$3,$4,$5) ON CONFLICT (user_id,event_id) DO NOTHING`,
        [userId, input.eventId, input.projectId, input.kind, input.amountPiasters],
      );
      if (movement.rowCount !== 1) throw new Error('duplicate settlement movement');

      const custodyDelta = input.kind === 'client_repay_personal' ? 0 : -input.amountPiasters;
      const receivableDelta = input.kind === 'return_custody' ? 0 : -input.amountPiasters;
      const updated = await t.query(
        `UPDATE finishing_project_balances
         SET custody_piasters=custody_piasters+$3,
             receivable_piasters=receivable_piasters+$4,
             updated_at=now()
         WHERE user_id=$1 AND project_id=$2
           AND custody_piasters+$3 >= 0 AND receivable_piasters+$4 >= 0`,
        [userId, input.projectId, custodyDelta, receivableDelta],
      );
      if (updated.rowCount !== 1) throw new Error('settlement balance update failed');

      // Client repayment: incoming cash. Return of custody: outgoing cash.
      // Both use trust categories so neither counts as personal income/expense.
      if (input.kind !== 'reimburse_from_custody') {
        const transactionType = input.kind === 'client_repay_personal' ? 'trustIn' : 'trustOut';
        const cash = await t.query(
          `INSERT INTO transactions
           (user_id,id,amount,type,category_id,payment_method_type,date,note,
            created_at,updated_at,account_id)
           VALUES ($1,$2,$3,$4,$5,'cash',$6,$7,now(),now(),$8)
           ON CONFLICT (user_id,id) DO NOTHING`,
          [userId, `finishing:${input.eventId}:settlement`,
            (input.amountPiasters / 100).toFixed(2), transactionType,
            input.categoryId, input.occurredOn, `Finishing ${input.kind} ${input.eventId}`,
            input.accountId],
        );
        if (cash.rowCount !== 1) throw new Error('settlement cash transaction collision');
      }
    },
    input.projectId,
  );
}
