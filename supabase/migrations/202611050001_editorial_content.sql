-- Public editorial content only. Authenticated social interactions and private
-- user data will use separate tables and policies; no fabricated auth users.
create table public.editorial_profiles (
  id text primary key,
  sort_index integer not null unique,
  name text not null,
  country text not null,
  image_key text not null,
  bio text not null,
  region text not null,
  doorway text not null,
  interests jsonb not null,
  age integer not null,
  content_kind text not null default 'editorial' check (content_kind = 'editorial')
);
create table public.editorial_reels (
  id text primary key,
  original_index integer not null unique,
  display_index integer not null unique,
  author_id text not null references public.editorial_profiles(id),
  video_key text not null,
  thumbnail_key text not null,
  caption text not null
);
create table public.editorial_comments (
  id text primary key,
  sort_index integer not null unique,
  content_id text not null,
  author_id text not null references public.editorial_profiles(id),
  body text not null
);
create table public.editorial_rooms (
  id text primary key,
  sort_index integer not null unique,
  host_id text not null references public.editorial_profiles(id),
  cover_key text not null,
  content jsonb not null
);
create table public.editorial_moments (
  id text primary key,
  sort_index integer not null unique,
  author_id text not null references public.editorial_profiles(id),
  image_key text not null,
  content jsonb not null
);
create table public.editorial_catalog (
  category text not null,
  sort_index integer not null,
  content jsonb not null,
  primary key(category, sort_index)
);
create index editorial_comments_content_idx on public.editorial_comments(content_id, sort_index);
alter table public.editorial_profiles enable row level security;
alter table public.editorial_reels enable row level security;
alter table public.editorial_comments enable row level security;
alter table public.editorial_rooms enable row level security;
alter table public.editorial_moments enable row level security;
alter table public.editorial_catalog enable row level security;
grant usage on schema public to anon, authenticated;
grant select on public.editorial_profiles, public.editorial_reels, public.editorial_comments, public.editorial_rooms, public.editorial_moments, public.editorial_catalog to anon, authenticated;
create policy editorial_profiles_read on public.editorial_profiles for select to anon, authenticated using (true);
create policy editorial_reels_read on public.editorial_reels for select to anon, authenticated using (true);
create policy editorial_comments_read on public.editorial_comments for select to anon, authenticated using (true);
create policy editorial_rooms_read on public.editorial_rooms for select to anon, authenticated using (true);
create policy editorial_moments_read on public.editorial_moments for select to anon, authenticated using (true);
create policy editorial_catalog_read on public.editorial_catalog for select to anon, authenticated using (true);
