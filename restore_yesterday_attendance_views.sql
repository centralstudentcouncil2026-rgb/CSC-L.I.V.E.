  drop view if exists public.attendance_leaderboard_points;
  drop view if exists public.team_attendance_points;
  drop view if exists public.attendance_point_history;
  
  create view public.attendance_point_history as
  with settings_source as (
      select coalesce(
          (
              select point_settings
              from public.attendance_settings
              where id = 1
              limit 1
          ),
          (
              select attendance_point_settings
              from public.attendance
              where attendance_point_settings is not null
              order by checked_at desc nulls last, id desc
              limit 1
          ),
          '{}'::jsonb
      ) as point_settings
  ),
  safe_parameters as (
      select
          case
              when coalesce(point_settings #>> '{parameters,registered_player_points}', '') ~ '^\d+(\.\d+)?$'
               and (point_settings #>> '{parameters,registered_player_points}')::numeric between 0 and 1000
                  then (point_settings #>> '{parameters,registered_player_points}')::numeric
              else 5
          end as registered_player_points,
          case
              when coalesce(point_settings #>> '{parameters,dean_points}', '') ~ '^\d+(\.\d+)?$'
               and (point_settings #>> '{parameters,dean_points}')::numeric between 0 and 1000
                  then (point_settings #>> '{parameters,dean_points}')::numeric
              else 50
          end as dean_points,
          case
              when coalesce(point_settings #>> '{parameters,faculty_points}', '') ~ '^\d+(\.\d+)?$'
               and (point_settings #>> '{parameters,faculty_points}')::numeric between 0 and 1000
                  then (point_settings #>> '{parameters,faculty_points}')::numeric
              else 5
          end as faculty_points,
          case
              when coalesce(point_settings #>> '{parameters,sponsor_points}', '') ~ '^\d+(\.\d+)?$'
               and (point_settings #>> '{parameters,sponsor_points}')::numeric between 0 and 1000
                  then (point_settings #>> '{parameters,sponsor_points}')::numeric
              else 5
          end as sponsor_points,
          case
              when coalesce(point_settings #>> '{parameters,sponsor_game_attendance_points}', '') ~ '^\d+(\.\d+)?$'
               and (point_settings #>> '{parameters,sponsor_game_attendance_points}')::numeric between 0 and 1000
                  then (point_settings #>> '{parameters,sponsor_game_attendance_points}')::numeric
              else 15
          end as sponsor_game_attendance_points,
          coalesce(
              point_settings #> '{parameters,college_totals}',
              point_settings #> '{opening_program,college_totals}',
              '{}'::jsonb
          ) as college_totals
      from settings_source
  ),
  normalized_attendance as (
      select
          a.id,
          a.attendance_date,
          coalesce(nullif(trim(a.attendance_session_title), ''), 'Attendance') as session_title,
          case
              when a.participant_id is not null
               and lower(coalesce(p.status, '')) = 'approved'
                  then 'registered_player'
              when coalesce(a.attendance_category, '') in ('faculty', 'department_chair', 'dean', 'sponsor', 'sponsor_game_attendance')
                  then a.attendance_category
              else 'student_player'
          end as resolved_attendance_category,
          coalesce(a.status, 'Present') as attendance_status,
          a.participant_id,
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
          end as team
      from public.attendance a
      left join public.participants p
          on p.id::text = a.participant_id::text
  ),
  attendance_counts as (
      select
          na.attendance_date,
          na.session_title,
          na.team,
          count(*) as total_present,
          count(*) filter (
              where na.resolved_attendance_category = 'registered_player'
          ) as registered_player_count,
          count(*) filter (
              where na.resolved_attendance_category = 'student_player'
          ) as student_player_count,
          count(*) filter (where na.resolved_attendance_category = 'faculty') as faculty_count,
          count(*) filter (where na.resolved_attendance_category = 'department_chair') as department_chair_count,
          count(*) filter (where na.resolved_attendance_category = 'dean') as dean_count,
          count(*) filter (where na.resolved_attendance_category = 'student_player') as student_from_college_count,
          count(*) filter (where na.resolved_attendance_category = 'sponsor') as sponsor_count,
          count(*) filter (where na.resolved_attendance_category = 'sponsor_game_attendance') as sponsor_game_attendance_count
      from normalized_attendance na
      where lower(coalesce(na.attendance_status, 'present')) = 'present'
        and na.team in ('CAH', 'COB', 'COD', 'COH', 'COM', 'CON', 'COT', 'CSET', 'CTE', 'Academy', 'Faculty')
      group by na.attendance_date, na.session_title, na.team
  )
  select
      ac.attendance_date,
      ac.session_title,
      ac.team,
      ac.total_present,
      ac.registered_player_count,
      ac.student_player_count,
      ac.faculty_count,
      ac.department_chair_count,
      ac.dean_count,
      ac.student_from_college_count,
      ac.sponsor_count,
      ac.sponsor_game_attendance_count,
      coalesce(college_totals.total_students, 0) as total_students,
      round((
          case
              when coalesce(college_totals.total_students, 0) > 0
                  then (ac.student_player_count::numeric / nullif(college_totals.total_students, 0)) * 100
              else 0
          end
          + (ac.registered_player_count * sp.registered_player_points)
          + (ac.dean_count * sp.dean_points)
          + (ac.faculty_count * sp.faculty_points)
          + (ac.department_chair_count * sp.faculty_points)
          + (ac.sponsor_count * sp.sponsor_points)
          + (ac.sponsor_game_attendance_count * sp.sponsor_game_attendance_points)
      ), 2) as total_points
  from attendance_counts ac
  cross join safe_parameters sp
  left join lateral (
      select
          case
              when coalesce(value ->> 'total_students', value ->> 'total_student_players', '') ~ '^\d+(\.\d+)?$'
                  then least(coalesce(value ->> 'total_students', value ->> 'total_student_players')::numeric, 10000)
              else 0
          end as total_students
      from jsonb_each(coalesce(sp.college_totals, '{}'::jsonb))
      where lower(key) = lower(ac.team)
         or lower(value ->> 'college_name') = lower(ac.team)
      limit 1
  ) college_totals on true;
  
  grant select on public.attendance_point_history to anon, authenticated;
  
  create view public.attendance_leaderboard_points as
  select
      team,
      round(sum(total_points), 2) as total_points
  from public.attendance_point_history
  group by team;
  
  create view public.team_attendance_points as
  select
      team,
      round(sum(total_points), 2) as total_points
  from public.attendance_point_history
  group by team;
  
  grant select on public.attendance_leaderboard_points to anon, authenticated;
  grant select on public.team_attendance_points to anon, authenticated;
