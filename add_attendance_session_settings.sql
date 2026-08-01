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
            "student_from_college_points": 2,
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
            "student_from_college_points": 2,
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
            "student_from_college_points": 2,
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
            "student_from_college_points": 2,
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

insert into public.attendance_settings (id)
values (1)
on conflict (id) do nothing;

alter table public.attendance
    add column if not exists attendance_session_type text not null default 'regular',
    add column if not exists attendance_session_title text not null default 'Regular Attendance',
    add column if not exists attendance_category text not null default 'student_player',
    add column if not exists attendance_point_settings jsonb not null default '{
        "parameters": {
            "registered_player_points": 5,
            "faculty_formula_base": 100,
            "department_chair_formula_base": 100,
            "dean_points": 50,
            "student_from_college_points": 2,
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
            "student_from_college_points": 2,
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

alter table public.attendance
    alter column attendance_category set default 'student_player';

update public.attendance
set attendance_category = case
    when participant_id is not null then 'registered_player'
    else 'student_player'
end
where attendance_category is null
   or attendance_category = '';

update public.attendance
set attendance_category = 'student_player'
where participant_id is null
  and attendance_category = 'student_from_college';

alter table public.attendance
    drop constraint if exists attendance_category_allowed;

alter table public.attendance
    add constraint attendance_category_allowed
    check (attendance_category in (
        'registered_player',
        'student_player',
        'faculty',
        'department_chair',
        'dean',
        'student_from_college',
        'sponsor',
        'sponsor_game_attendance'
    ));

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
        'student_from_college_points', coalesce(point_settings #> '{parameters,student_player_points}', point_settings #> '{parameters,student_from_college_points}', point_settings #> '{opening_program,student_from_college_points}', '2'::jsonb),
        'faculty_points', coalesce(point_settings #> '{parameters,faculty_points}', point_settings #> '{sunday_devotional,faculty_points}', '5'::jsonb),
        'sponsor_points', coalesce(point_settings #> '{parameters,sponsor_points}', point_settings #> '{sunday_devotional,sponsor_points}', '5'::jsonb),
        'student_player_points', coalesce(point_settings #> '{parameters,student_player_points}', point_settings #> '{parameters,student_from_college_points}', point_settings #> '{sunday_devotional,student_player_points}', '2'::jsonb),
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
        'student_from_college_points', coalesce(attendance_point_settings #> '{parameters,student_player_points}', attendance_point_settings #> '{parameters,student_from_college_points}', attendance_point_settings #> '{opening_program,student_from_college_points}', '2'::jsonb),
        'faculty_points', coalesce(attendance_point_settings #> '{parameters,faculty_points}', attendance_point_settings #> '{sunday_devotional,faculty_points}', '5'::jsonb),
        'sponsor_points', coalesce(attendance_point_settings #> '{parameters,sponsor_points}', attendance_point_settings #> '{sunday_devotional,sponsor_points}', '5'::jsonb),
        'student_player_points', coalesce(attendance_point_settings #> '{parameters,student_player_points}', attendance_point_settings #> '{parameters,student_from_college_points}', attendance_point_settings #> '{sunday_devotional,student_player_points}', '2'::jsonb),
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

create or replace view public.attendance_point_history as
with current_settings as (
    select coalesce(point_settings, '{}'::jsonb) as point_settings
    from public.attendance_settings
    where id = 1
),
normalized_settings as (
    select
        jsonb_build_object(
            'registered_player_points', coalesce(point_settings #> '{parameters,registered_player_points}', point_settings #> '{opening_program,registered_player_points}', '5'::jsonb),
            'faculty_formula_base', '100'::jsonb,
            'department_chair_formula_base', '100'::jsonb,
            'dean_points', coalesce(point_settings #> '{parameters,dean_points}', point_settings #> '{opening_program,dean_points}', '50'::jsonb),
            'student_from_college_points', coalesce(point_settings #> '{parameters,student_player_points}', point_settings #> '{parameters,student_from_college_points}', point_settings #> '{opening_program,student_from_college_points}', '2'::jsonb),
            'faculty_points', coalesce(point_settings #> '{parameters,faculty_points}', point_settings #> '{sunday_devotional,faculty_points}', '5'::jsonb),
            'sponsor_points', coalesce(point_settings #> '{parameters,sponsor_points}', point_settings #> '{sunday_devotional,sponsor_points}', '5'::jsonb),
            'student_player_points', coalesce(point_settings #> '{parameters,student_player_points}', point_settings #> '{parameters,student_from_college_points}', point_settings #> '{sunday_devotional,student_player_points}', '2'::jsonb),
            'sponsor_game_attendance_points', coalesce(point_settings #> '{parameters,sponsor_game_attendance_points}', point_settings #> '{game_attendance,sponsor_points}', '15'::jsonb),
            'college_totals', coalesce(point_settings #> '{parameters,college_totals}', point_settings #> '{opening_program,college_totals}', '{}'::jsonb)
        ) as parameters
    from current_settings
),
attendance_counts as (
    select
        attendance_date,
        case btrim(lower(regexp_replace(coalesce(nullif(home_college, ''), nullif(team, '')), '[^a-zA-Z0-9]+', ' ', 'g')))
            when 'college of science engineering and technology' then 'CSET'
            when 'college of nursing' then 'CON'
            when 'college of business' then 'COB'
            when 'college of arts and humanities' then 'CAH'
            when 'college of theology' then 'COT'
            when 'college of health' then 'COH'
            when 'college of medicine' then 'COM'
            when 'college of teachers education' then 'CTE'
            when 'college of dentistry' then 'COD'
            else coalesce(nullif(home_college, ''), nullif(team, ''))
        end as team,
        max(attendance_session_title) as session_title,
        count(*) filter (where lower(coalesce(status, 'present')) = 'present') as total_present,
        count(*) filter (where lower(coalesce(status, 'present')) = 'present' and participant_id is not null and attendance_category = 'registered_player') as registered_player_count,
        count(*) filter (where lower(coalesce(status, 'present')) = 'present' and participant_id is null and attendance_category in ('student_player', 'student_from_college')) as student_player_count,
        count(*) filter (where lower(coalesce(status, 'present')) = 'present' and attendance_category = 'faculty') as faculty_count,
        count(*) filter (where lower(coalesce(status, 'present')) = 'present' and attendance_category = 'department_chair') as department_chair_count,
        count(*) filter (where lower(coalesce(status, 'present')) = 'present' and attendance_category = 'dean') as dean_count,
        count(*) filter (where lower(coalesce(status, 'present')) = 'present' and attendance_category = 'student_from_college') as student_from_college_count,
        count(*) filter (where lower(coalesce(status, 'present')) = 'present' and attendance_category = 'sponsor') as sponsor_count,
        count(*) filter (where lower(coalesce(status, 'present')) = 'present' and attendance_category = 'sponsor_game_attendance') as sponsor_game_attendance_count
    from public.attendance
    group by attendance_date,
        case btrim(lower(regexp_replace(coalesce(nullif(home_college, ''), nullif(team, '')), '[^a-zA-Z0-9]+', ' ', 'g')))
            when 'college of science engineering and technology' then 'CSET'
            when 'college of nursing' then 'CON'
            when 'college of business' then 'COB'
            when 'college of arts and humanities' then 'CAH'
            when 'college of theology' then 'COT'
            when 'college of health' then 'COH'
            when 'college of medicine' then 'COM'
            when 'college of teachers education' then 'CTE'
            when 'college of dentistry' then 'COD'
            else coalesce(nullif(home_college, ''), nullif(team, ''))
        end
)
select
    ac.attendance_date,
    ac.team,
    ac.session_title,
    ac.total_present,
    ac.registered_player_count,
    ac.student_player_count,
    ac.faculty_count,
    ac.department_chair_count,
    ac.dean_count,
    ac.student_from_college_count,
    ac.sponsor_count,
    ac.sponsor_game_attendance_count,
    coalesce(college_totals.total_faculty, 0) as total_faculty,
    coalesce(college_totals.total_department_chairs, 0) as total_department_chairs,
    (
        ac.registered_player_count * coalesce((ns.parameters ->> 'registered_player_points')::numeric, 5)
        + ac.student_player_count * coalesce((ns.parameters ->> 'student_player_points')::numeric, 2)
        + case
            when coalesce(nullif(ns.parameters ->> 'faculty_points', '')::numeric, 5) > 0
            then ac.faculty_count * coalesce(nullif(ns.parameters ->> 'faculty_points', '')::numeric, 5)
            when coalesce(college_totals.total_faculty, 0) > 0
            then (ac.faculty_count::numeric / nullif(college_totals.total_faculty, 0)) * 100
            else 0
          end
        + case
            when coalesce(nullif(ns.parameters ->> 'faculty_points', '')::numeric, 5) > 0
            then ac.department_chair_count * coalesce(nullif(ns.parameters ->> 'faculty_points', '')::numeric, 5)
            when coalesce(college_totals.total_department_chairs, 0) > 0
            then (ac.department_chair_count::numeric / nullif(college_totals.total_department_chairs, 0)) * 100
            else 0
          end
        + ac.dean_count * coalesce((ns.parameters ->> 'dean_points')::numeric, 50)
        + ac.sponsor_count * coalesce((ns.parameters ->> 'sponsor_points')::numeric, 5)
        + ac.sponsor_game_attendance_count * coalesce((ns.parameters ->> 'sponsor_game_attendance_points')::numeric, 15)
    )::numeric(12, 2) as total_points
from attendance_counts ac
cross join normalized_settings ns
left join lateral (
    select
        coalesce(nullif(value ->> 'total_faculty', '')::numeric, 0) as total_faculty,
        coalesce(nullif(value ->> 'total_department_chairs', '')::numeric, 0) as total_department_chairs
    from jsonb_each(coalesce(ns.parameters -> 'college_totals', '{}'::jsonb))
    where key = ac.team
       or value ->> 'college_name' = ac.team
    limit 1
) college_totals on true
where ac.team is not null;

grant select on public.attendance_point_history to anon, authenticated;
