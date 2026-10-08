-- V2: People (address book, synced like the other personal data) and the Shared Ledger.
--
-- The ledger is NOT last-writer-wins: one entry on the server is the single shared financial event,
-- each party sees it from their own point of view (ledger_participants.direction), and only
-- CONFIRMED entries count towards a balance. Every state change is written to audit_logs.

create sequence ledger_seq;

create table people (
  user_id        uuid not null references users(id) on delete cascade,
  id             text not null,
  name           text not null,
  phone          text,
  email          text,
  notes          text,
  linked_user_id text,
  updated_at     timestamptz not null,
  deleted_at     timestamptz,
  seq            bigint not null default nextval('change_seq'),
  primary key (user_id, id)
);
create index people_seq_idx on people (user_id, seq);

create table ledger_entries (
  id               text primary key,                 -- client-generated uuid; also the idempotency key
  kind             text not null check (kind in ('LOAN','ADVANCE','SETTLEMENT','OTHER')),
  amount           numeric(18,2) not null check (amount > 0),
  currency         char(3) not null default 'EGP',
  entry_date       date not null,
  description      text,
  status           text not null check (status in ('PENDING','CONFIRMED','REJECTED','CANCELLED')),
  reject_reason    text,
  settles_entry_id text references ledger_entries(id) on delete set null,
  created_by       uuid references users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  confirmed_at     timestamptz,
  seq              bigint not null default nextval('ledger_seq')
);
create index ledger_entries_seq_idx on ledger_entries (seq);

-- Two seats today (creator + counterparty); the key allows more parties later.
-- direction is from that participant's own point of view:
--   GAVE     = this participant handed money to the other side
--   RECEIVED = this participant got money from the other side
create table ledger_participants (
  entry_id     text not null references ledger_entries(id) on delete cascade,
  seat         smallint not null check (seat >= 1),
  role         text not null check (role in ('CREATOR','COUNTERPARTY')),
  user_id      uuid references users(id) on delete set null,   -- null = a person without an account
  person_id    text,                                            -- id in that user's own People list
  display_name text,                                            -- name for a non-user (or deleted-user) party
  direction    text not null check (direction in ('GAVE','RECEIVED')),
  primary key (entry_id, seat)
);
create index ledger_participants_user_idx on ledger_participants (user_id);

create table notifications (
  id         uuid primary key,
  user_id    uuid not null references users(id) on delete cascade,
  type       text not null check (type in ('NEW_ENTRY','SETTLEMENT_RECEIVED','CONFIRMED','REJECTED','CANCELLED')),
  entry_id   text references ledger_entries(id) on delete cascade,
  actor_name text,
  amount     numeric(18,2),
  currency   char(3),
  created_at timestamptz not null default now(),
  read_at    timestamptz,
  seq        bigint not null default nextval('ledger_seq')
);
create index notifications_user_seq_idx on notifications (user_id, seq);

create table audit_logs (
  id            bigserial primary key,
  actor_user_id uuid references users(id) on delete set null,
  entity_type   text not null,
  entity_id     text not null,
  action        text not null,
  payload       jsonb,
  created_at    timestamptz not null default now()
);
create index audit_logs_entity_idx on audit_logs (entity_type, entity_id);
