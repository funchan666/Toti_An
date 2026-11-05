-- Public revision signal contains no user profile or message contents.
create table public.directory_revision (
  id boolean primary key default true check (id),
  changed_at timestamptz not null default now()
);
insert into public.directory_revision(id) values(true);
alter table public.directory_revision enable row level security;
grant select on public.directory_revision to authenticated;
create policy directory_revision_read on public.directory_revision for select to authenticated using (true);
create function private.mark_directory_changed() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.directory_revision set changed_at = clock_timestamp() where id = true;
  return null;
end; $$;
revoke all on function private.mark_directory_changed() from public, anon, authenticated;
create trigger directory_changed after insert or update or delete on public.user_profiles
for each statement execute function private.mark_directory_changed();
alter publication supabase_realtime add table public.directory_revision;
