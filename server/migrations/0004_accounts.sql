-- Phase 2 (UI/UX document §13): accounts (Cash / Bank / Credit card / Debit card / Wallet /
-- Savings / Other) and transfers between them. Balances are derived on the device from the
-- opening balance plus the account's transactions; nothing here stores a running balance.

create table accounts (
  user_id         uuid not null references users(id) on delete cascade,
  id              text not null,
  name            text not null,
  type            text not null check (type in ('cash','bank','creditCard','debitCard','wallet','savings','other')),
  opening_balance numeric(18,2) not null default 0,
  currency        char(3) not null default 'EGP',
  color           text not null,
  card_id         text,             -- sync id of the card this account represents (card types)
  is_active       boolean not null default true,
  updated_at      timestamptz not null,
  deleted_at      timestamptz,
  seq             bigint not null default nextval('change_seq'),
  primary key (user_id, id)
);
create index accounts_seq_idx on accounts (user_id, seq);

alter table transactions add column account_id text;
alter table transactions add column to_account_id text;
alter table transactions drop constraint if exists transactions_type_check;
alter table transactions add constraint transactions_type_check
  check (type in ('expense','income','trustIn','trustOut','transfer'));

alter table categories drop constraint if exists categories_type_check;
alter table categories add constraint categories_type_check
  check (type in ('expense','income','trust','transfer'));

alter table users add column phone text;
