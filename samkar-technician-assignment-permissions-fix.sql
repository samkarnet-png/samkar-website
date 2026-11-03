-- SAMKAR Network Solutions: targeted permission fix for technician assignments.
-- Run this in Supabase SQL Editor as the project database owner.
-- This does NOT disable RLS and does NOT change any existing RLS policies.
-- It only grants authenticated users column-level access to the new assignment fields.
-- Existing row-level policies must continue to restrict which rows each user may update.

begin;

-- The assignment page needs to read these fields.
grant select (technician_id, scheduled_for)
  on table public.service_requests to authenticated;

-- The assignment page needs to update only these new fields.
-- This does not grant UPDATE permission on other service request columns.
grant update (technician_id, scheduled_for)
  on table public.service_requests to authenticated;

commit;
