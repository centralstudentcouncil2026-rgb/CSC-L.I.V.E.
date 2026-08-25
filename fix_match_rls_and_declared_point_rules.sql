-- Fix scheduled_matches RLS for assigned committee accounts and apply
-- the current declared-point rules.
-- Run in Supabase SQL Editor.

create or replace function public.app_can_manage_match_sport(match_sport_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        public.app_is_admin()
        or exists (
            select 1
            from public.user_profiles profile
            where profile.id = auth.uid()
              and lower(trim(profile.role)) = 'committee'
              and lower(trim(profile.approval_status)) = 'approved'
              and (
                  regexp_replace(lower(coalesce(profile.assigned_sport_name, '')), '[^a-z0-9]+', '', 'g') in ('overallcommittee', 'overallcoordinator', 'overall')
                  or profile.assigned_sport_id = match_sport_id
                  or exists (
                      select 1
                      from public.sports sport
                      where sport.id = match_sport_id
                        and regexp_replace(lower(coalesce(sport.sport_name, '')), '[^a-z0-9]+', '', 'g')
                            = regexp_replace(lower(coalesce(profile.assigned_sport_name, '')), '[^a-z0-9]+', '', 'g')
                  )
              )
        ),
        false
    )
$$;

revoke all on function public.app_can_manage_match_sport(bigint) from public;
grant execute on function public.app_can_manage_match_sport(bigint) to authenticated;

create or replace function public.app_is_match_creator(match_created_by text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        nullif(trim(coalesce(match_created_by, '')), '') = auth.uid()::text
        or lower(nullif(trim(coalesce(match_created_by, '')), '')) = lower(coalesce(auth.email(), '')),
        false
    )
$$;

revoke all on function public.app_is_match_creator(text) from public;
grant execute on function public.app_is_match_creator(text) to authenticated;

alter table public.scheduled_matches enable row level security;

drop policy if exists "Public can read scheduled matches" on public.scheduled_matches;
create policy "Public can read scheduled matches"
on public.scheduled_matches
for select
to anon
using (true);

drop policy if exists "Admins can read all matches" on public.scheduled_matches;
create policy "Admins can read all matches"
on public.scheduled_matches
for select
to authenticated
using (public.app_is_admin());

drop policy if exists "Committee can read assigned sport matches" on public.scheduled_matches;
create policy "Committee can read assigned sport matches"
on public.scheduled_matches
for select
to authenticated
using (
    public.app_can_manage_match_sport(sport_id)
    or public.app_is_match_creator(created_by)
);

drop policy if exists "Dashboard users can create matches" on public.scheduled_matches;
drop policy if exists "Committee can create own matches" on public.scheduled_matches;
drop policy if exists "Committee can create assigned sport matches" on public.scheduled_matches;
create policy "Committee can create assigned sport matches"
on public.scheduled_matches
for insert
to authenticated
with check (public.app_can_manage_match_sport(sport_id));

drop policy if exists "Committee can update own matches" on public.scheduled_matches;
drop policy if exists "Committee can update assigned sport matches" on public.scheduled_matches;
create policy "Committee can update assigned sport matches"
on public.scheduled_matches
for update
to authenticated
using (
    public.app_can_manage_match_sport(sport_id)
    or public.app_is_match_creator(created_by)
)
with check (
    public.app_can_manage_match_sport(sport_id)
    or public.app_is_match_creator(created_by)
);

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

update public.game_history history
set
    winner_points_awarded = case
        when (
            lower(coalesce(history.best_player, '')) like '%win by default%'
            or lower(coalesce(history.best_player, '')) like '%won by default%'
            or lower(coalesce(history.best_player, '')) like '%winner by default%'
            or lower(coalesce(history.result, '')) like '%default%'
            or lower(coalesce(history.result, '')) like '%forfeit%'
        ) then
            case
                when lower(coalesce(sport.game_type, 'major')) = 'minor' then 20
                else 50
            end
        when lower(coalesce(sport.game_type, 'major')) = 'minor' then 100
        else 200
    end,
    loser_points_awarded = case
        when (
            lower(coalesce(history.best_player, '')) like '%win by default%'
            or lower(coalesce(history.best_player, '')) like '%won by default%'
            or lower(coalesce(history.best_player, '')) like '%winner by default%'
            or lower(coalesce(history.result, '')) like '%default%'
            or lower(coalesce(history.result, '')) like '%forfeit%'
        ) then 0
        when lower(coalesce(sport.game_type, 'major')) = 'minor' then 50
        else 100
    end,
    updated_at = now()
from public.sports sport
where history.sport_id = sport.id
  and history.winner_team_id is not null
  and history.loser_team_id is not null;

select
    id,
    sport_name,
    game_type,
    winner_points,
    loser_points,
    forfeit_winner_points,
    forfeit_loser_points
from public.sports
order by game_type, sport_name;
