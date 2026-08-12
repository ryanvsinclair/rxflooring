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
    check (status in ('new', 'contacted', 'scheduled', 'done', 'closed', 'archived'))
);

-- Existing projects created before services existed:
alter table public.assessment_requests
  add column if not exists services text[] not null default '{}';

-- Existing projects: allow archived inbox status (past preferred_date).
-- Drops any status CHECK (name can vary) then recreates with archived.
do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on t.relnamespace = n.oid
    where n.nspname = 'public'
      and t.relname = 'assessment_requests'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%status%'
  loop
    execute format('alter table public.assessment_requests drop constraint %I', r.conname);
  end loop;
end $$;
alter table public.assessment_requests
  add constraint assessment_requests_status_check
  check (status in ('new', 'contacted', 'scheduled', 'done', 'closed', 'archived'));

create index if not exists assessment_requests_created_at_idx
  on public.assessment_requests (created_at desc);
create index if not exists assessment_requests_status_idx
  on public.assessment_requests (status);
create index if not exists assessment_requests_preferred_date_idx
  on public.assessment_requests (preferred_date);

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
  notes text,
  description text,
  prescribed text,
  completed_at timestamptz,
  published boolean not null default false
);

-- Existing projects created before prescription fields existed:
alter table public.jobs add column if not exists description text;
alter table public.jobs add column if not exists prescribed text;
alter table public.jobs add column if not exists completed_at timestamptz;
alter table public.jobs add column if not exists published boolean not null default false;

create index if not exists jobs_created_at_idx on public.jobs (created_at desc);
create index if not exists jobs_published_completed_at_idx
  on public.jobs (published, completed_at desc nulls last)
  where published = true;

create table if not exists public.job_photos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  storage_path text not null,
  caption text,
  sort_order int not null default 0,
  kind text not null default 'other'
    check (kind in ('before', 'after', 'other'))
);

alter table public.job_photos add column if not exists kind text not null default 'other';

create index if not exists job_photos_job_id_idx on public.job_photos (job_id);
create index if not exists job_photos_job_id_kind_idx on public.job_photos (job_id, kind);

-- ---------------------------------------------------------------------------
-- services catalog + job_services (see also supabase/services.sql)
-- ---------------------------------------------------------------------------
create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  slug text not null unique,
  title text not null,
  detail text,
  category text not null,
  category_label text not null,
  sort_order int not null default 0,
  active boolean not null default true
);

create index if not exists services_active_sort_idx
  on public.services (active, sort_order, title);

create table if not exists public.job_services (
  job_id uuid not null references public.jobs (id) on delete cascade,
  service_id uuid not null references public.services (id) on delete restrict,
  primary key (job_id, service_id)
);

create index if not exists job_services_service_id_idx
  on public.job_services (service_id);

insert into public.services (slug, title, detail, category, category_label, sort_order) values
  ('carpet',   'Carpet Installation',          'Wall-to-wall stretch-in and glue-down.',                         'flooring',    'Flooring',    10),
  ('stairs',   'Stair Wrapping & Runners',      'Carpet stair wrapping and stair runners, clean around every spindle.', 'flooring', 'Flooring', 20),
  ('seaming',  'Seaming, Repair & Restretching','Carpet seaming, repair, and power-stretch restretching.',       'flooring',    'Flooring',    30),
  ('lvp',      'LVP / LVT Installation',        'Luxury vinyl plank and luxury vinyl tile.',                     'flooring',    'Flooring',    40),
  ('laminate', 'Laminate Installation',         'Laminate flooring, measured and laid right.',                   'flooring',    'Flooring',    50),
  ('hardwood', 'Hardwood Installation',         'Nail-down, glue-down, and floating hardwood.',                  'flooring',    'Flooring',    60),
  ('refinish', 'Sanding & Refinishing',         'Hardwood sanding and refinishing that restores the grain.',     'flooring',    'Flooring',    70),
  ('tile',     'Ceramic & Porcelain Tile',      'Tile installation with clean lines and correct prep.',          'flooring',    'Flooring',    80),
  ('subfloor', 'Subfloor Prep & Repair',        'Leveling, repair, and prep before the finish floor goes down.', 'flooring',    'Flooring',    90),
  ('removal',  'Flooring Removal & Disposal',   'Old flooring torn out and hauled away.',                        'flooring',    'Flooring',   100),
  ('painting', 'Interior Painting',             'Clean interior paint work that finishes the room.',             'renovation',  'Renovation', 110),
  ('demo',     'Interior Demolition',           'Strip-outs and interior demolition, contained and scheduled.',  'renovation',  'Renovation', 120),
  ('junk',     'Junk Removal',                  'Debris haul-away so the site is clear when we leave.',          'renovation',  'Renovation', 130),
  ('pm',       'Project Management',            'Measuring, scheduling, multi-trade coordination, and warranty.','renovation',  'Renovation', 140),
  ('lawn',     'Lawn Care',                     'Mowing, edging, and seasonal lawn maintenance.',                'landscaping', 'Landscaping',150),
  ('garden',   'Garden & Beds',                 'Planting, mulching, and bed refresh.',                          'landscaping', 'Landscaping',160),
  ('yard',     'Yard Cleanup',                  'Brush clearing, leaf cleanup, and seasonal yard work.',         'landscaping', 'Landscaping',170),
  ('snow',     'Snow Clearing',                 'Driveways, walkways, and entrances cleared after every storm.', 'snow',        'Snow',       180)
on conflict (slug) do update set
  title = excluded.title,
  detail = excluded.detail,
  category = excluded.category,
  category_label = excluded.category_label,
  sort_order = excluded.sort_order,
  active = true;

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
-- Storage bucket for job photos (public read via CDN URL; write = managers)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('job-photos', 'job-photos', true)
on conflict (id) do update set public = excluded.public;

-- ---------------------------------------------------------------------------
-- Grants (Data API)
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

grant insert on table public.assessment_requests to anon;
grant select, update on table public.assessment_requests to authenticated;

grant select on table public.jobs to anon;
grant select on table public.job_photos to anon;
grant select on table public.services to anon, authenticated;
grant select on table public.job_services to anon, authenticated;
grant select, insert, update, delete on table public.jobs to authenticated;
grant select, insert, update, delete on table public.job_photos to authenticated;
grant select, insert, update, delete on table public.services to authenticated;
grant select, insert, update, delete on table public.job_services to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.assessment_requests enable row level security;
alter table public.jobs enable row level security;
alter table public.job_photos enable row level security;
alter table public.services enable row level security;
alter table public.job_services enable row level security;

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

-- Jobs: public can read published prescriptions; managers manage all.
drop policy if exists "anon_select_published_jobs" on public.jobs;
create policy "anon_select_published_jobs"
  on public.jobs
  for select
  to anon
  using (published = true);

drop policy if exists "authenticated_all_jobs" on public.jobs;
create policy "authenticated_all_jobs"
  on public.jobs
  for all
  to authenticated
  using (true)
  with check (true);

-- Job photos metadata: public can read photos of published jobs.
drop policy if exists "anon_select_photos_of_published_jobs" on public.job_photos;
create policy "anon_select_photos_of_published_jobs"
  on public.job_photos
  for select
  to anon
  using (
    exists (
      select 1
      from public.jobs j
      where j.id = job_photos.job_id
        and j.published = true
    )
  );

drop policy if exists "authenticated_all_job_photos" on public.job_photos;
create policy "authenticated_all_job_photos"
  on public.job_photos
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists "anon_select_active_services" on public.services;
create policy "anon_select_active_services"
  on public.services
  for select
  to anon
  using (active = true);

drop policy if exists "authenticated_all_services" on public.services;
create policy "authenticated_all_services"
  on public.services
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists "anon_select_job_services_of_published_jobs" on public.job_services;
create policy "anon_select_job_services_of_published_jobs"
  on public.job_services
  for select
  to anon
  using (
    exists (
      select 1
      from public.jobs j
      where j.id = job_services.job_id
        and j.published = true
    )
  );

drop policy if exists "authenticated_all_job_services" on public.job_services;
create policy "authenticated_all_job_services"
  on public.job_services
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
