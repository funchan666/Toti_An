-- Real media sessions are separate from the preserved editorial rooms.
create table public.rtc_sessions (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('voice_room', 'live', 'voice_call', 'video_call')),
  owner_id uuid not null references auth.users(id) on delete cascade,
  peer_id uuid references auth.users(id) on delete cascade,
  title text not null default '' check (char_length(title) <= 80),
  summary text not null default '' check (char_length(summary) <= 160),
  tag text not null default '' check (char_length(tag) <= 32),
  status text not null check (status in ('preparing', 'ringing', 'active', 'declined', 'ended')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check ((kind in ('voice_call', 'video_call')) = (peer_id is not null)),
  check (peer_id is null or peer_id <> owner_id)
);
create index rtc_sessions_owner_idx on public.rtc_sessions(owner_id, created_at desc);
create index rtc_sessions_peer_idx on public.rtc_sessions(peer_id, created_at desc) where peer_id is not null;
create index rtc_sessions_public_active_idx on public.rtc_sessions(kind, expires_at desc) where status = 'active' and peer_id is null;
alter table public.rtc_sessions enable row level security;
grant select on public.rtc_sessions to authenticated;

create function private.rtc_can_view(p_owner uuid, p_peer uuid, p_status text, p_expiry timestamptz)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select private.account_can_upload())
    and not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = (select auth.uid()) and b.blocked_id = p_owner)
         or (b.blocker_id = p_owner and b.blocked_id = (select auth.uid()))
         or (p_peer is not null and ((b.blocker_id = (select auth.uid()) and b.blocked_id = p_peer)
           or (b.blocker_id = p_peer and b.blocked_id = (select auth.uid()))))
    )
    and case when p_peer is null then p_expiry > now() and
      (p_status = 'active' or (p_status = 'preparing' and p_owner = (select auth.uid())))
      else (select auth.uid()) in (p_owner, p_peer) end;
$$;
revoke all on function private.rtc_can_view(uuid, uuid, text, timestamptz) from public, anon;
grant execute on function private.rtc_can_view(uuid, uuid, text, timestamptz) to authenticated;
create policy rtc_sessions_visible on public.rtc_sessions for select to authenticated
  using ((select private.rtc_can_view(owner_id, peer_id, status, expires_at)));

create function private.start_toti_rtc(p_kind text, p_title text, p_peer uuid, p_summary text, p_tag text)
returns public.rtc_sessions language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.rtc_sessions; is_call boolean;
begin
  if not private.account_can_upload() then raise exception 'Account unavailable'; end if;
  is_call := p_kind in ('voice_call', 'video_call');
  if p_kind not in ('voice_room', 'live', 'voice_call', 'video_call')
      or is_call <> (p_peer is not null) or p_peer = actor then
    raise exception 'Invalid session';
  end if;
  if is_call and (
    not exists (select 1 from public.user_follows where follower_id = actor and followee_id = p_peer and active)
    or not exists (select 1 from public.user_follows where follower_id = p_peer and followee_id = actor and active)
    or exists (select 1 from public.user_blocks where (blocker_id = actor and blocked_id = p_peer) or (blocker_id = p_peer and blocked_id = actor))
  ) then raise exception 'Mutual follow required'; end if;
  if not is_call and (char_length(trim(coalesce(p_title, ''))) < 3 or char_length(p_title) > 80) then
    raise exception 'Invalid session title';
  end if;
  if char_length(coalesce(p_summary, '')) > 160 or char_length(coalesce(p_tag, '')) > 32 then
    raise exception 'Invalid session details';
  end if;
  insert into public.rtc_sessions(kind, owner_id, peer_id, title, summary, tag, status, expires_at)
  values (p_kind, actor, p_peer, trim(coalesce(p_title, '')), trim(coalesce(p_summary, '')), trim(coalesce(p_tag, '')),
    case when is_call then 'ringing' else 'preparing' end,
    now() + case when is_call then interval '60 seconds' else interval '2 minutes' end)
  returning * into result;
  return result;
end; $$;
revoke all on function private.start_toti_rtc(text, text, uuid, text, text) from public, anon;
grant execute on function private.start_toti_rtc(text, text, uuid, text, text) to authenticated;
create function public.start_toti_rtc(p_kind text, p_title text default '', p_peer uuid default null, p_summary text default '', p_tag text default '')
returns public.rtc_sessions language sql security invoker set search_path = '' as $$
  select private.start_toti_rtc(p_kind, p_title, p_peer, p_summary, p_tag);
$$;
revoke all on function public.start_toti_rtc(text, text, uuid, text, text) from public, anon;
grant execute on function public.start_toti_rtc(text, text, uuid, text, text) to authenticated;

create function private.update_toti_rtc(p_id uuid, p_action text)
returns public.rtc_sessions language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); s public.rtc_sessions; result public.rtc_sessions;
begin
  if not private.account_can_upload() then raise exception 'Account unavailable'; end if;
  select * into s from public.rtc_sessions where id = p_id for update;
  if not found then raise exception 'Session unavailable'; end if;
  if p_action in ('accept', 'decline') then
    if s.peer_id is distinct from actor or s.status <> 'ringing' or s.expires_at <= now()
      or not private.rtc_can_view(s.owner_id, s.peer_id, s.status, s.expires_at)
      or not exists (select 1 from public.user_follows where follower_id = actor and followee_id = s.owner_id and active)
      or not exists (select 1 from public.user_follows where follower_id = s.owner_id and followee_id = actor and active)
    then raise exception 'Call unavailable'; end if;
    update public.rtc_sessions set status = case when p_action = 'accept' then 'active' else 'declined' end,
      expires_at = now() + interval '2 minutes' where id = p_id returning * into result;
  elsif p_action = 'publish' then
    if s.owner_id <> actor or s.peer_id is not null or s.status <> 'preparing' or s.expires_at <= now()
    then raise exception 'Session unavailable'; end if;
    update public.rtc_sessions set status = 'active', expires_at = now() + interval '2 minutes'
      where id = p_id returning * into result;
  elsif p_action = 'heartbeat' then
    if s.owner_id <> actor or s.status <> 'active' or s.expires_at <= now()
      or not private.rtc_can_view(s.owner_id, s.peer_id, s.status, s.expires_at)
      or (s.peer_id is not null and (
        not exists (select 1 from public.user_follows where follower_id = s.owner_id and followee_id = s.peer_id and active)
        or not exists (select 1 from public.user_follows where follower_id = s.peer_id and followee_id = s.owner_id and active)
      )) then raise exception 'Session unavailable'; end if;
    update public.rtc_sessions set expires_at = now() + interval '2 minutes' where id = p_id returning * into result;
  elsif p_action = 'end' then
    if actor <> s.owner_id and actor is distinct from s.peer_id then raise exception 'Not allowed'; end if;
    update public.rtc_sessions set status = 'ended', expires_at = now() where id = p_id returning * into result;
  else raise exception 'Invalid action';
  end if;
  return result;
end; $$;
revoke all on function private.update_toti_rtc(uuid, text) from public, anon;
grant execute on function private.update_toti_rtc(uuid, text) to authenticated;
create function public.update_toti_rtc(p_id uuid, p_action text)
returns public.rtc_sessions language sql security invoker set search_path = '' as $$
  select private.update_toti_rtc(p_id, p_action);
$$;
revoke all on function public.update_toti_rtc(uuid, text) from public, anon;
grant execute on function public.update_toti_rtc(uuid, text) to authenticated;

create function private.toti_rtc_token_claims(p_id uuid)
returns table (room_name text, can_publish boolean, session_kind text)
language sql stable security definer set search_path = '' as $$
  select 'toti-' || s.id::text,
    s.kind <> 'live' or s.owner_id = (select auth.uid()), s.kind
  from public.rtc_sessions s
  where s.id = p_id and s.expires_at > now() and s.status in ('preparing', 'ringing', 'active')
    and private.rtc_can_view(s.owner_id, s.peer_id, s.status, s.expires_at)
    and (s.peer_id is null or (s.status = 'active' or s.owner_id = (select auth.uid())))
    and (s.peer_id is null or (
      exists (select 1 from public.user_follows where follower_id = s.owner_id and followee_id = s.peer_id and active)
      and exists (select 1 from public.user_follows where follower_id = s.peer_id and followee_id = s.owner_id and active)
    ));
$$;
revoke all on function private.toti_rtc_token_claims(uuid) from public, anon;
grant execute on function private.toti_rtc_token_claims(uuid) to authenticated;
create function public.toti_rtc_token_claims(p_id uuid)
returns table (room_name text, can_publish boolean, session_kind text)
language sql stable security invoker set search_path = '' as $$
  select * from private.toti_rtc_token_claims(p_id);
$$;
revoke all on function public.toti_rtc_token_claims(uuid) from public, anon;
grant execute on function public.toti_rtc_token_claims(uuid) to authenticated;

alter publication supabase_realtime add table public.rtc_sessions;
