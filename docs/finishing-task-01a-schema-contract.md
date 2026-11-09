# Task 01A — Schema and posting contract (review before migration)

Status: design only. No database migration or production changes have been made.

## Confirmed integration hazards
1. Current local schemaVersion is 8. The SQLite account balance query counts only income, expense and transfer; trustIn/trustOut are *not* included. Therefore DO NOT use trustIn/trustOut to represent real project cash receipts/disbursements without explicitly fixing the account balance projection and its regression tests.
2. Current sync pipeline is table-based last-writer-wins. Financial event posting must be immutable/idempotent and conflict-safe rather than simply adding project financial tables to the generic mutable sync table list.
3. Current local transaction rows use REAL amounts, while the new financial engine should store integer piasters. Define exact conversion and reject amounts with >2 decimal places.
4. Local People/Accounts/Transactions use integer row ids plus stable sync_id. Project links across devices must use stable sync ids, not local row ids.
5. Backup/restore and sign-out/wipe have explicit table lists and must be updated together with the schema.

## Proposed SQLite v9 tables
- finishing_projects: id TEXT PRIMARY KEY (UUID), person_sync_id TEXT NOT NULL, name TEXT NOT NULL, location TEXT, start_date TEXT NOT NULL, planned_end_date TEXT, budget_piasters INTEGER, work_status TEXT NOT NULL, financial_status TEXT NOT NULL, notes TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL; CHECK budget_piasters >= 0.
- finishing_trades: id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES finishing_projects(id), label TEXT NOT NULL, sort_order INTEGER NOT NULL, UNIQUE(project_id,label).
- finishing_events: id TEXT PRIMARY KEY, project_id TEXT NOT NULL REFERENCES finishing_projects(id), kind TEXT NOT NULL CHECK(kind IN ('client_advance','personal_allocation','cost','reimburse_from_custody','client_repay_personal','return_custody','reversal')), occurred_at TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('pending','posted','reversed')), reverses_event_id TEXT UNIQUE REFERENCES finishing_events(id), memo TEXT, created_at INTEGER NOT NULL; unique client-generated event id is idempotency key.
- finishing_cost_details: event_id TEXT PRIMARY KEY REFERENCES finishing_events(id), trade_id TEXT NOT NULL REFERENCES finishing_trades(id), cost_type TEXT NOT NULL CHECK(cost_type IN ('materials','labor','other')), amount_piasters INTEGER NOT NULL CHECK(amount_piasters > 0), description TEXT NOT NULL, payee TEXT.
- finishing_allocations: id TEXT PRIMARY KEY, event_id TEXT NOT NULL REFERENCES finishing_events(id), funding_source TEXT NOT NULL CHECK(funding_source IN ('client_custody','personal')), amount_piasters INTEGER NOT NULL CHECK(amount_piasters > 0), UNIQUE(event_id,funding_source). All allocations for a cost must sum to its amount.
- finishing_cash_legs: id TEXT PRIMARY KEY, event_id TEXT NOT NULL REFERENCES finishing_events(id), account_sync_id TEXT NOT NULL, direction TEXT NOT NULL CHECK(direction IN ('in','out')), amount_piasters INTEGER NOT NULL CHECK(amount_piasters > 0), existing_transaction_sync_id TEXT UNIQUE, UNIQUE(event_id,account_sync_id,direction). Physical movements only; no legs for earmarking within the same account.
- finishing_audit: id TEXT PRIMARY KEY, event_id TEXT, project_id TEXT NOT NULL, action TEXT NOT NULL, recorded_at INTEGER NOT NULL, details_json TEXT NOT NULL.
- finishing_attachments: id TEXT PRIMARY KEY, project_id TEXT NOT NULL, event_id TEXT, local_uri TEXT, metadata_json TEXT.

Do not persist derived custody or receivable balances as editable totals; derive from posted event effects and verify against snapshot aggregates if optimization is needed.

## Posting invariant examples (all amounts piasters)
- client_advance 50,000 EGP: custody +5,000,000; real cash in +5,000,000.
- cost 10,000 EGP split 7,000 custody/3,000 personal: project cost +1,000,000 once; custody -700,000; receivable +300,000; real cash out -1,000,000 across the actual account legs.
- reimburse_from_custody 2,000 EGP: custody -200,000; receivable -200,000; no new cost; physical transfer only if different owned accounts.
- client_repay_personal 2,000 EGP: receivable -200,000; custody unchanged; real cash in +200,000.
- return_custody 3,000 EGP: custody -300,000; receivable unchanged; real cash out -300,000.
- personal_allocation: project personal liquidity + amount, but custody and receivable unchanged; no real movement unless a genuine account-to-account transfer occurs.

## Atomicity and conflict control
- Posting authority must validate balances, event uniqueness, and account legs atomically.
- On offline clients, events may be pending but must not be reported as server-confirmed; concurrent submissions must reconcile without overspending custody.
- Reversals are new immutable events, never destructive deletion of posted entries.
- Server migration should use a separate PostgreSQL migration after finalizing server posting endpoint and ownership constraints.
- Project financial status cannot become closed until all events posted, custody=0, receivable=0, and no unresolved conflicts.

## Migration gates
1. Snapshot v8 DB and pre-upgrade balances.
2. Add new tables and indexes only; no destructive changes to existing rows.
3. Verify v8 -> v9 upgrade and fresh install.
4. Verify balances, backups, sign-out/wipe and sync behavior with project data.
5. Add migration rollback/recovery strategy and test on copied database before deployment.

## Open architecture decisions before writing migration
- Whether project financial events are server-authoritative (recommended) and how offline pending postings are presented.
- Whether direct customer repayments should be represented in Shared Ledger or as a projection only.
- How existing account transaction types will represent client-held funds so balances stay correct and income analytics remain unaffected.
- Management fees are not yet approved and are intentionally excluded.
