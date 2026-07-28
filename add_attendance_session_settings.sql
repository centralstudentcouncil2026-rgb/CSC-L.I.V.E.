-- Shared attendance session settings for the admin attendance checker.
-- Run this in the Supabase SQL Editor for the dashboard project.

create table if not exists public.attendance_settings (
    id integer primary key default 1,
    attendance_date date not null default current_date,
    duration_minutes integer not null default 480 check (duration_minutes > 0),
    opened_at timestamptz not null default now(),
    closes_at timestamptz not null default (now() + interval '480 minutes'),
    updated_by text,
    updated_by_name text,
    updated_at timestamptz not null default now(),
    check (id = 1)
);

update public.attendance_settings
set opened_at = now() - interval '1 day',
    closes_at = now() - interval '1 minute',
    updated_at = now()
where id = 1
  and closes_at > now();

alter table public.attendance_settings enable row level security;

grant select on public.attendance_settings to authenticated;
grant insert, update on public.attendance_settings to authenticated;

drop policy if exists "Dashboard users can read attendance settings" on public.attendance_settings;
create policy "Dashboard users can read attendance settings"
on public.attendance_settings
for select
to authenticated
using (public.app_is_dashboard_user());

drop policy if exists "Admins can manage attendance settings" on public.attendance_settings;
create policy "Admins can manage attendance settings"
on public.attendance_settings
for all
to authenticated
using (public.app_is_admin())
with check (public.app_is_admin());

do $$
begin
    alter publication supabase_realtime add table public.attendance_settings;
exception
    when duplicate_object then null;
    when undefined_object then null;
end $$;
