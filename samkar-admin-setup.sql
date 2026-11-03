-- SAMKAR Network Solutions: secure administrator access
-- Run in Supabase Dashboard > SQL Editor as the project owner.
-- This does NOT change customer authentication or registration.

-- 1) This table contains administrator assignments only.
-- Customers cannot insert, update, or delete their own role.
create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role = 'admin'),
  created_at timestamptz not null default now()
);

alter table public.user_roles enable row level security;
revoke all on table public.user_roles from anon, authenticated;
grant select on table public.user_roles to authenticated;

drop policy if exists "Users can view their own admin role" on public.user_roles;
create policy "Users can view their own admin role"
  on public.user_roles
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- SECURITY DEFINER allows the policy helper to check the role table safely
-- without requiring administrators to read every row in user_roles.
create or replace function public.is_samkar_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles as ur
    where ur.user_id = (select auth.uid())
      and ur.role = 'admin'
  );
$$;

revoke all on function public.is_samkar_admin() from public;
grant execute on function public.is_samkar_admin() to authenticated;

-- 2) Allow administrators to view customer profile details needed for requests.
-- Existing customer policies remain in place; this adds an admin-only SELECT path.
grant select on table public.profiles to authenticated;
drop policy if exists "Admins can view customer profiles" on public.profiles;
create policy "Admins can view customer profiles"
  on public.profiles
  for select
  to authenticated
  using ((select public.is_samkar_admin()));

-- 3) Secure request access. Drop the customer policies created by the earlier
-- SAMKAR service-requests SQL, then replace them with stricter policies.
drop policy if exists "Customers can view their own requests" on public.service_requests;
drop policy if exists "Customers can submit their own requests" on public.service_requests;
drop policy if exists "Customers and admins can view requests" on public.service_requests;
drop policy if exists "Customers can submit pending requests" on public.service_requests;
drop policy if exists "Admins can update request status" on public.service_requests;

create policy "Customers and admins can view requests"
  on public.service_requests
  for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or (select public.is_samkar_admin())
  );

create policy "Customers can submit pending requests"
  on public.service_requests
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and status = 'pending'
  );

create policy "Admins can update request status"
  on public.service_requests
  for update
  to authenticated
  using ((select public.is_samkar_admin()))
  with check ((select public.is_samkar_admin()));

-- Customers can create/read requests. Authenticated users may only UPDATE the
-- status column, and RLS restricts that update to administrators.
grant select, insert on table public.service_requests to authenticated;
revoke update on table public.service_requests from authenticated;
grant update (status) on table public.service_requests to authenticated;

-- Keep updated_at current when an administrator changes a status.
create or replace function public.set_service_requests_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_service_requests_updated_at on public.service_requests;
create trigger set_service_requests_updated_at
before update on public.service_requests
for each row execute function public.set_service_requests_updated_at();

-- 4) IMPORTANT: assign the first administrator manually after running this file.
-- In Supabase > Authentication > Users, copy the UUID for YOUR own account.
-- Then run this separately, replacing the placeholder with that UUID:
--
-- insert into public.user_roles (user_id, role)
-- values ('PASTE-YOUR-ACCOUNT-UUID-HERE', 'admin')
-- on conflict (user_id) do update set role = excluded.role;
--
-- Never put a service_role key in website JavaScript, HTML, or CSS.
