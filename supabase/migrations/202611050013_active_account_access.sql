-- Reject new operations and reads after deletion begins, including while a JWT
-- issued before deletion is still within its validity period.
create policy messages_active_account on public.direct_messages as restrictive for select to authenticated
  using ((select private.account_can_upload()));
create policy comments_active_account on public.content_comments as restrictive for select to authenticated
  using ((select private.account_can_upload()));
create policy follows_active_account_select on public.user_follows as restrictive for select to authenticated
  using ((select private.account_can_upload()));
create policy follows_active_account_insert on public.user_follows as restrictive for insert to authenticated
  with check ((select private.account_can_upload()));
create policy follows_active_account_update on public.user_follows as restrictive for update to authenticated
  using ((select private.account_can_upload())) with check ((select private.account_can_upload()));
create policy blocks_active_account_select on public.user_blocks as restrictive for select to authenticated
  using ((select private.account_can_upload()));
create policy blocks_active_account_delete on public.user_blocks as restrictive for delete to authenticated
  using ((select private.account_can_upload()));
create policy likes_active_account_select on public.content_likes as restrictive for select to authenticated
  using ((select private.account_can_upload()));
create policy reports_active_account_insert on public.content_reports as restrictive for insert to authenticated
  with check ((select private.account_can_upload()));
create policy directory_active_account_select on public.directory_revision as restrictive for select to authenticated
  using ((select private.account_can_upload()));
create or replace function public.discover_toti_users()
returns table (user_id uuid, nickname text, gender text, country text, age integer)
language sql stable security invoker set search_path = ''
as $$ select * from private.discover_toti_users() where (select private.account_can_upload()); $$;
create or replace function public.discover_toti_avatars()
returns table (user_id uuid, avatar_key text)
language sql stable security invoker set search_path = ''
as $$ select * from private.discover_toti_avatars() where (select private.account_can_upload()); $$;
create or replace function public.send_toti_message(p_recipient uuid, p_body text, p_client_id text)
returns public.direct_messages language plpgsql security invoker set search_path = '' as $$
begin
  if not (select private.account_can_upload()) then raise exception 'Account unavailable' using errcode = 'P0001'; end if;
  return private.send_toti_message(p_recipient, p_body, p_client_id);
end; $$;
create or replace function public.block_toti_user(p_user uuid) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if not (select private.account_can_upload()) then raise exception 'Account unavailable' using errcode = 'P0001'; end if;
  perform private.block_toti_user(p_user);
end; $$;
