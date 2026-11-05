alter table public.user_follows add column active boolean not null default true;
revoke delete on public.user_follows from authenticated;
grant update on public.user_follows to authenticated;
drop policy follows_owner_delete on public.user_follows;
create policy follows_owner_update on public.user_follows for update to authenticated
  using (follower_id = (select auth.uid())) with check (follower_id = (select auth.uid()));

create or replace function private.discover_toti_users()
returns table (user_id uuid, nickname text, gender text, country text, age integer)
language sql stable security definer set search_path = '' as $$
  select p.user_id, p.nickname, p.gender, p.country,
         extract(year from age(current_date, p.birthday))::integer
  from public.user_profiles p
  where (select auth.uid()) is not null and p.user_id <> (select auth.uid())
    and p.birthday <= (current_date - interval '18 years')::date
    and (not exists (select 1 from public.user_blocks b
          where b.blocker_id = p.user_id and b.blocked_id = (select auth.uid()))
      or exists (select 1 from public.user_blocks b
          where b.blocker_id = (select auth.uid()) and b.blocked_id = p.user_id))
  order by p.nickname, p.user_id;
$$;

create or replace function private.send_toti_message(p_recipient uuid, p_body text, p_client_id text)
returns public.direct_messages language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.direct_messages;
begin
  if actor is null or p_recipient is null or actor = p_recipient
     or p_body is null or char_length(trim(p_body)) not between 1 and 2000
     or p_client_id is null or char_length(p_client_id) not between 16 and 64 then
    raise exception 'Message could not be sent' using errcode = 'P0001';
  end if;
  select * into result from public.direct_messages
    where sender_id = actor and client_id = p_client_id and recipient_id = p_recipient and body = trim(p_body);
  if result.id is not null then return result; end if;
  if not exists (select 1 from public.user_follows where follower_id = actor and followee_id = p_recipient and active)
     or not exists (select 1 from public.user_follows where follower_id = p_recipient and followee_id = actor and active)
     or exists (select 1 from public.user_blocks where (blocker_id = actor and blocked_id = p_recipient) or (blocker_id = p_recipient and blocked_id = actor)) then
    raise exception 'Message could not be sent' using errcode = 'P0001';
  end if;
  insert into public.direct_messages(sender_id, recipient_id, body, client_id)
  values (actor, p_recipient, trim(p_body), p_client_id)
  on conflict (sender_id, client_id) do nothing returning * into result;
  if result.id is null then
    select * into result from public.direct_messages
      where sender_id = actor and client_id = p_client_id and recipient_id = p_recipient and body = trim(p_body);
    if result.id is null then raise exception 'Message could not be sent' using errcode = 'P0001'; end if;
  end if;
  return result;
end; $$;

create or replace function private.block_toti_user(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null or p_user is null or actor = p_user then
    raise exception 'Cannot block user' using errcode = 'P0001';
  end if;
  insert into public.user_blocks(blocker_id, blocked_id) values (actor, p_user) on conflict do nothing;
  update public.user_follows set active = false
    where (follower_id = actor and followee_id = p_user) or (follower_id = p_user and followee_id = actor);
end; $$;
