create table if not exists public.rfid_profiles (
    rfid_value text primary key,
    full_name text not null,
    course text,
    college text,
    last_checked_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

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
