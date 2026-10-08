-- Sign-up by mobile number with a one-time code (OTP). E-mail becomes optional.
alter table users alter column email drop not null;
create unique index users_phone_uq on users (phone) where phone is not null;

create table otp_codes (
  id          uuid primary key,
  phone       text not null,
  purpose     text not null,               -- 'register'
  code_hash   text not null,
  attempts    integer not null default 0,
  expires_at  timestamptz not null,
  consumed_at timestamptz,
  created_at  timestamptz not null default now()
);
create index otp_codes_phone_idx on otp_codes (phone, purpose, created_at desc);
