-- Amanat: money held for / paid to a person. A transaction type 'trustIn' (received) or 'trustOut'
-- (paid out) in the single system category of type 'trust'.
alter table categories drop constraint if exists categories_type_check;
alter table categories add constraint categories_type_check check (type in ('expense','income','trust'));
alter table transactions drop constraint if exists transactions_type_check;
alter table transactions add constraint transactions_type_check check (type in ('expense','income','trustIn','trustOut'));
