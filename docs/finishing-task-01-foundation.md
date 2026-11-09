# Finishing Module — Task 01: Financial Foundation

Status: design contract; implementation pending. Branch: feature/finishing-foundation.
Do not merge or deploy until migration, sync, backup, and accounting tests pass.

## Existing architecture verified
- Flutter/Drift local database schema v8; accounts and transactions are syncable.
- Real account balances are derived from opening balances and transaction rows.
- People and Shared Ledger are distinct from the local transaction/account balance model.
- Syncable entities currently use timestamp-based last-writer-wins, unsuitable as the sole source of truth for financial posting.
- Backup uses an explicit list of tables.

## Core invariants
1. Project custody (client-owned) and personally financed project liquidity must never be combined into client custody.
2. Every project cost is recognized exactly once regardless of split funding.
3. Personally financed eligible expenses create a receivable once; reimbursements reduce receivables without recognizing a second cost.
4. Project cash receipts and disbursements affect real accounts only when physical cash actually moves. Internal earmarking/reclassification has no real account movement.
5. Client receipts applied to personal receivables must not increase client custody.
6. No custody overspend, negative money, over-reimbursement, duplicate posting, or silent deletion of posted financial events.
7. Project closure requires no client custody, no receivables, and no pending events. Completion of work is separate.
8. Money stored in integer minor units (EGP piasters), with explicit rounding at integration boundaries.

## Proposed domain records (not migrations yet)
- finishing_projects: stable UUID, owner, person reference, name, status, dates, optional budget and notes.
- finishing_project_categories: stable UUID, project, label, ordering.
- finishing_events: stable UUID/idempotency key, project, event kind, occurred_at, posting status, original_event_id for reversals, audit metadata.
- finishing_costs: event, category, materials/labor, total minor units, payee, description.
- finishing_allocations: event, source custody/personal, amount minor units, real-account posting reference if physical movement.
- finishing_account_links: immutable links to actual transactions and/or ledger entries, unique per source event and leg.
- finishing_attachments and finishing_audit_events.

Avoid duplicate accounting ledgers: choose a single posting authority and define whether the Shared Ledger is a projection or an independently confirmed obligation. A confirmed Shared Ledger event must not be counted twice in customer balances.

## Before coding
- Inspect all transaction posting/update/delete paths and idempotency handling.
- Inspect server migrations and sync client for foreign-key mapping and conflict behavior.
- Design immutable event posting with server-side atomicity or equivalent deterministic conflict-safe reconciliation.
- Confirm account and people references are stable across devices.
- Plan schema v9 additive migration, compatible with older backups and devices.
- Add new tables to backup/export/restore with parent-first ordering and tests.
- Determine how client funds received in a real account should be represented without misclassifying them as personal income.

## Acceptance tests
- Existing database upgrades from v8 with identical pre-existing balances.
- New install creates all finishing tables and required constraints.
- 10,000 cost split 7,000 custody + 3,000 personal: cost=10,000 once; custody -7,000; receivable +3,000; real cash -10,000 exactly once if one real account.
- Direct client reimbursement: real account +amount; receivable -amount; custody unchanged.
- Internal custody-to-personal reimbursement: custody -amount; receivable -amount; no phantom real account cash flow.
- Transfer between owned accounts: equal and opposite real-account movements, no new income/cost.
- Retry and concurrent duplicate submissions post once.
- Offline and multi-device conflict test preserves both legitimate distinct financial events.
- Reversal restores financial positions with audit trail.
- Backup/restore roundtrip preserves all project events and links.
- Old project-less transactions and Shared Ledger entries remain unchanged.
- Closing a project with nonzero custody/receivables/pending entries is rejected.

## Execution gates
Gate A: approved schema and accounting posting contract.
Gate B: migration + repository + unit tests.
Gate C: server synchronization + conflict/idempotency tests.
Gate D: backup/restore + regression tests.
Gate E: reviewed pull request. No direct changes to master.
