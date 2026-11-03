-- SAMKAR Network Solutions: network map feature storage and permissions
-- Run in the existing SAMKAR Supabase project, in SQL Editor.
-- Uses the existing public.is_samkar_admin() function from SAMKAR's admin setup.
-- Does not drop or modify existing client, billing, subscription, invoice, or request tables.

begin;

create table if not exists public.network_map_features (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 120),
  feature_type text not null check (
    feature_type in ('mast', 'equipment', 'installation', 'coverage', 'power_point', 'other')
  ),
  description text,
  power_value numeric,
  power_unit text,
  geometry jsonb not null,
  is_published boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint network_map_geometry_object check (
    jsonb_typeof(geometry) = 'object'
    and geometry ? 'type'
    and geometry ? 'coordinates'
  )
);

create index if not exists network_map_features_published_idx
  on public.network_map_features (is_published, feature_type);
create index if not exists network_map_features_created_at_idx
  on public.network_map_features (created_at desc);

alter table public.network_map_features enable row level security;

drop policy if exists "SAMKAR admins manage network map features"
  on public.network_map_features;
create policy "SAMKAR admins manage network map features"
  on public.network_map_features
  for all
  to authenticated
  using (public.is_samkar_admin())
  with check (public.is_samkar_admin());

drop policy if exists "Anyone can read published network map features"
  on public.network_map_features;
create policy "Anyone can read published network map features"
  on public.network_map_features
  for select
  to anon, authenticated
  using (is_published = true);

-- RLS policies remain the security boundary. Authenticated users receive table
-- privileges, but only admins pass the admin policy for write operations.
grant select on public.network_map_features to anon, authenticated;
grant insert, update, delete on public.network_map_features to authenticated;

commit;
