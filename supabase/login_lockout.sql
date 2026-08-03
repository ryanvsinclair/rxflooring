-- RX Flooring - password lockout after 3 failures + email unlock
-- 1) Run this in the SQL Editor
-- 2) Enable the hook: Authentication → Hooks → Password Verification
--    → Postgres function → public.hook_password_verification_attempt
-- 3) Add redirect URL: Authentication → URL Configuration
--    → http://localhost:3000/manager/  and your production /manager/

create table if not exists public.manager_login_guard (
  user_id uuid primary key references auth.users (id) on delete cascade,
  failed_attempts int not null default 0,
  locked_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.manager_login_guard enable row level security;

-- No direct client access to the guard table
revoke all on table public.manager_login_guard from anon, authenticated, public;
grant all on table public.manager_login_guard to supabase_auth_admin;
grant delete on table public.manager_login_guard to authenticated;

-- Authenticated users may only clear their own lock (after magic-link verify)
drop policy if exists "users_clear_own_lock" on public.manager_login_guard;
create policy "users_clear_own_lock"
  on public.manager_login_guard
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.clear_manager_login_lock()
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  delete from public.manager_login_guard
  where user_id = (select auth.uid());
end;
$$;

grant execute on function public.clear_manager_login_lock() to authenticated;
revoke execute on function public.clear_manager_login_lock() from anon, public;

-- Auth Hook: runs on every password check (including direct API calls)
create or replace function public.hook_password_verification_attempt(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (event->>'user_id')::uuid;
  is_valid boolean := coalesce((event->>'valid')::boolean, false);
  attempts int := 0;
  locked timestamptz;
begin
  select g.failed_attempts, g.locked_at
    into attempts, locked
  from public.manager_login_guard g
  where g.user_id = uid;

  -- Already locked: block password login until email verify unlocks
  if locked is not null then
    return jsonb_build_object(
      'decision', 'reject',
      'message', 'LOCKED: Check your email for a sign-in link to verify and unlock.',
      'should_logout_user', false
    );
  end if;

  -- Correct password and not locked → reset counter
  if is_valid then
    delete from public.manager_login_guard where user_id = uid;
    return jsonb_build_object('decision', 'continue');
  end if;

  -- Failed password attempt
  insert into public.manager_login_guard as g (user_id, failed_attempts, locked_at, updated_at)
  values (uid, 1, null, now())
  on conflict (user_id) do update
    set
      failed_attempts = g.failed_attempts + 1,
      updated_at = now(),
      locked_at = case
        when g.failed_attempts + 1 >= 3 then now()
        else null
      end
  returning g.failed_attempts, g.locked_at into attempts, locked;

  if locked is not null then
    return jsonb_build_object(
      'decision', 'reject',
      'message', 'LOCKED: Check your email for a sign-in link to verify and unlock.',
      'should_logout_user', false
    );
  end if;

  -- Under threshold: let Auth return normal invalid-credentials behavior
  return jsonb_build_object('decision', 'continue');
end;
$$;

grant execute on function public.hook_password_verification_attempt(jsonb) to supabase_auth_admin;
revoke execute on function public.hook_password_verification_attempt(jsonb) from anon, authenticated, public;
