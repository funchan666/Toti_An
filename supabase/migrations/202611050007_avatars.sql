alter table public.user_profiles add column avatar_key text;
alter table public.user_profiles add constraint avatar_owned_path
  check (avatar_key is null or (split_part(avatar_key, '/', 1) = user_id::text and split_part(avatar_key, '/', 2) <> '' and split_part(avatar_key, '/', 3) = ''));

create table private.account_deletions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  started_at timestamptz not null default now()
);
revoke all on private.account_deletions from public, anon, authenticated;
create function private.account_can_upload() returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null
    and exists (select 1 from auth.users u where u.id = (select auth.uid()))
    and not exists (
    select 1 from private.account_deletions d where d.user_id = (select auth.uid())
  );
$$;
revoke all on function private.account_can_upload() from public, anon;
grant execute on function private.account_can_upload() to authenticated;

create function private.can_view_avatar(object_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null
    and exists (select 1 from auth.users u where u.id = (select auth.uid())) and (
    split_part(object_name, '/', 1) = (select auth.uid())::text
    or exists (
      select 1 from public.user_profiles p
      where p.avatar_key = object_name
        and p.birthday <= (current_date - interval '18 years')::date
        and not exists (select 1 from public.user_blocks b where
          (b.blocker_id = (select auth.uid()) and b.blocked_id = p.user_id) or
          (b.blocker_id = p.user_id and b.blocked_id = (select auth.uid())))
    )
  );
$$;
revoke all on function private.can_view_avatar(text) from public, anon;
grant execute on function private.can_view_avatar(text) to authenticated;
create policy toti_avatar_read on storage.objects for select to authenticated
  using (bucket_id = 'toti-avatars' and (select private.can_view_avatar(name)));
create policy toti_avatar_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'toti-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 1 and (select private.account_can_upload()));
create policy toti_avatar_delete on storage.objects for delete to authenticated
  using (bucket_id = 'toti-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy profiles_not_deleting on public.user_profiles as restrictive for update to authenticated
  using ((select private.account_can_upload())) with check ((select private.account_can_upload()));
create policy profile_insert_not_deleting on public.user_profiles as restrictive for insert to authenticated
  with check ((select private.account_can_upload()));

create function private.discover_toti_avatars() returns table(user_id uuid, avatar_key text)
language sql stable security definer set search_path = '' as $$
  select p.user_id, p.avatar_key from public.user_profiles p
  where (select auth.uid()) is not null and p.user_id <> (select auth.uid()) and p.avatar_key is not null
    and p.birthday <= (current_date - interval '18 years')::date
    and not exists (select 1 from public.user_blocks b where
      (b.blocker_id = (select auth.uid()) and b.blocked_id = p.user_id) or
      (b.blocker_id = p.user_id and b.blocked_id = (select auth.uid())));
$$;
revoke all on function private.discover_toti_avatars() from public, anon;
grant execute on function private.discover_toti_avatars() to authenticated;
create function public.discover_toti_avatars() returns table(user_id uuid, avatar_key text)
language sql stable security invoker set search_path = '' as $$ select * from private.discover_toti_avatars(); $$;
revoke all on function public.discover_toti_avatars() from public, anon;
grant execute on function public.discover_toti_avatars() to authenticated;

create function private.begin_toti_account_deletion() returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null then raise exception 'Unauthorized' using errcode = 'P0001'; end if;
  insert into private.account_deletions(user_id) values (actor) on conflict do nothing;
end; $$;
revoke all on function private.begin_toti_account_deletion() from public, anon;
grant execute on function private.begin_toti_account_deletion() to authenticated;
create function public.begin_toti_account_deletion() returns void
language sql security invoker set search_path = '' as $$ select private.begin_toti_account_deletion(); $$;
revoke all on function public.begin_toti_account_deletion() from public, anon;
grant execute on function public.begin_toti_account_deletion() to authenticated;
