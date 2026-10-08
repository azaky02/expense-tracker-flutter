-- Masarefy server schema. Every synced row belongs to a user; the client generates ids (text),
-- so an offline device can create data and push it later. Deletes are tombstones (deleted_at).
-- No cross-entity foreign keys on purpose: a device may push a transaction before its category.

create sequence change_seq;

create table users (
  id            uuid primary key,
  email         text not null,
  name          text not null default '',
  password_hash text not null,
  created_at    timestamptz not null default now(),
  last_login_at timestamptz
);
create unique index users_email_uq on users (lower(email));

create table refresh_tokens (
  id         uuid primary key,
  user_id    uuid not null references users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  user_agent text
);
create index refresh_tokens_user_idx on refresh_tokens (user_id);

create table banks (
  user_id    uuid not null references users(id) on delete cascade,
  id         text not null,
  name       text not null,
  logo_uri   text,
  is_custom  boolean not null default false,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  seq        bigint not null default nextval('change_seq'),
  primary key (user_id, id)
);

create table categories (
  user_id    uuid not null references users(id) on delete cascade,
  id         text not null,
  parent_id  text,
  name       text not null,
  icon       text not null,
  color      text not null,
  type       text not null check (type in ('expense','income')),
  is_default boolean not null default false,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  seq        bigint not null default nextval('change_seq'),
  primary key (user_id, id)
);

create table cards (
  user_id           uuid not null references users(id) on delete cascade,
  id                text not null,
  bank_id           text not null,
  card_type         text not null check (card_type in ('visa','mastercard','meeza')),
  card_category     text not null check (card_category in ('credit','debit')),
  nickname          text not null,
  last4_digits      text not null check (last4_digits ~ '^[0-9]{4}$'),
  due_date_day      integer check (due_date_day between 1 and 31),
  statement_date_day integer check (statement_date_day between 1 and 31),
  credit_limit      numeric(14,2),
  color             text not null,
  is_active         boolean not null default true,
  updated_at        timestamptz not null,
  deleted_at        timestamptz,
  seq               bigint not null default nextval('change_seq'),
  primary key (user_id, id)
);

-- Identity is the (case-sensitive) name, same as the app's unique index.
create table beneficiaries (
  user_id      uuid not null references users(id) on delete cascade,
  name         text not null,
  last_used_at timestamptz not null,
  updated_at   timestamptz not null,
  deleted_at   timestamptz,
  seq          bigint not null default nextval('change_seq'),
  primary key (user_id, name)
);

create table transactions (
  user_id             uuid not null references users(id) on delete cascade,
  id                  text not null,
  amount              numeric(14,2) not null,
  type                text not null check (type in ('expense','income')),
  category_id         text not null,
  payment_method_type text not null check (payment_method_type in ('cash','card')),
  card_id             text,
  date                date not null,
  note                text,
  beneficiary_name    text,
  created_at          timestamptz not null,
  updated_at          timestamptz not null,
  deleted_at          timestamptz,
  seq                 bigint not null default nextval('change_seq'),
  primary key (user_id, id)
);
create index transactions_user_date_idx on transactions (user_id, date desc) where deleted_at is null;

create table category_budgets (
  user_id       uuid not null references users(id) on delete cascade,
  category_id   text not null,
  monthly_limit numeric(14,2) not null,
  is_enabled    boolean not null default true,
  updated_at    timestamptz not null,
  deleted_at    timestamptz,
  seq           bigint not null default nextval('change_seq'),
  primary key (user_id, category_id)
);

create index banks_seq_idx            on banks            (user_id, seq);
create index categories_seq_idx       on categories       (user_id, seq);
create index cards_seq_idx            on cards            (user_id, seq);
create index beneficiaries_seq_idx    on beneficiaries    (user_id, seq);
create index transactions_seq_idx     on transactions     (user_id, seq);
create index category_budgets_seq_idx on category_budgets (user_id, seq);
