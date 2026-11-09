import type { Tx } from './db.ts';

export interface FinishingClosureResult {
  status: 'closed' | 'already_closed';
  closedAt: string;
}

/**
 * Must run inside withTx with the authenticated user ID.
 * The same project balance row is locked by every posting path.
 * This checks server-tracked reservations only; offline client events are
 * not visible and must be synced/reconciled before exposing closure in UI.
 */
export async function closeFinishingProject(
  tx: Tx, userId: string, projectId: string,
): Promise<FinishingClosureResult> {
  if (!userId.trim() || !projectId.trim()) throw new Error('missing closure identity');
  const result = await tx.query(
    `SELECT financial_status,closed_at,custody_piasters,receivable_piasters
     FROM finishing_project_balances
     WHERE user_id=$1 AND project_id=$2 FOR UPDATE`,
    [userId, projectId],
  );
  if (result.rowCount !== 1) throw new Error('project not found');
  const row = result.rows[0] as {
    financial_status: string; closed_at: Date | string | null;
    custody_piasters: number | string; receivable_piasters: number | string;
  };
  if (row.financial_status === 'closed') {
    if (!row.closed_at) throw new Error('invalid closure state');
    return { status: 'already_closed', closedAt: new Date(row.closed_at).toISOString() };
  }
  if (Number(row.custody_piasters) !== 0 || Number(row.receivable_piasters) !== 0) {
    throw new Error('outstanding custody or personal receivable');
  }
  const pending = await tx.query(
    `SELECT 1 FROM finishing_posting_requests
     WHERE user_id=$1 AND project_id=$2 AND state='reserved' LIMIT 1`,
    [userId, projectId],
  );
  if (pending.rowCount) throw new Error('pending project posting');
  const unknown = await tx.query(
    `SELECT 1 FROM finishing_posting_requests
     WHERE user_id=$1 AND project_id IS NULL AND state='reserved' LIMIT 1`,
    [userId],
  );
  if (unknown.rowCount) throw new Error('unscoped pending posting requires reconciliation');
  const updated = await tx.query(
    `UPDATE finishing_project_balances
     SET financial_status='closed',closed_at=now(),updated_at=now()
     WHERE user_id=$1 AND project_id=$2 AND financial_status='open'
     RETURNING closed_at`,
    [userId, projectId],
  );
  if (updated.rowCount !== 1) throw new Error('closure update failed');
  return { status: 'closed', closedAt: new Date(updated.rows[0].closed_at).toISOString() };
}
