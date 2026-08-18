-- Remove configured sport winner/loser default points.
-- After this, declared match points should come only from the committee result form.

alter table public.sports
    add column if not exists winner_points numeric not null default 0,
    add column if not exists loser_points numeric not null default 0;

alter table public.sports
    alter column winner_points set default 0,
    alter column loser_points set default 0;

update public.sports
set
    winner_points = 0,
    loser_points = 0
where coalesce(winner_points, 0) <> 0
   or coalesce(loser_points, 0) <> 0;

select
    id,
    sport_name,
    winner_points,
    loser_points,
    game_type,
    player_limit
from public.sports
order by sport_name;
