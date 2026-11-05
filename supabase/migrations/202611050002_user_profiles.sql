-- User-owned profile fields. The email identity is a real Auth user;
-- editorial profiles are separate and never receive login credentials.
create table public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null check (char_length(nickname) between 1 and 40),
  gender text not null check (char_length(gender) between 1 and 40),
  birthday date not null,
  country text not null check (char_length(country) between 1 and 80),
  updated_at timestamptz not null default now()
);
alter table public.user_profiles enable row level security;
grant select, insert, update, delete on public.user_profiles to authenticated;
create policy profile_owner_select on public.user_profiles for select to authenticated using (user_id = (select auth.uid()));
create policy profile_owner_insert on public.user_profiles for insert to authenticated with check (user_id = (select auth.uid()));
create policy profile_owner_update on public.user_profiles for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy profile_owner_delete on public.user_profiles for delete to authenticated using (user_id = (select auth.uid()));
