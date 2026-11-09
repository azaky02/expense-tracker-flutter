import assert from 'node:assert/strict';
import test from 'node:test';
import pg from 'pg';
import { postFinishingClientAdvance } from '../src/finishing_client_advance.ts';
import { postFinishingCostCash } from '../src/finishing_cost_cash.ts';
import { postFinishingSettlement } from '../src/finishing_settlement.ts';
import { closeFinishingProject } from '../src/finishing_project_closure.ts';

const url = process.env.FINISHING_TEST_DATABASE_URL;
test('PostgreSQL complete financial lifecycle: advance, split cost, settlements, close, retry', {
  skip: !url ? 'FINISHING_TEST_DATABASE_URL is not configured' : false,
}, async () => {
  const pool = new pg.Pool({ connectionString: url, max: 2 });
  const schema = 'finishing_lifecycle_' + Math.random().toString(36).slice(2, 11);
  const user = '00000000-0000-4000-8000-000000000002';
  const date = '2026-11-09';
  const client = await pool.connect();
  try {
    await client.query('CREATE SCHEMA "' + schema + '"');
    await client.query(`CREATE TABLE "${schema}".finishing_project_balances (
      user_id uuid, project_id text, custody_piasters bigint NOT NULL DEFAULT 0 CHECK(custody_piasters>=0),
      receivable_piasters bigint NOT NULL DEFAULT 0 CHECK(receivable_piasters>=0),
      cost_piasters bigint NOT NULL DEFAULT 0 CHECK(cost_piasters>=0),
      financial_status text NOT NULL DEFAULT 'open', closed_at timestamptz,
      updated_at timestamptz DEFAULT now(), PRIMARY KEY(user_id,project_id))`);
    await client.query(`CREATE TABLE "${schema}".finishing_project_movements (
      user_id uuid,event_id text,project_id text,kind text,amount_piasters bigint,
      custody_share_piasters bigint DEFAULT 0,personal_share_piasters bigint DEFAULT 0,
      PRIMARY KEY(user_id,event_id))`);
    await client.query(`CREATE TABLE "${schema}".finishing_posting_requests (
      user_id text,event_id text,payload_hash text,project_id text,
      state text NOT NULL DEFAULT 'reserved',created_at timestamptz DEFAULT now(),
      committed_at timestamptz,PRIMARY KEY(user_id,event_id))`);
    await client.query(`CREATE TABLE "${schema}".accounts (
      user_id uuid,id text,is_active boolean,deleted_at timestamptz)`);
    await client.query(`CREATE TABLE "${schema}".categories (
      user_id uuid,id text,type text,deleted_at timestamptz)`);
    await client.query(`CREATE TABLE "${schema}".transactions (
      user_id uuid,id text,amount numeric(14,2),type text,category_id text,
      payment_method_type text,date date,note text,created_at timestamptz,
      updated_at timestamptz,account_id text,PRIMARY KEY(user_id,id))`);
    await client.query(`INSERT INTO "${schema}".finishing_project_balances(user_id,project_id)
      VALUES($1,'project')`,[user]);
    await client.query(`INSERT INTO "${schema}".accounts VALUES($1,'cash',true,NULL)`,[user]);
    await client.query(`INSERT INTO "${schema}".categories VALUES
      ($1,'trust','trust',NULL),($1,'expense','expense',NULL)`,[user]);
    const inTx = async <T>(fn:()=>Promise<T>):Promise<T> => {
      await client.query('BEGIN');
      await client.query('SET LOCAL search_path TO "'+schema+'"');
      try { const result=await fn(); await client.query('COMMIT'); return result; }
      catch(error) { await client.query('ROLLBACK'); throw error; }
    };
    const advance = { eventId:'advance',projectId:'project',accountId:'cash',
      trustCategoryId:'trust',amountPiasters:2000000,occurredOn:date };
    assert.equal(await inTx(()=>postFinishingClientAdvance(client as never,user,advance)),'posted');
    assert.equal(await inTx(()=>postFinishingClientAdvance(client as never,user,advance)),'already_committed');
    assert.equal(await inTx(()=>postFinishingCostCash(client as never,user,{
      eventId:'cost',projectId:'project',accountId:'cash',custodyCategoryId:'trust',
      expenseCategoryId:'expense',custodyPiasters:700000,personalPiasters:300000,occurredOn:date,
    })),'posted');
    await assert.rejects(()=>inTx(()=>closeFinishingProject(client as never,user,'project')),/outstanding/);
    assert.equal(await inTx(()=>postFinishingSettlement(client as never,user,{
      eventId:'reimburse',projectId:'project',kind:'reimburse_from_custody',
      amountPiasters:300000,occurredOn:date,
    })),'posted');
    assert.equal(await inTx(()=>postFinishingSettlement(client as never,user,{
      eventId:'return',projectId:'project',kind:'return_custody',
      amountPiasters:1000000,accountId:'cash',categoryId:'trust',occurredOn:date,
    })),'posted');
    const result=await inTx(()=>closeFinishingProject(client as never,user,'project'));
    assert.equal(result.status,'closed');
    assert.equal((await inTx(()=>closeFinishingProject(client as never,user,'project'))).status,'already_closed');
    await assert.rejects(()=>inTx(()=>postFinishingClientAdvance(client as never,user,{
      ...advance,eventId:'after-close',
    })),/project balance not initialized/);
    const balance=await client.query(`SELECT * FROM "${schema}".finishing_project_balances WHERE project_id='project'`);
    assert.equal(Number(balance.rows[0].custody_piasters),0);
    assert.equal(Number(balance.rows[0].receivable_piasters),0);
    assert.equal(Number(balance.rows[0].cost_piasters),1000000);
    const movements=await client.query(`SELECT COUNT(*)::int AS count FROM "${schema}".finishing_project_movements`);
    assert.equal(movements.rows[0].count,4);
    const cash=await client.query(`SELECT COUNT(*)::int AS count FROM "${schema}".transactions`);
    assert.equal(cash.rows[0].count,4);
  } finally {
    await client.query('ROLLBACK').catch(()=>{});
    client.release();
    await pool.query('DROP SCHEMA IF EXISTS "'+schema+'" CASCADE');
    await pool.end();
  }
});
