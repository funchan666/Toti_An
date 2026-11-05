-- Real accounts are separate from the existing editorial profiles.
create table public.user_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followee_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);
create index user_follows_followee_idx on public.user_follows(followee_id, follower_id);
create table public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index user_blocks_blocked_idx on public.user_blocks(blocked_id, blocker_id);
create table public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null check (char_length(client_id) between 16 and 64),
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  unique (sender_id, client_id),
  check (sender_id <> recipient_id)
);
create index direct_messages_sender_time_idx on public.direct_messages(sender_id, created_at, id);
create index direct_messages_recipient_time_idx on public.direct_messages(recipient_id, created_at, id);
alter table public.user_follows enable row level security;
alter table public.user_blocks enable row level security;
alter table public.direct_messages enable row level security;
grant select, insert, delete on public.user_follows to authenticated;
grant select, delete on public.user_blocks to authenticated;
grant select on public.direct_messages to authenticated;
create policy follows_participants_read on public.user_follows for select to authenticated using (follower_id = (select auth.uid()) or followee_id = (select auth.uid()));
create policy follows_owner_insert on public.user_follows for insert to authenticated with check (follower_id = (select auth.uid()));
create policy follows_owner_delete on public.user_follows for delete to authenticated using (follower_id = (select auth.uid()));
create policy blocks_owner_read on public.user_blocks for select to authenticated using (blocker_id = (select auth.uid()));
create policy blocks_owner_delete on public.user_blocks for delete to authenticated using (blocker_id = (select auth.uid()));
create policy messages_participants_read on public.direct_messages for select to authenticated using (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()));

create schema if not exists private;
grant usage on schema private to authenticated;

create function private.discover_toti_users()
returns table (user_id uuid, nickname text, gender text, country text, age integer)
language sql stable security definer set search_path = ''
as $$
  select p.user_id, p.nickname, p.gender, p.country,
         extract(year from age(current_date, p.birthday))::integer
  from public.user_profiles p
  where (select auth.uid()) is not null and p.user_id <> (select auth.uid())
    and p.birthday <= (current_date - interval '18 years')::date
    and not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = (select auth.uid()) and b.blocked_id = p.user_id)
         or (b.blocker_id = p.user_id and b.blocked_id = (select auth.uid()))
    )
  order by p.nickname, p.user_id;
$$;
revoke all on function private.discover_toti_users() from public, anon;
grant execute on function private.discover_toti_users() to authenticated;
create function public.discover_toti_users()
returns table (user_id uuid, nickname text, gender text, country text, age integer)
language sql stable security invoker set search_path = ''
as $$ select * from private.discover_toti_users(); $$;
revoke all on function public.discover_toti_users() from public, anon;
grant execute on function public.discover_toti_users() to authenticated;

create function private.send_toti_message(p_recipient uuid, p_body text, p_client_id text)
returns public.direct_messages
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result public.direct_messages;
begin
  if actor is null or p_recipient is null or actor = p_recipient
     or p_body is null or char_length(trim(p_body)) not between 1 and 2000
     or p_client_id is null or char_length(p_client_id) not between 16 and 64 then
    raise exception 'Message could not be sent' using errcode = 'P0001';
  end if;
  select * into result from public.direct_messages
    where sender_id = actor and client_id = p_client_id and recipient_id = p_recipient and body = trim(p_body);
  if result.id is not null then return result; end if;
  if not exists (select 1 from public.user_follows where follower_id = actor and followee_id = p_recipient)
     or not exists (select 1 from public.user_follows where follower_id = p_recipient and followee_id = actor)
     or exists (select 1 from public.user_blocks where (blocker_id = actor and blocked_id = p_recipient) or (blocker_id = p_recipient and blocked_id = actor)) then
    raise exception 'Message could not be sent' using errcode = 'P0001';
  end if;
  insert into public.direct_messages(sender_id, recipient_id, body, client_id)
  values (actor, p_recipient, trim(p_body), p_client_id)
  on conflict (sender_id, client_id) do nothing
  returning * into result;
  if result.id is null then
    select * into result from public.direct_messages
      where sender_id = actor and client_id = p_client_id and recipient_id = p_recipient and body = trim(p_body);
    if result.id is null then raise exception 'Message could not be sent' using errcode = 'P0001'; end if;
  end if;
  return result;
end;
$$;
revoke all on function private.send_toti_message(uuid,text,text) from public, anon;
grant execute on function private.send_toti_message(uuid,text,text) to authenticated;
create function public.send_toti_message(p_recipient uuid, p_body text, p_client_id text)
returns public.direct_messages language sql security invoker set search_path = ''
as $$ select private.send_toti_message(p_recipient, p_body, p_client_id); $$;
revoke all on function public.send_toti_message(uuid,text,text) from public, anon;
grant execute on function public.send_toti_message(uuid,text,text) to authenticated;

create function private.block_toti_user(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null or p_user is null or actor = p_user then
    raise exception 'Cannot block user' using errcode = 'P0001';
  end if;
  insert into public.user_blocks(blocker_id, blocked_id) values (actor, p_user) on conflict do nothing;
  delete from public.user_follows where (follower_id = actor and followee_id = p_user) or (follower_id = p_user and followee_id = actor);
end; $$;
revoke all on function private.block_toti_user(uuid) from public, anon;
grant execute on function private.block_toti_user(uuid) to authenticated;
create function public.block_toti_user(p_user uuid) returns void language sql security invoker set search_path = ''
as $$ select private.block_toti_user(p_user); $$;
revoke all on function public.block_toti_user(uuid) from public, anon;
grant execute on function public.block_toti_user(uuid) to authenticated;
alter publication supabase_realtime add table public.user_follows, public.direct_messages;
