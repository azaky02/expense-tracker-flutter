import type { Tx } from './db.ts';
import { initializeFinishingProjectBalance } from './finishing_project_initialization.ts';

export interface NewFinishingProject {
  projectId: string;
  clientName: string;
  projectName: string;
  description?: string;
}
export function validateNewFinishingProject(input: NewFinishingProject): void {
  if (!/^[A-Za-z0-9_-]{1,100}$/.test(input.projectId)) throw new Error('invalid project id');
  if (![input.clientName,input.projectName].every((v) => typeof v === 'string' && v.trim().length > 0 && v.trim().length <= 150)) {
    throw new Error('invalid project or client name');
  }
  if (input.description !== undefined && (typeof input.description !== 'string' || input.description.length > 2000)) {
    throw new Error('invalid project description');
  }
}

/** Must be called inside withTx using req.userId from requireAuth, never a client-supplied userId. */
export async function createFinishingProject(
  tx: Tx, userId: string, input: NewFinishingProject,
): Promise<'created' | 'already_exists'> {
  validateNewFinishingProject(input);
  const clientName = input.clientName.trim();
  const projectName = input.projectName.trim();
  const description = input.description?.trim() ?? '';
  await initializeFinishingProjectBalance(tx, userId, { projectId: input.projectId });
  const result = await tx.query(
    `INSERT INTO finishing_projects(user_id,project_id,client_name,project_name,description)
     VALUES($1,$2,$3,$4,$5) ON CONFLICT (user_id,project_id) DO NOTHING`,
    [userId,input.projectId,clientName,projectName,description],
  );
  if (result.rowCount === 1) return 'created';
  const existing = await tx.query(
    'SELECT client_name,project_name,description FROM finishing_projects WHERE user_id=$1 AND project_id=$2',
    [userId,input.projectId],
  );
  if (existing.rowCount !== 1) throw new Error('project creation conflict');
  const row = existing.rows[0] as {client_name:string;project_name:string;description:string};
  if (row.client_name !== clientName || row.project_name !== projectName || row.description !== description) {
    throw new Error('project id reused with different details');
  }
  return 'already_exists';
}

export async function listFinishingProjects(tx: Tx,userId:string) {
  const result = await tx.query(
    `SELECT p.project_id,p.client_name,p.project_name,p.description,p.created_at,
       b.custody_piasters::text,b.receivable_piasters::text,b.cost_piasters::text,
       b.financial_status,b.closed_at
     FROM finishing_projects p
     JOIN finishing_project_balances b USING(user_id,project_id)
     WHERE p.user_id=$1 ORDER BY p.created_at DESC,p.project_id DESC LIMIT 200`,
    [userId],
  );
  return result.rows;
}

export async function getFinishingProject(tx:Tx,userId:string,projectId:string) {
  if (!/^[A-Za-z0-9_-]{1,100}$/.test(projectId)) throw new Error('invalid project id');
  const result = await tx.query(
    `SELECT p.project_id,p.client_name,p.project_name,p.description,p.created_at,
       b.custody_piasters::text,b.receivable_piasters::text,b.cost_piasters::text,
       b.financial_status,b.closed_at
     FROM finishing_projects p
     JOIN finishing_project_balances b USING(user_id,project_id)
     WHERE p.user_id=$1 AND p.project_id=$2`,
    [userId,projectId],
  );
  return result.rows[0] ?? null;
}
