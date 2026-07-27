create table if not exists public.rfid_profiles (
    rfid_value text primary key,
    student_id text,
    full_name text not null,
    course text,
    college text,
    last_checked_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

alter table if exists public.rfid_profiles
    add column if not exists student_id text;

create index if not exists rfid_profiles_student_id_idx
on public.rfid_profiles (student_id);

alter table public.rfid_profiles enable row level security;

drop policy if exists "Allow public read rfid profiles" on public.rfid_profiles;
create policy "Allow public read rfid profiles"
on public.rfid_profiles
for select
to anon, authenticated
using (true);

drop policy if exists "Allow public upsert rfid profiles" on public.rfid_profiles;
create policy "Allow public upsert rfid profiles"
on public.rfid_profiles
for insert
to anon, authenticated
with check (true);

drop policy if exists "Allow public update rfid profiles" on public.rfid_profiles;
create policy "Allow public update rfid profiles"
on public.rfid_profiles
for update
to anon, authenticated
using (true)
with check (true);
