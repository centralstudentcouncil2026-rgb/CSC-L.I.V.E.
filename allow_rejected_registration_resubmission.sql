-- Allow rejected CSC Cup registrations to be replaced by a fresh public form submission.
-- Run this in the Supabase SQL Editor for the project used by the registration form.

grant select, insert, update on public.participants to anon, authenticated;

drop policy if exists "Public can read participant registrations for resubmission" on public.participants;
create policy "Public can read participant registrations for resubmission"
on public.participants
for select
to anon, authenticated
using (true);

drop policy if exists "Public can submit participant registrations" on public.participants;
create policy "Public can submit participant registrations"
on public.participants
for insert
to anon, authenticated
with check (
    lower(coalesce(status, 'pending')) = 'pending'
);

drop policy if exists "Public can resubmit rejected participant registrations" on public.participants;
create policy "Public can resubmit rejected participant registrations"
on public.participants
for update
to anon, authenticated
using (lower(coalesce(status, 'pending')) = 'rejected')
with check (lower(coalesce(status, 'pending')) = 'pending');

drop policy if exists "Public can upload participant documents" on storage.objects;
create policy "Public can upload participant documents"
on storage.objects
for insert
to anon, authenticated
with check (
    bucket_id = 'participant-documents'
    and name like 'participants/%'
);

drop policy if exists "Public can update participant documents" on storage.objects;
create policy "Public can update participant documents"
on storage.objects
for update
to anon, authenticated
using (
    bucket_id = 'participant-documents'
    and name like 'participants/%'
)
with check (
    bucket_id = 'participant-documents'
    and name like 'participants/%'
);
