-- RX Flooring — services catalog + job links
-- Run in Supabase SQL Editor (safe to re-run).
-- https://supabase.com/dashboard/project/xddnrxxlkwlpowieufjf/sql/new

-- ---------------------------------------------------------------------------
-- services (catalog)
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

-- ---------------------------------------------------------------------------
-- job_services (which services a job provided)
-- ---------------------------------------------------------------------------
create table if not exists public.job_services (
  job_id uuid not null references public.jobs (id) on delete cascade,
  service_id uuid not null references public.services (id) on delete restrict,
  primary key (job_id, service_id)
);

create index if not exists job_services_service_id_idx
  on public.job_services (service_id);

-- ---------------------------------------------------------------------------
-- Seed catalog (matches public site SERVICES list)
-- ---------------------------------------------------------------------------
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
-- Grants
-- ---------------------------------------------------------------------------
grant select on table public.services to anon, authenticated;
grant select, insert, update, delete on table public.services to authenticated;

grant select on table public.job_services to anon, authenticated;
grant select, insert, update, delete on table public.job_services to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.services enable row level security;
alter table public.job_services enable row level security;

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

-- Public can see service links for published jobs; managers manage all.
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
