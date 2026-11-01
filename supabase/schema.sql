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

-- Live updates: phones in the same family see changes right away
alter publication supabase_realtime add table families, subscriptions;
