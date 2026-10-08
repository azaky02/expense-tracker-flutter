# Masarefy V2 – People & Shared Ledger (M3 + M4)

Implements sections 3, 4, 7.2, 8, 9, 10, 12 (in-app), 14 and 15.1 of
`Masarefy_System_Design_v2.docx`. Owner decisions (2026-10-08): start with M3+M4; the
counterparty may be a registered user **or** a person without an account; notifications are
in-app now, push later.

## Model

| Table (server, PostgreSQL) | Purpose |
|---|---|
| `people` | The user's address book (synced like other personal data, last-writer-wins). |
| `ledger_entries` | One row per shared financial event. `id` is client-generated and is the idempotency key. `status`: PENDING / CONFIRMED / REJECTED / CANCELLED. `kind`: LOAN / ADVANCE / SETTLEMENT / OTHER. |
| `ledger_participants` | One row per party (seat 1 = creator, seat 2 = counterparty; the key allows more). `direction` is from that party's own side: GAVE / RECEIVED. `user_id` null = a person without an account. |
| `notifications` | NEW_ENTRY, SETTLEMENT_RECEIVED, CONFIRMED, REJECTED, CANCELLED. |
| `audit_logs` | CREATE / CONFIRM / REJECT / CANCEL with actor and payload. |

On the phone (Drift, schema v3): `people` (synced), `ledger_entries` (read-only replica from the
user's side), `ledger_outbox` (queued operations), `app_notifications`.

## Rules

* With a registered user (the person's e-mail matches an account): the entry starts **PENDING**;
  only the counterparty can **confirm** or **reject** (with a reason); only the creator can
  **cancel** while pending. A confirmed shared entry is never edited or cancelled – record an
  opposite entry (adjustment) instead.
* With a person without an account: the entry is the creator's own record, **CONFIRMED** at once,
  and the creator may void (cancel) it.
* Balances are never stored: they are derived from CONFIRMED entries only.
  Loans/advances/other create an obligation, settlements pay one down; a settlement larger than the
  obligation flips to the other side. `net = Σ GAVE − Σ RECEIVED` (> 0 = they owe me, receivable;
  < 0 = I owe them, payable).
* Statement = confirmed entries, oldest first, with a running balance, totals, remaining balance,
  count and last date; shared as text.

## API (rides on `POST /api/sync`, one round trip)

Request adds `ledgerCursor`, `notificationCursor`, `ledgerOps[]`, `readNotifications[]`.
Ops: `create {id, kind, direction, amount, currency, date, description?, personId?,
counterpartEmail?, counterpartName?, settlesEntryId?}`, `confirm {id}`, `reject {id, reason?}`,
`cancel {id}`. Response adds `ledgerResults[]` (`ok`, `status`, `error`: id_taken /
self_counterparty / settles_not_found / not_found / not_allowed / invalid_state), `ledger
{entries, cursor, hasMore}` and `notifications {items, cursor, hasMore}`. Every user touched by a
request is locked in a fixed order, so a feed cursor never skips a late commit and two users
cannot deadlock.

## Offline

Creating, confirming, rejecting and cancelling all work offline: the change is applied to the
local replica at once (marked "waiting to sync") and the op is queued; the server's answer
replaces the optimistic copy. Re-sending is safe (idempotent).

## Migration from v1.1

"Amanat" transactions become ledger entries with the same person (received = OTHER,
paid back = SETTLEMENT), queued for the server; the old transactions are deleted (the delete
syncs). The "+" menu is now Expense / Income / Transaction with a person / Settlement; the bottom
navigation is Home | Transactions | + | People | More (cards moved under More).

## Not in this slice

DISPUTED/RESOLVED states, multi-party entries in the UI, push notifications, PDF/Excel export of
statements, multi-currency UI, accounts/transfers (M1/M2), budgets/recurring/calendar (M6).
