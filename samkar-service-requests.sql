-- SAMKAR Network Solutions: customer service requests
-- Run this in Supabase Dashboard > SQL Editor > New query.

create table if not exists public.service_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_type text not null check (
    request_type in (
      'New installation',
      'Internet connection problem',
      'Slow internet',
      'Billing question',
      'Other'
    )
  ),
  phone text not null,
  details text not null,
  service_location text not null check (
    service_location in ('Nyahururu', 'Maralal', 'Ol Kalou', 'MA4')
  ),
  package_name text,
  speed_mbps integer check (speed_mbps is null or speed_mbps > 0),
  monthly_price_kes numeric(10,2) check (
    monthly_price_kes is null or monthly_price_kes >= 0
  ),
  status text not null default 'pending' check (
    status in ('pending', 'approved', 'in_progress', 'completed', 'rejected')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists service_requests_user_created_idx
  on public.service_requests (user_id, created_at desc);

alter table public.service_requests enable row level security;

drop policy if exists "Customers can view their own requests"
  on public.service_requests;
create policy "Customers can view their own requests"
  on public.service_requests
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Customers can submit their own requests"
  on public.service_requests;
create policy "Customers can submit their own requests"
  on public.service_requests
  for insert
  to authenticated
  with check (auth.uid() = user_id);

grant select, insert on public.service_requests to authenticated;
