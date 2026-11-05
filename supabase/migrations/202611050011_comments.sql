create table public.content_comments (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  content_id text not null check (char_length(content_id) between 1 and 300),
  client_id text not null check (char_length(client_id) between 16 and 64),
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  unique (author_id, client_id)
);
create index content_comments_content_idx on public.content_comments(content_id, created_at, id);
create index content_comments_author_idx on public.content_comments(author_id);
alter table public.content_comments enable row level security;
grant select on public.content_comments to authenticated;
create function private.comment_is_visible(author uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and not exists (
    select 1 from public.user_blocks b where
      (b.blocker_id = (select auth.uid()) and b.blocked_id = author) or
      (b.blocker_id = author and b.blocked_id = (select auth.uid()))
  );
$$;
revoke all on function private.comment_is_visible(uuid) from public, anon;
grant execute on function private.comment_is_visible(uuid) to authenticated;
create policy comments_visible on public.content_comments for select to authenticated
  using ((select private.comment_is_visible(author_id)));
create function private.send_toti_comment(p_content text, p_body text, p_client_id text)
returns public.content_comments language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.content_comments;
begin
  if actor is null or p_content is null or char_length(p_content) not between 1 and 300
     or p_body is null or char_length(trim(p_body)) not between 1 and 2000
     or p_client_id is null or char_length(p_client_id) not between 16 and 64
     or not exists (select 1 from auth.users where id = actor)
     or exists (select 1 from private.account_deletions where user_id = actor) then
    raise exception 'Comment could not be sent' using errcode = 'P0001';
  end if;
  insert into public.content_comments(author_id, content_id, body, client_id)
    values (actor, p_content, trim(p_body), p_client_id)
    on conflict (author_id, client_id) do nothing returning * into result;
  if result.id is null then
    select * into result from public.content_comments where author_id = actor and client_id = p_client_id and content_id = p_content and body = trim(p_body);
    if result.id is null then raise exception 'Comment could not be sent' using errcode = 'P0001'; end if;
  end if;
  return result;
end; $$;
revoke all on function private.send_toti_comment(text,text,text) from public, anon;
grant execute on function private.send_toti_comment(text,text,text) to authenticated;
create function public.send_toti_comment(p_content text, p_body text, p_client_id text)
returns public.content_comments language sql security invoker set search_path = ''
as $$ select private.send_toti_comment(p_content, p_body, p_client_id); $$;
revoke all on function public.send_toti_comment(text,text,text) from public, anon;
grant execute on function public.send_toti_comment(text,text,text) to authenticated;
alter publication supabase_realtime add table public.content_comments;
