-- Shared attendance session settings for the admin attendance checker.
-- Run this in the Supabase SQL Editor for the dashboard project.

create table if not exists public.attendance_settings (
    id integer primary key default 1,
    attendance_date date not null default current_date,
    duration_minutes integer not null default 480 check (duration_minutes > 0),
    opened_at timestamptz not null default now(),
    closes_at timestamptz not null default (now() + interval '480 minutes'),
    session_type text not null default 'regular',
    session_title text not null default 'Regular Attendance',
    point_settings jsonb not null default '{
        "parameters": {
            "registered_player_points": 5,
            "faculty_formula_base": 100,
            "department_chair_formula_base": 100,
            "dean_points": 50,
            "student_from_college_points": 1,
            "faculty_points": 5,
            "sponsor_points": 5,
            "student_player_points": 2,
            "sponsor_game_attendance_points": 15,
            "college_totals": {}
        },
        "opening_program": {
            "registered_player_points": 5,
            "faculty_formula_base": 100,
            "department_chair_formula_base": 100,
            "dean_points": 50,
            "student_from_college_points": 1,
            "college_totals": {}
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
    add column if not exists session_title text not null default 'Regular Attendance',
    add column if not exists point_settings jsonb not null default '{
        "parameters": {
            "registered_player_points": 5,
            "faculty_formula_base": 100,
            "department_chair_formula_base": 100,
            "dean_points": 50,
            "student_from_college_points": 1,
            "faculty_points": 5,
            "sponsor_points": 5,
            "student_player_points": 2,
            "sponsor_game_attendance_points": 15,
            "college_totals": {}
        },
        "opening_program": {
            "registered_player_points": 5,
            "faculty_formula_base": 100,
            "department_chair_formula_base": 100,
            "dean_points": 50,
            "student_from_college_points": 1,
            "college_totals": {}
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

alter table public.attendance_settings
    alter column session_title set default 'Regular Attendance';

alter table public.attendance
    add column if not exists attendance_session_type text not null default 'regular',
    add column if not exists attendance_session_title text not null default 'Regular Attendance',
    add column if not exists attendance_point_settings jsonb not null default '{
        "parameters": {
            "registered_player_points": 5,
            "faculty_formula_base": 100,
            "department_chair_formula_base": 100,
            "dean_points": 50,
            "student_from_college_points": 1,
            "faculty_points": 5,
            "sponsor_points": 5,
            "student_player_points": 2,
            "sponsor_game_attendance_points": 15,
            "college_totals": {}
        },
        "opening_program": {
            "registered_player_points": 5,
            "faculty_formula_base": 100,
            "department_chair_formula_base": 100,
            "dean_points": 50,
            "student_from_college_points": 1,
            "college_totals": {}
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
    alter column attendance_session_title set default 'Regular Attendance';

update public.attendance_settings
set session_title = 'Regular Attendance'
where session_title = 'Regular Day';

update public.attendance
set attendance_session_title = 'Regular Attendance'
where attendance_session_title = 'Regular Day';

update public.attendance_settings
set point_settings = jsonb_set(
    coalesce(point_settings, '{}'::jsonb),
    '{opening_program,college_totals}',
    coalesce(point_settings #> '{opening_program,college_totals}', '{}'::jsonb),
    true
);

update public.attendance_settings
set point_settings = jsonb_set(
    coalesce(point_settings, '{}'::jsonb),
    '{parameters}',
    jsonb_build_object(
        'registered_player_points', coalesce(point_settings #> '{parameters,registered_player_points}', point_settings #> '{opening_program,registered_player_points}', '5'::jsonb),
        'faculty_formula_base', '100'::jsonb,
        'department_chair_formula_base', '100'::jsonb,
        'dean_points', coalesce(point_settings #> '{parameters,dean_points}', point_settings #> '{opening_program,dean_points}', '50'::jsonb),
        'student_from_college_points', coalesce(point_settings #> '{parameters,student_from_college_points}', point_settings #> '{opening_program,student_from_college_points}', '1'::jsonb),
        'faculty_points', coalesce(point_settings #> '{parameters,faculty_points}', point_settings #> '{sunday_devotional,faculty_points}', '5'::jsonb),
        'sponsor_points', coalesce(point_settings #> '{parameters,sponsor_points}', point_settings #> '{sunday_devotional,sponsor_points}', '5'::jsonb),
        'student_player_points', coalesce(point_settings #> '{parameters,student_player_points}', point_settings #> '{sunday_devotional,student_player_points}', '2'::jsonb),
        'sponsor_game_attendance_points', coalesce(point_settings #> '{parameters,sponsor_game_attendance_points}', point_settings #> '{game_attendance,sponsor_points}', '15'::jsonb),
        'college_totals', coalesce(point_settings #> '{parameters,college_totals}', point_settings #> '{opening_program,college_totals}', '{}'::jsonb)
    ),
    true
);

update public.attendance
set attendance_point_settings = jsonb_set(
    coalesce(attendance_point_settings, '{}'::jsonb),
    '{opening_program,college_totals}',
    coalesce(attendance_point_settings #> '{opening_program,college_totals}', '{}'::jsonb),
    true
);

update public.attendance
set attendance_point_settings = jsonb_set(
    coalesce(attendance_point_settings, '{}'::jsonb),
    '{parameters}',
    jsonb_build_object(
        'registered_player_points', coalesce(attendance_point_settings #> '{parameters,registered_player_points}', attendance_point_settings #> '{opening_program,registered_player_points}', '5'::jsonb),
        'faculty_formula_base', '100'::jsonb,
        'department_chair_formula_base', '100'::jsonb,
        'dean_points', coalesce(attendance_point_settings #> '{parameters,dean_points}', attendance_point_settings #> '{opening_program,dean_points}', '50'::jsonb),
        'student_from_college_points', coalesce(attendance_point_settings #> '{parameters,student_from_college_points}', attendance_point_settings #> '{opening_program,student_from_college_points}', '1'::jsonb),
        'faculty_points', coalesce(attendance_point_settings #> '{parameters,faculty_points}', attendance_point_settings #> '{sunday_devotional,faculty_points}', '5'::jsonb),
        'sponsor_points', coalesce(attendance_point_settings #> '{parameters,sponsor_points}', attendance_point_settings #> '{sunday_devotional,sponsor_points}', '5'::jsonb),
        'student_player_points', coalesce(attendance_point_settings #> '{parameters,student_player_points}', attendance_point_settings #> '{sunday_devotional,student_player_points}', '2'::jsonb),
        'sponsor_game_attendance_points', coalesce(attendance_point_settings #> '{parameters,sponsor_game_attendance_points}', attendance_point_settings #> '{game_attendance,sponsor_points}', '15'::jsonb),
        'college_totals', coalesce(attendance_point_settings #> '{parameters,college_totals}', attendance_point_settings #> '{opening_program,college_totals}', '{}'::jsonb)
    ),
    true
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
