-- RX Flooring - run once in Supabase SQL Editor
-- https://supabase.com/dashboard/project/xddnrxxlkwlpowieufjf/sql/new

-- ---------------------------------------------------------------------------
-- assessment_requests (public booking form → manager inbox)
-- ---------------------------------------------------------------------------
create table if not exists public.assessment_requests (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  name text not null,
  phone text not null,
  address text not null,
  preferred_date date not null,
  preferred_window text not null,
  notes text,
  services text[] not null default '{}',
  status text not null default 'new'
    check (status in ('new', 'contacted', 'scheduled', 'done', 'closed'))
);

-- Existing projects created before services existed:
alter table public.assessment_requests
  add column if not exists services text[] not null default '{}';

create index if not exists assessment_requests_created_at_idx
  on public.assessment_requests (created_at desc);
create index if not exists assessment_requests_status_idx
  on public.assessment_requests (status);

-- ---------------------------------------------------------------------------
-- jobs + photos (manager upserts later)
-- ---------------------------------------------------------------------------
create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  title text not null,
  address text,
  assessment_request_id uuid references public.assessment_requests (id) on delete set null,
  status text not null default 'planned'
    check (status in ('planned', 'in_progress', 'complete', 'archived')),
  notes text
);

create index if not exists jobs_created_at_idx on public.jobs (created_at desc);

create table if not exists public.job_photos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  storage_path text not null,
  caption text,
  sort_order int not null default 0
);

create index if not exists job_photos_job_id_idx on public.job_photos (job_id);

-- ---------------------------------------------------------------------------
-- updated_at helper
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists assessment_requests_set_updated_at on public.assessment_requests;
create trigger assessment_requests_set_updated_at
  before update on public.assessment_requests
  for each row execute function public.set_updated_at();

drop trigger if exists jobs_set_updated_at on public.jobs;
create trigger jobs_set_updated_at
  before update on public.jobs
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Storage bucket for job photos (private; managers only)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('job-photos', 'job-photos', false)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Grants (Data API)
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

grant insert on table public.assessment_requests to anon;
grant select, update on table public.assessment_requests to authenticated;

grant select, insert, update, delete on table public.jobs to authenticated;
grant select, insert, update, delete on table public.job_photos to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.assessment_requests enable row level security;
alter table public.jobs enable row level security;
alter table public.job_photos enable row level security;

-- Public can submit a booking; cannot read anyone else's.
drop policy if exists "anon_insert_assessment_requests" on public.assessment_requests;
create policy "anon_insert_assessment_requests"
  on public.assessment_requests
  for insert
  to anon
  with check (true);

-- Authenticated managers can read / update bookings.
drop policy if exists "authenticated_select_assessment_requests" on public.assessment_requests;
create policy "authenticated_select_assessment_requests"
  on public.assessment_requests
  for select
  to authenticated
  using (true);

drop policy if exists "authenticated_update_assessment_requests" on public.assessment_requests;
create policy "authenticated_update_assessment_requests"
  on public.assessment_requests
  for update
  to authenticated
  using (true)
  with check (true);

-- Jobs
drop policy if exists "authenticated_all_jobs" on public.jobs;
create policy "authenticated_all_jobs"
  on public.jobs
  for all
  to authenticated
  using (true)
  with check (true);

-- Job photos metadata
drop policy if exists "authenticated_all_job_photos" on public.job_photos;
create policy "authenticated_all_job_photos"
  on public.job_photos
  for all
  to authenticated
  using (true)
  with check (true);

-- Storage policies
drop policy if exists "managers_read_job_photos" on storage.objects;
create policy "managers_read_job_photos"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'job-photos');

drop policy if exists "managers_insert_job_photos" on storage.objects;
create policy "managers_insert_job_photos"
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id = 'job-photos');

drop policy if exists "managers_update_job_photos" on storage.objects;
create policy "managers_update_job_photos"
  on storage.objects
  for update
  to authenticated
  using (bucket_id = 'job-photos')
  with check (bucket_id = 'job-photos');

drop policy if exists "managers_delete_job_photos" on storage.objects;
create policy "managers_delete_job_photos"
  on storage.objects
  for delete
  to authenticated
  using (bucket_id = 'job-photos');
