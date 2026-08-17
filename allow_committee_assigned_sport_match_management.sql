-- Allow committee accounts assigned to the same sport to manage shared matches.
-- Run this in the Supabase SQL Editor for the dashboard project.

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
                  profile.assigned_sport_id = match_sport_id
                  or lower(trim(coalesce(profile.assigned_sport_name, ''))) = 'overall committee'
                  or exists (
                      select 1
                      from public.sports sport
                      where sport.id = match_sport_id
                        and (
                            regexp_replace(lower(coalesce(sport.sport_name, '')), '[^a-z0-9]+', '', 'g')
                                = regexp_replace(lower(coalesce(profile.assigned_sport_name, '')), '[^a-z0-9]+', '', 'g')
                            or (
                                length(regexp_replace(lower(coalesce(profile.assigned_sport_name, '')), '[^a-z0-9]+', '', 'g')) > 0
                                and (
                                    regexp_replace(lower(coalesce(sport.sport_name, '')), '[^a-z0-9]+', '', 'g')
                                        like '%' || regexp_replace(lower(coalesce(profile.assigned_sport_name, '')), '[^a-z0-9]+', '', 'g') || '%'
                                    or regexp_replace(lower(coalesce(profile.assigned_sport_name, '')), '[^a-z0-9]+', '', 'g')
                                        like '%' || regexp_replace(lower(coalesce(sport.sport_name, '')), '[^a-z0-9]+', '', 'g') || '%'
                                )
                            )
                        )
                  )
              )
        ),
        false
    )
$$;

revoke all on function public.app_can_manage_match_sport(bigint) from public;
grant execute on function public.app_can_manage_match_sport(bigint) to authenticated;

-- scheduled_matches --------------------------------------------------------
-- Anonymous student views can still read all schedules. Authenticated
-- committee accounts are constrained to their assigned sport; admins keep full access.

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
using (public.app_can_manage_match_sport(sport_id));

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
using (public.app_can_manage_match_sport(sport_id))
with check (public.app_can_manage_match_sport(sport_id));

-- game_history -------------------------------------------------------------

drop policy if exists "Public can read game history" on public.game_history;
create policy "Public can read game history"
on public.game_history
for select
to anon
using (true);

drop policy if exists "Admins can read all game history" on public.game_history;
create policy "Admins can read all game history"
on public.game_history
for select
to authenticated
using (public.app_is_admin());

drop policy if exists "Committee can read assigned sport game history" on public.game_history;
create policy "Committee can read assigned sport game history"
on public.game_history
for select
to authenticated
using (
    exists (
        select 1
        from public.scheduled_matches match_record
        where match_record.id = game_history.match_id
          and public.app_can_manage_match_sport(match_record.sport_id)
    )
);

drop policy if exists "Dashboard users can create owned game history" on public.game_history;
drop policy if exists "Committee can create assigned sport game history" on public.game_history;
create policy "Committee can create assigned sport game history"
on public.game_history
for insert
to authenticated
with check (
    exists (
        select 1
        from public.scheduled_matches match_record
        where match_record.id = game_history.match_id
          and public.app_can_manage_match_sport(match_record.sport_id)
    )
);

drop policy if exists "Dashboard users can update owned game history" on public.game_history;
drop policy if exists "Committee can update assigned sport game history" on public.game_history;
create policy "Committee can update assigned sport game history"
on public.game_history
for update
to authenticated
using (
    exists (
        select 1
        from public.scheduled_matches match_record
        where match_record.id = game_history.match_id
          and public.app_can_manage_match_sport(match_record.sport_id)
    )
)
with check (
    exists (
        select 1
        from public.scheduled_matches match_record
        where match_record.id = game_history.match_id
          and public.app_can_manage_match_sport(match_record.sport_id)
    )
);

-- basketball_match_player_stats ------------------------------------------
-- These rows hold both basketball and volleyball live score sheets.

drop policy if exists "Basketball stats are readable by dashboard users" on public.basketball_match_player_stats;
drop policy if exists "Basketball stats are readable by students" on public.basketball_match_player_stats;
create policy "Basketball stats are readable by students"
on public.basketball_match_player_stats
for select
to anon
using (true);

drop policy if exists "Admins can read all score rows" on public.basketball_match_player_stats;
create policy "Admins can read all score rows"
on public.basketball_match_player_stats
for select
to authenticated
using (public.app_is_admin());

drop policy if exists "Committee can read assigned sport score rows" on public.basketball_match_player_stats;
create policy "Committee can read assigned sport score rows"
on public.basketball_match_player_stats
for select
to authenticated
using (
    exists (
        select 1
        from public.scheduled_matches match_record
        where match_record.id = basketball_match_player_stats.match_id
          and public.app_can_manage_match_sport(match_record.sport_id)
    )
);

drop policy if exists "Committee and admin can insert basketball stats" on public.basketball_match_player_stats;
drop policy if exists "Admins can create all score rows" on public.basketball_match_player_stats;
create policy "Admins can create all score rows"
on public.basketball_match_player_stats
for insert
to authenticated
with check (public.app_is_admin());

drop policy if exists "Committee can create assigned sport score rows" on public.basketball_match_player_stats;
create policy "Committee can create assigned sport score rows"
on public.basketball_match_player_stats
for insert
to authenticated
with check (
    exists (
        select 1
        from public.scheduled_matches match_record
        where match_record.id = basketball_match_player_stats.match_id
          and public.app_can_manage_match_sport(match_record.sport_id)
    )
);

drop policy if exists "Committee and admin can update basketball stats" on public.basketball_match_player_stats;
drop policy if exists "Admins can update all score rows" on public.basketball_match_player_stats;
create policy "Admins can update all score rows"
on public.basketball_match_player_stats
for update
to authenticated
using (public.app_is_admin())
with check (public.app_is_admin());

drop policy if exists "Committee can update assigned sport score rows" on public.basketball_match_player_stats;
create policy "Committee can update assigned sport score rows"
on public.basketball_match_player_stats
for update
to authenticated
using (
    exists (
        select 1
        from public.scheduled_matches match_record
        where match_record.id = basketball_match_player_stats.match_id
          and public.app_can_manage_match_sport(match_record.sport_id)
    )
)
with check (
    exists (
        select 1
        from public.scheduled_matches match_record
        where match_record.id = basketball_match_player_stats.match_id
          and public.app_can_manage_match_sport(match_record.sport_id)
    )
);

drop policy if exists "Committee and admin can delete basketball stats" on public.basketball_match_player_stats;
drop policy if exists "Admins can delete all score rows" on public.basketball_match_player_stats;
create policy "Admins can delete all score rows"
on public.basketball_match_player_stats
for delete
to authenticated
using (public.app_is_admin());

drop policy if exists "Committee can delete assigned sport score rows" on public.basketball_match_player_stats;
create policy "Committee can delete assigned sport score rows"
on public.basketball_match_player_stats
for delete
to authenticated
using (
    exists (
        select 1
        from public.scheduled_matches match_record
        where match_record.id = basketball_match_player_stats.match_id
          and public.app_can_manage_match_sport(match_record.sport_id)
    )
);
