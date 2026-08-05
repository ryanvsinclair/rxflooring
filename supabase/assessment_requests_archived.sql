-- Allow status = 'archived' on assessment_requests.
-- Run in SQL Editor:
-- https://supabase.com/dashboard/project/xddnrxxlkwlpowieufjf/sql/new

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
