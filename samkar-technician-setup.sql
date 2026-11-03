-- SAMKAR Network Solutions: technician roster and job assignments.
-- Run this as a NEW query in Supabase SQL Editor. It does not drop existing data.
-- Requires the existing user_roles table and public.is_samkar_admin() function
-- created by the current SAMKAR billing setup SQL.

create table if not exists public.technicians (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(trim(full_name)) between 2 and 120),
  phone text not null check (length(trim(phone)) between 7 and 25),
  service_area text not null check (length(trim(service_area)) between 2 and 120),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists technicians_active_name_idx
  on public.technicians (is_active, full_name);

-- Add assignment fields to the existing requests table without replacing it.
alter table public.service_requests
  add column if not exists technician_id uuid references public.technicians(id) on delete set null;

alter table public.service_requests
  add column if not exists scheduled_for timestamptz;

create index if not exists service_requests_technician_id_idx
  on public.service_requests (technician_id);
create index if not exists service_requests_scheduled_for_idx
  on public.service_requests (scheduled_for);

alter table public.technicians enable row level security;

drop policy if exists "SAMKAR admins manage technicians" on public.technicians;
create policy "SAMKAR admins manage technicians"
  on public.technicians
  for all
  to authenticated
  using (public.is_samkar_admin())
  with check (public.is_samkar_admin());

grant select, insert, update, delete on public.technicians to authenticated;

-- Existing service_requests RLS policies are deliberately left unchanged.
-- The admin dashboard uses the same admin-only request update access it already uses
-- to change request status. If that existing policy is not admin-only, review it
-- separately rather than disabling Row Level Security.
