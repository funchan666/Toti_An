create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  target_id text not null check (char_length(target_id) between 1 and 300),
  subject_id text check (subject_id is null or char_length(subject_id) <= 100),
  reason text not null check (reason in ('Harassment', 'Sexual content', 'Violence or threats', 'Spam or scam', 'Other')),
  created_at timestamptz not null default now()
);
create index content_reports_reporter_idx on public.content_reports(reporter_id, created_at);
alter table public.content_reports enable row level security;
grant insert on public.content_reports to authenticated;
create policy report_owner_insert on public.content_reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));
