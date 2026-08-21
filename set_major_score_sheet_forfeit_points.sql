-- Basketball and volleyball are major games.
-- If one team defaults, the present team receives 100 points and the defaulting team receives 0.

update public.sports
set
    game_type = 'major',
    forfeit_winner_points = 100,
    forfeit_loser_points = 0
where lower(coalesce(sport_name, '')) like '%basketball%'
   or lower(coalesce(sport_name, '')) like '%volleyball%';

select
    id,
    sport_name,
    game_type,
    forfeit_winner_points,
    forfeit_loser_points
from public.sports
where lower(coalesce(sport_name, '')) like '%basketball%'
   or lower(coalesce(sport_name, '')) like '%volleyball%'
order by sport_name;
