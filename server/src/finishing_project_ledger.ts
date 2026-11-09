import type { Tx } from './db.ts';

export interface FinishingCostAllocation {
  projectId: string;
  eventId: string;
  custodyPiasters: number;
  personalPiasters: number;
}

export function validateFinishingCostAllocation(input: FinishingCostAllocation): number {
  if (!input.projectId.trim() || !input.eventId.trim()) throw new Error('missing identity');
  const { custodyPiasters: custody, personalPiasters: personal } = input;
  if (![custody, personal].every((n) => Number.isSafeInteger(n) && n >= 0)) {
    throw new Error('invalid cost allocation');
  }
  const total = custody + personal;
  if (!Number.isSafeInteger(total) || total <= 0) throw new Error('invalid cost total');
  return total;
}

/**
 * Atomic balance mutation, called inside the SAME withTx as account cash posting.
 * The project balance row is locked to serialize concurrent spending.
 * An event ID is unique per user, including across different projects.
 *
 * Do not call independently of cash posting: a failed cash write must roll back
 * both this movement and the account transaction.
 */
export async function applyFinishingCostToLedger(
  tx: Tx,
  userId: string,
  input: FinishingCostAllocation,
): Promise<void> {
  const total = validateFinishingCostAllocation(input);
  const balance = await tx.query(
    `SELECT custody_piasters FROM finishing_project_balances
     WHERE user_id=$1 AND project_id=$2 AND financial_status='open' FOR UPDATE`,
    [userId, input.projectId],
  );
  if (balance.rowCount !== 1) throw new Error('project balance not initialized');
  const custody = Number(balance.rows[0].custody_piasters);
  if (!Number.isSafeInteger(custody) || custody < input.custodyPiasters) {
    throw new Error('insufficient project custody');
  }
  const movement = await tx.query(
    `INSERT INTO finishing_project_movements
      (user_id,event_id,project_id,kind,amount_piasters,custody_share_piasters,personal_share_piasters)
     VALUES ($1,$2,$3,'cost',$4,$5,$6) ON CONFLICT (user_id,event_id) DO NOTHING`,
    [userId, input.eventId, input.projectId, total, input.custodyPiasters, input.personalPiasters],
  );
  if (movement.rowCount !== 1) throw new Error('duplicate project movement');
  const updated = await tx.query(
    `UPDATE finishing_project_balances
     SET custody_piasters=custody_piasters-$3,
         receivable_piasters=receivable_piasters+$4,
         cost_piasters=cost_piasters+$5,
         updated_at=now()
     WHERE user_id=$1 AND project_id=$2 AND custody_piasters >= $3`,
    [userId, input.projectId, input.custodyPiasters, input.personalPiasters, total],
  );
  if (updated.rowCount !== 1) throw new Error('project custody changed');
}
