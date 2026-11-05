create table public.content_likes (
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id text not null check (char_length(content_id) between 1 and 300),
  active boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, content_id)
);
alter table public.content_likes enable row level security;
grant select, insert, update on public.content_likes to authenticated;
create policy likes_owner_select on public.content_likes for select to authenticated using (user_id = (select auth.uid()));
create policy likes_owner_insert on public.content_likes for insert to authenticated with check (user_id = (select auth.uid()));
create policy likes_owner_update on public.content_likes for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy likes_not_deleting_insert on public.content_likes as restrictive for insert to authenticated with check ((select private.account_can_upload()));
create policy likes_not_deleting_update on public.content_likes as restrictive for update to authenticated using ((select private.account_can_upload())) with check ((select private.account_can_upload()));
alter publication supabase_realtime add table public.content_likes;
