-- Fix existing attendance_point_logs rows from 2026-08-16 onward.
-- Run attendance_points_logs_from_aug16.sql first so the function and columns exist.

do $$
declare
    refreshed_count integer := 0;
    session_row record;
begin
    for session_row in
        select distinct attendance_date, session_title
        from public.attendance_point_logs
        where attendance_date >= date '2026-08-16'
          and nullif(trim(coalesce(session_title, '')), '') is not null
    loop
        if public.refresh_attendance_point_log(session_row.attendance_date, session_row.session_title) then
            refreshed_count := refreshed_count + 1;
        end if;
    end loop;

    raise notice 'Refreshed % attendance session log(s) from 2026-08-16 onward.', refreshed_count;
end
$$;

-- Optional check for the COB Afternoon Session sample.
select
    attendance_date,
    session_title,
    team,
    registered_player_count,
    registered_player_points,
    student_player_count,
    total_students,
    student_player_points,
    total_points,
    scoring_breakdown,
    point_settings,
    computed_at
from public.attendance_point_logs
where attendance_date = date '2026-08-16'
  and session_title = 'Afternoon Session'
  and team = 'COB';
