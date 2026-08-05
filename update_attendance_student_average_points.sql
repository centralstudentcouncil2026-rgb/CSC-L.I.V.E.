drop view if exists public.attendance_leaderboard_points;
drop view if exists public.attendance_point_history;

create view public.attendance_point_history as
with current_settings as (
    select coalesce(
        (select point_settings from public.attendance_settings where id = 1 limit 1),
        '{}'::jsonb
    ) as point_settings
),
safe_parameters as (
    select
        case when coalesce(point_settings #>> '{parameters,registered_player_points}', '') ~ '^\d+(\.\d+)?$'
              and (point_settings #>> '{parameters,registered_player_points}')::numeric between 0 and 1000
             then (point_settings #>> '{parameters,registered_player_points}')::numeric else 5 end as registered_player_points,
        case when coalesce(point_settings #>> '{parameters,dean_points}', '') ~ '^\d+(\.\d+)?$'
              and (point_settings #>> '{parameters,dean_points}')::numeric between 0 and 1000
             then (point_settings #>> '{parameters,dean_points}')::numeric else 50 end as dean_points,
        case when coalesce(point_settings #>> '{parameters,faculty_points}', '') ~ '^\d+(\.\d+)?$'
              and (point_settings #>> '{parameters,faculty_points}')::numeric between 0 and 1000
             then (point_settings #>> '{parameters,faculty_points}')::numeric else 5 end as faculty_points,
        case when coalesce(point_settings #>> '{parameters,sponsor_points}', '') ~ '^\d+(\.\d+)?$'
              and (point_settings #>> '{parameters,sponsor_points}')::numeric between 0 and 1000
             then (point_settings #>> '{parameters,sponsor_points}')::numeric else 5 end as sponsor_points,
        case when coalesce(point_settings #>> '{parameters,sponsor_game_attendance_points}', '') ~ '^\d+(\.\d+)?$'
              and (point_settings #>> '{parameters,sponsor_game_attendance_points}')::numeric between 0 and 1000
             then (point_settings #>> '{parameters,sponsor_game_attendance_points}')::numeric else 15 end as sponsor_game_attendance_points,
        coalesce(point_settings #> '{parameters,college_totals}', '{}'::jsonb) as college_totals
    from current_settings
),
normalized_attendance as (
    select
        a.*,
        p.status as participant_status,
        p.team as participant_team,
        case btrim(lower(regexp_replace(coalesce(
            case
                when a.participant_id is not null and nullif(p.team, '') is not null then p.team
                else null
            end,
            nullif(a.home_college, ''),
            nullif(a.team, '')
        ), '[^a-zA-Z0-9]+', ' ', 'g')))
            when 'college of science engineering and technology' then 'CSET'
            when 'college of nursing' then 'CON'
            when 'college of business' then 'COB'
            when 'college of arts and humanities' then 'CAH'
            when 'college of theology' then 'COT'
            when 'college of health' then 'COH'
            when 'college of medicine' then 'COM'
            when 'college of teacher education' then 'CTE'
            when 'college of teachers education' then 'CTE'
            when 'college of dentistry' then 'COD'
            when 'academy' then 'Academy'
            when 'faculty' then 'Faculty'
            else upper(btrim(coalesce(
                case
                    when a.participant_id is not null and nullif(p.team, '') is not null then p.team
                    else null
                end,
                nullif(a.home_college, ''),
                nullif(a.team, '')
            )))
        end as normalized_team
    from public.attendance a
    left join public.participants p
        on p.id::text = a.participant_id::text
),
attendance_counts as (
    select
        na.attendance_date,
        na.normalized_team as team,
        coalesce(nullif(na.attendance_session_title, ''), 'Morning Session') as session_title,
        count(*) filter (where lower(coalesce(na.status, 'present')) = 'present') as total_present,
        count(*) filter (
            where lower(coalesce(na.status, 'present')) = 'present'
              and na.participant_id is not null
              and lower(coalesce(na.participant_status, '')) = 'approved'
              and na.attendance_category = 'registered_player'
        ) as registered_player_count,
        count(*) filter (
            where lower(coalesce(na.status, 'present')) = 'present'
              and (
                  na.participant_id is null
                  or lower(coalesce(na.participant_status, '')) <> 'approved'
                  or na.attendance_category in ('student_player', 'student_from_college')
              )
        ) as student_player_count,
        count(*) filter (where lower(coalesce(na.status, 'present')) = 'present' and na.attendance_category = 'faculty') as faculty_count,
        count(*) filter (where lower(coalesce(na.status, 'present')) = 'present' and na.attendance_category = 'department_chair') as department_chair_count,
        count(*) filter (where lower(coalesce(na.status, 'present')) = 'present' and na.attendance_category = 'dean') as dean_count,
        count(*) filter (where lower(coalesce(na.status, 'present')) = 'present' and na.attendance_category = 'student_from_college') as student_from_college_count,
        count(*) filter (where lower(coalesce(na.status, 'present')) = 'present' and na.attendance_category = 'sponsor') as sponsor_count,
        count(*) filter (where lower(coalesce(na.status, 'present')) = 'present' and na.attendance_category = 'sponsor_game_attendance') as sponsor_game_attendance_count
    from normalized_attendance na
    where na.normalized_team in ('CAH', 'COB', 'COD', 'COH', 'COM', 'CON', 'COT', 'CSET', 'CTE', 'Academy', 'Faculty')
    group by na.attendance_date, na.normalized_team, coalesce(nullif(na.attendance_session_title, ''), 'Morning Session')
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
    coalesce(college_totals.total_students, 0) as total_students,
    round((
        ac.registered_player_count * sp.registered_player_points
        + case
            when coalesce(college_totals.total_students, 0) > 0 then (ac.student_player_count::numeric / nullif(college_totals.total_students, 0)) * 100
            else 0
          end
        + case
            when sp.faculty_points > 0 then ac.faculty_count * sp.faculty_points
            when coalesce(college_totals.total_faculty, 0) > 0 then (ac.faculty_count::numeric / nullif(college_totals.total_faculty, 0)) * 100
            else 0
          end
        + case
            when sp.faculty_points > 0 then ac.department_chair_count * sp.faculty_points
            when coalesce(college_totals.total_department_chairs, 0) > 0 then (ac.department_chair_count::numeric / nullif(college_totals.total_department_chairs, 0)) * 100
            else 0
          end
        + ac.dean_count * sp.dean_points
        + ac.sponsor_count * sp.sponsor_points
        + ac.sponsor_game_attendance_count * sp.sponsor_game_attendance_points
    ), 2) as total_points
from attendance_counts ac
cross join safe_parameters sp
left join lateral (
    select
        case when coalesce(value ->> 'total_faculty', '') ~ '^\d+(\.\d+)?$'
             then least((value ->> 'total_faculty')::numeric, 10000)
             else 0 end as total_faculty,
        case when coalesce(value ->> 'total_department_chairs', '') ~ '^\d+(\.\d+)?$'
             then least((value ->> 'total_department_chairs')::numeric, 10000)
             else 0 end as total_department_chairs,
        case when coalesce(value ->> 'total_students', value ->> 'total_student_players', '') ~ '^\d+(\.\d+)?$'
             then least(coalesce(value ->> 'total_students', value ->> 'total_student_players')::numeric, 10000)
             else 0 end as total_students
    from jsonb_each(coalesce(sp.college_totals, '{}'::jsonb))
    where key = ac.team or value ->> 'college_name' = ac.team
    limit 1
) college_totals on true;

grant select on public.attendance_point_history to anon, authenticated;

create view public.attendance_leaderboard_points as
select
    team,
    round(sum(total_points), 2) as total_points
from public.attendance_point_history
group by team;

grant select on public.attendance_leaderboard_points to anon, authenticated;
