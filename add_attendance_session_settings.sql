-- Shared attendance session settings for the admin attendance checker.
-- Run this in the Supabase SQL Editor for the dashboard project.

create table if not exists public.attendance_settings (
    id integer primary key default 1,
    attendance_date date not null default current_date,
    duration_minutes integer not null default 480 check (duration_minutes > 0),
    opened_at timestamptz not null default now(),
    closes_at timestamptz not null default (now() + interval '480 minutes'),
    session_type text not null default 'regular',
    session_title text not null default 'Regular Day',
    point_settings jsonb not null default '{
        "opening_program": {
            "registered_player_points": 5,
            "faculty_formula_base": 100,
            "department_chair_formula_base": 100,
            "dean_points": 50,
            "student_from_college_points": 1
        },
        "sunday_devotional": {
            "faculty_points": 5,
            "sponsor_points": 5,
            "student_player_points": 2
        },
        "game_attendance": {
            "sponsor_points": 15
        }
    }'::jsonb,
    updated_by text,
    updated_by_name text,
    updated_at timestamptz not null default now(),
    check (id = 1)
);

alter table public.attendance_settings
    add column if not exists session_type text not null default 'regular',
    add column if not exists session_title text not null default 'Regular Day',
    add column if not exists point_settings jsonb not null default '{
        "opening_program": {
            "registered_player_points": 5,
            "faculty_formula_base": 100,
            "department_chair_formula_base": 100,
            "dean_points": 50,
            "student_from_college_points": 1
        },
        "sunday_devotional": {
            "faculty_points": 5,
            "sponsor_points": 5,
            "student_player_points": 2
        },
        "game_attendance": {
            "sponsor_points": 15
        }
    }'::jsonb;

alter table public.attendance
    add column if not exists attendance_session_type text not null default 'regular',
    add column if not exists attendance_session_title text not null default 'Regular Day',
    add column if not exists attendance_point_settings jsonb not null default '{
        "opening_program": {
            "registered_player_points": 5,
            "faculty_formula_base": 100,
            "department_chair_formula_base": 100,
            "dean_points": 50,
            "student_from_college_points": 1
        },
        "sunday_devotional": {
            "faculty_points": 5,
            "sponsor_points": 5,
            "student_player_points": 2
        },
        "game_attendance": {
            "sponsor_points": 15
        }
    }'::jsonb;

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
