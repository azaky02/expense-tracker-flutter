import type { Tx } from './db.ts';

export interface FinishingProjectInitialization {
  projectId: string;
}

/**
 * Creates the zero-balance server ledger for a new project.
 * Call only from an authenticated, authorized project-creation transaction.
 * This is not a public API and does not create a client-facing project record.
 */
export async function initializeFinishingProjectBalance(
  tx: Tx,
  userId: string,
  input: FinishingProjectInitialization,
): Promise<'created' | 'already_exists'> {
  if (!userId.trim() || !/^[a-zA-Z0-9_-]{1,100}$/.test(input.projectId)) {
    throw new Error('invalid project identity');
  }
  const result = await tx.query(
    `INSERT INTO finishing_project_balances
      (user_id,project_id,custody_piasters,receivable_piasters,cost_piasters)
     VALUES ($1,$2,0,0,0) ON CONFLICT (user_id,project_id) DO NOTHING`,
    [userId, input.projectId],
  );
  if (result.rowCount === 1) return 'created';
  const existing = await tx.query(
    'SELECT 1 FROM finishing_project_balances WHERE user_id=$1 AND project_id=$2',
    [userId, input.projectId],
  );
  if (existing.rowCount !== 1) throw new Error('project initialization conflict');
  return 'already_exists';
}
