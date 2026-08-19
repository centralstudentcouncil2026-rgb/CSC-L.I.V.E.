-- Add editable declared-point rules for each sport/game category.
-- Committees will use these values when declaring regular and default/forfeit results.

alter table public.sports
    add column if not exists winner_points numeric not null default 0,
    add column if not exists loser_points numeric not null default 0,
    add column if not exists forfeit_winner_points numeric not null default 0,
    add column if not exists forfeit_loser_points numeric not null default 0;

alter table public.sports
    alter column winner_points set default 0,
    alter column loser_points set default 0,
    alter column forfeit_winner_points set default 0,
    alter column forfeit_loser_points set default 0;

update public.sports
set
    winner_points = case
        when lower(coalesce(game_type, 'major')) = 'minor' then 100
        else 200
    end,
    loser_points = case
        when lower(coalesce(game_type, 'major')) = 'minor' then 50
        else 100
    end,
    forfeit_winner_points = case
        when lower(coalesce(game_type, 'major')) = 'minor' then 20
        else 50
    end,
    forfeit_loser_points = 0;

select
    id,
    sport_name,
    game_type,
    winner_points,
    loser_points,
    forfeit_winner_points,
    forfeit_loser_points,
    player_limit
from public.sports
order by sport_name;
