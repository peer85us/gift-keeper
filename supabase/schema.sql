-- Gift Keeper cloud: run this once in your Supabase project (SQL Editor → New query → Run).
-- One row per family holds the shared wallet; people join a family with its invite code.

create table if not exists families (
  id          uuid primary key default gen_random_uuid(),
  invite_code text unique not null default upper(substr(md5(random()::text), 1, 8)),
  data        jsonb not null default '{}',
  updated_at  timestamptz not null default now(),
  updated_by  uuid
);

create table if not exists family_members (
  family_id uuid not null references families on delete cascade,
  user_id   uuid not null references auth.users on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

-- Paid plans, written only by the Stripe webhook (service role)
create table if not exists subscriptions (
  family_id           uuid primary key references families on delete cascade,
  tier                text not null check (tier in ('premium', 'ultra')),
  status              text not null,
  since               date not null default current_date,
  stripe_customer     text,
  stripe_subscription text unique
);

alter table families       enable row level security;
alter table family_members enable row level security;
alter table subscriptions  enable row level security;

create or replace function is_member(fid uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from family_members where family_id = fid and user_id = auth.uid());
$$;

create policy "members read their family"   on families       for select using (is_member(id));
create policy "members update their family" on families       for update using (is_member(id)) with check (is_member(id));
create policy "see your own memberships"    on family_members for select using (user_id = auth.uid());
create policy "members see the family plan" on subscriptions  for select using (is_member(family_id));

-- Start a family with what's already on the phone
create or replace function create_family(initial jsonb) returns families
language plpgsql security definer set search_path = public as $$
declare f families;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into families (data, updated_by) values (initial, auth.uid()) returning * into f;
  insert into family_members (family_id, user_id) values (f.id, auth.uid());
  return f;
end $$;

-- Join with an invite code (leaves any family you were in)
create or replace function join_family(code text) returns families
language plpgsql security definer set search_path = public as $$
declare f families;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into f from families where invite_code = upper(trim(code));
  if f.id is null then raise exception 'no such family'; end if;
  delete from family_members where user_id = auth.uid() and family_id <> f.id;
  insert into family_members (family_id, user_id) values (f.id, auth.uid()) on conflict do nothing;
  delete from families x where not exists (select 1 from family_members m where m.family_id = x.id);
  return f;
end $$;

-- Delete my account; a family nobody is left in is deleted with it
create or replace function delete_me() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  delete from auth.users where id = auth.uid();
  delete from families x where not exists (select 1 from family_members m where m.family_id = x.id);
end $$;

revoke all on function create_family(jsonb), join_family(text), delete_me() from anon;

-- Keeper Coins: every change is a ledger line. Purchases are added by the Stripe webhook;
-- spending and the daily bonus go through the functions below, which check the price and balance.
create table if not exists coin_ledger (
  id         bigserial primary key,
  family_id  uuid not null references families on delete cascade,
  member     text not null,               -- the family profile the coins belong to
  delta      integer not null,
  reason     text not null,               -- buy:<pack> · daily:<date> · item:<item>
  ref        text unique,                 -- Stripe checkout session, so a payment is only counted once
  created_at timestamptz not null default now()
);
create table if not exists shop_items (
  id     text primary key,
  price  integer not null,
  repeat boolean not null default false
);
insert into shop_items (id, price, repeat) values
  ('theme:birthday', 100, false), ('theme:holiday', 100, false), ('theme:love', 100, false),
  ('theme:galaxy', 100, false), ('theme:gold', 100, false), ('theme:sports', 100, false),
  ('theme:diamond', 250, false), ('theme:neon', 250, false), ('theme:lava', 250, false), ('theme:aurora', 250, false),
  ('kid:galaxy', 150, false), ('kid:rainbow', 150, false), ('kid:dino', 150, false),
  ('kid:unicorn', 150, false), ('kid:camo', 150, false), ('kid:gold', 300, false),
  ('frame:gold', 100, false), ('frame:ice', 150, false), ('frame:fire', 200, false), ('frame:rainbow', 200, false),
  ('slots5', 400, true)
on conflict (id) do update set price = excluded.price, repeat = excluded.repeat;

alter table coin_ledger enable row level security;
alter table shop_items  enable row level security;
create policy "members see family coins" on coin_ledger for select using (is_member(family_id));
create policy "anyone sees prices"       on shop_items  for select using (true);

create or replace function buy_item(fid uuid, member text, item text) returns void
language plpgsql security definer set search_path = public as $$
declare it shop_items; bal integer;
begin
  if not is_member(fid) then raise exception 'not in this family'; end if;
  perform pg_advisory_xact_lock(hashtext(fid::text || member));   -- one purchase at a time per person
  select * into it from shop_items where id = item;
  if it.id is null then raise exception 'no such item'; end if;
  if not it.repeat and exists (select 1 from coin_ledger l where l.family_id = fid and l.member = buy_item.member and l.reason = 'item:' || item)
    then raise exception 'already owned'; end if;
  select coalesce(sum(delta), 0) into bal from coin_ledger l where l.family_id = fid and l.member = buy_item.member;
  if bal < it.price then raise exception 'not enough coins'; end if;
  insert into coin_ledger (family_id, member, delta, reason) values (fid, member, -it.price, 'item:' || item);
end $$;

create or replace function claim_daily(fid uuid, member text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(fid) then raise exception 'not in this family'; end if;
  perform pg_advisory_xact_lock(hashtext(fid::text || member));
  if exists (select 1 from coin_ledger l where l.family_id = fid and l.member = claim_daily.member and l.reason = 'daily:' || current_date)
    then raise exception 'already claimed'; end if;
  insert into coin_ledger (family_id, member, delta, reason) values (fid, member, 5, 'daily:' || current_date);
end $$;

-- One-time bonuses: sharing your invite link (25 coins) and joining from a friend's link (50)
create or replace function claim_bonus(fid uuid, member text, kind text) returns void
language plpgsql security definer set search_path = public as $$
declare amount int := case kind when 'share' then 25 when 'invite' then 50 end;
begin
  if not is_member(fid) then raise exception 'not in this family'; end if;
  if amount is null then raise exception 'unknown bonus'; end if;
  perform pg_advisory_xact_lock(hashtext(fid::text || member));
  if exists (select 1 from coin_ledger l where l.family_id = fid and l.member = claim_bonus.member and l.reason = 'bonus:' || kind)
    then raise exception 'already claimed'; end if;
  insert into coin_ledger (family_id, member, delta, reason) values (fid, member, amount, 'bonus:' || kind);
end $$;

revoke all on function buy_item(uuid, text, text), claim_daily(uuid, text), claim_bonus(uuid, text, text) from anon;

-- Live updates: phones in the same family see changes right away
alter publication supabase_realtime add table families, subscriptions, coin_ledger;

-- ============================================================================
-- Shop update (Nov 2026): stickers, pets, app colors, Early alerts, seasonal styles,
-- streaks, coins for adding cards, achievements.
-- Safe to run again on its own if you already ran everything above.
-- ============================================================================
alter table shop_items add column if not exists season_from text;   -- 'MM-DD'; may wrap past New Year
alter table shop_items add column if not exists season_to   text;

insert into shop_items (id, price, repeat, season_from, season_to) values
  ('theme:xmas', 200, false, '11-15', '12-31'), ('theme:snow', 200, false, '12-01', '02-28'),
  ('theme:newyear', 200, false, '12-26', '01-10'), ('theme:valentine', 200, false, '02-01', '02-14'),
  ('theme:halloween', 200, false, '10-01', '10-31')
on conflict (id) do update set price = excluded.price, season_from = excluded.season_from, season_to = excluded.season_to;

insert into shop_items (id, price, repeat) values
  ('sticker:star', 50, false), ('sticker:cake', 50, false), ('sticker:gift', 50, false), ('sticker:heart', 50, false),
  ('sticker:party', 75, false), ('sticker:fire', 75, false), ('sticker:crown', 100, false), ('sticker:rocket', 100, false),
  ('pet:puppy', 150, false), ('pet:kitty', 150, false), ('pet:bunny', 150, false), ('pet:panda', 200, false),
  ('pet:fox', 200, false), ('pet:owl', 200, false), ('pet:dragon', 400, false),
  ('look:sunset', 200, false), ('look:ocean', 200, false), ('look:forest', 200, false), ('look:candy', 200, false), ('look:gold', 300, false),
  ('boost:early', 150, false)
on conflict (id) do update set price = excluded.price, repeat = excluded.repeat;

create or replace function buy_item(fid uuid, member text, item text) returns void
language plpgsql security definer set search_path = public as $$
declare it shop_items; bal integer; md text := to_char(current_date, 'MM-DD');
begin
  if not is_member(fid) then raise exception 'not in this family'; end if;
  perform pg_advisory_xact_lock(hashtext(fid::text || member));   -- one purchase at a time per person
  select * into it from shop_items where id = item;
  if it.id is null then raise exception 'no such item'; end if;
  if it.season_from is not null and not (case when it.season_from <= it.season_to
      then md between it.season_from and it.season_to else md >= it.season_from or md <= it.season_to end)
    then raise exception 'out of season'; end if;
  if not it.repeat and exists (select 1 from coin_ledger l where l.family_id = fid and l.member = buy_item.member and l.reason = 'item:' || item)
    then raise exception 'already owned'; end if;
  select coalesce(sum(delta), 0) into bal from coin_ledger l where l.family_id = fid and l.member = buy_item.member;
  if bal < it.price then raise exception 'not enough coins'; end if;
  insert into coin_ledger (family_id, member, delta, reason) values (fid, member, -it.price, 'item:' || item);
end $$;

-- One-time bonuses: sharing (25), joining from a friend's link (50), and achievements (keep in step with ACHIEVEMENTS in app.html)
create or replace function claim_bonus(fid uuid, member text, kind text) returns void
language plpgsql security definer set search_path = public as $$
declare amount int := case kind when 'share' then 25 when 'invite' then 50
  when 'ach:first' then 10 when 'ach:five' then 25 when 'ach:spent' then 15
  when 'ach:beat' then 25 when 'ach:big' then 20 when 'ach:goal' then 50 end;
begin
  if not is_member(fid) then raise exception 'not in this family'; end if;
  if amount is null then raise exception 'unknown bonus'; end if;
  perform pg_advisory_xact_lock(hashtext(fid::text || member));
  if exists (select 1 from coin_ledger l where l.family_id = fid and l.member = claim_bonus.member and l.reason = 'bonus:' || kind)
    then raise exception 'already claimed'; end if;
  insert into coin_ledger (family_id, member, delta, reason) values (fid, member, amount, 'bonus:' || kind);
end $$;

-- 25 coins every 7th day in a row the daily bonus is claimed
create or replace function claim_streak(fid uuid, member text) returns void
language plpgsql security definer set search_path = public as $$
declare n int := 0; d date := current_date;
begin
  if not is_member(fid) then raise exception 'not in this family'; end if;
  perform pg_advisory_xact_lock(hashtext(fid::text || member));
  while exists (select 1 from coin_ledger l where l.family_id = fid and l.member = claim_streak.member and l.reason = 'daily:' || d) loop
    n := n + 1; d := d - 1;
  end loop;
  if n = 0 or n % 7 <> 0 then raise exception 'no streak bonus today'; end if;
  if exists (select 1 from coin_ledger l where l.family_id = fid and l.member = claim_streak.member and l.reason = 'streak:' || current_date)
    then raise exception 'already claimed'; end if;
  insert into coin_ledger (family_id, member, delta, reason) values (fid, member, 25, 'streak:' || current_date);
end $$;

-- 2 coins for each new gift card, up to 5 cards a month per person
create or replace function claim_card(fid uuid, member text, card text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(fid) then raise exception 'not in this family'; end if;
  perform pg_advisory_xact_lock(hashtext(fid::text || member));
  if exists (select 1 from coin_ledger l where l.family_id = fid and l.reason = 'card:' || card)
    then raise exception 'already counted'; end if;
  if (select count(*) from coin_ledger l where l.family_id = fid and l.member = claim_card.member and l.reason like 'card:%'
      and l.created_at >= date_trunc('month', now())) >= 5 then raise exception 'monthly limit'; end if;
  insert into coin_ledger (family_id, member, delta, reason) values (fid, member, 2, 'card:' || card);
end $$;

revoke all on function buy_item(uuid, text, text), claim_bonus(uuid, text, text),
  claim_streak(uuid, text), claim_card(uuid, text, text) from anon;
