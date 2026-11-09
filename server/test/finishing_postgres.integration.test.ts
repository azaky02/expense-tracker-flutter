import assert from 'node:assert/strict';
import test from 'node:test';
import pg from 'pg';
import { applyFinishingCostToLedger } from '../src/finishing_project_ledger.ts';
import { closeFinishingProject } from '../src/finishing_project_closure.ts';

const url = process.env.FINISHING_TEST_DATABASE_URL;
test('PostgreSQL serializes concurrent custody spending and blocks premature closure', {
  skip: !url ? 'FINISHING_TEST_DATABASE_URL is not configured' : false,
}, async () => {
  const pool = new pg.Pool({ connectionString: url, max: 3 });
  const schema = 'finishing_ci_' + Math.random().toString(36).slice(2, 12);
  const userId = '00000000-0000-4000-8000-000000000001';
  const a = await pool.connect();
  const b = await pool.connect();
  try {
    await a.query('CREATE SCHEMA "' + schema + '"');
    await a.query(`CREATE TABLE "${schema}".finishing_project_balances (
      user_id uuid NOT NULL, project_id text NOT NULL,
      custody_piasters bigint NOT NULL CHECK(custody_piasters>=0),
      receivable_piasters bigint NOT NULL CHECK(receivable_piasters>=0),
      cost_piasters bigint NOT NULL CHECK(cost_piasters>=0),
      financial_status text NOT NULL DEFAULT 'open', closed_at timestamptz,
      updated_at timestamptz DEFAULT now(), PRIMARY KEY(user_id,project_id))`);
    await a.query(`CREATE TABLE "${schema}".finishing_project_movements (
      user_id uuid NOT NULL,event_id text NOT NULL,project_id text NOT NULL,
      kind text NOT NULL,amount_piasters bigint NOT NULL,
      custody_share_piasters bigint NOT NULL,personal_share_piasters bigint NOT NULL,
      PRIMARY KEY(user_id,event_id))`);
    await a.query(`CREATE TABLE "${schema}".finishing_posting_requests (
      user_id text NOT NULL,project_id text,state text NOT NULL)`);
    await a.query(`INSERT INTO "${schema}".finishing_project_balances
      (user_id,project_id,custody_piasters,receivable_piasters,cost_piasters)
      VALUES ($1,'p1',10000,0,0)`,[userId]);
    await a.query('BEGIN');
    await b.query('BEGIN');
    await a.query('SET LOCAL search_path TO "' + schema + '"');
    await b.query('SET LOCAL search_path TO "' + schema + '"');
    await applyFinishingCostToLedger(a as never,userId,{
      projectId:'p1',eventId:'first',custodyPiasters:7000,personalPiasters:0,
    });
    // The second transaction waits for the first row lock; after commit it
    // must see the reduced balance and reject the overdraft.
    const second = applyFinishingCostToLedger(b as never,userId,{
      projectId:'p1',eventId:'second',custodyPiasters:7000,personalPiasters:0,
    }).then(()=> 'posted',()=> 'rejected');
    await a.query('COMMIT');
    assert.equal(await second,'rejected');
    await b.query('ROLLBACK');
    await assert.rejects(async () => {
      await a.query('BEGIN');
      await a.query('SET LOCAL search_path TO "' + schema + '"');
      try { await closeFinishingProject(a as never,userId,'p1'); }
      finally { await a.query('ROLLBACK'); }
    }, /outstanding custody/);
    const balance=await a.query(`SELECT custody_piasters,cost_piasters FROM "${schema}".finishing_project_balances WHERE user_id=$1 AND project_id='p1'`,[userId]);
    assert.equal(Number(balance.rows[0].custody_piasters),3000);
    assert.equal(Number(balance.rows[0].cost_piasters),7000);
  } finally {
    await a.query('ROLLBACK').catch(()=>{});
    await b.query('ROLLBACK').catch(()=>{});
    a.release();b.release();
    await pool.query('DROP SCHEMA IF EXISTS "'+schema+'" CASCADE');
    await pool.end();
  }
});
