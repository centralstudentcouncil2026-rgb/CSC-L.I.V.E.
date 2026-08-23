-- Ensure accounts assigned to "Overall Committee" or "Overall Coordinator"
-- can view and manage every game.
-- Run this in the Supabase SQL Editor for the active CSC L.I.V.E. project.

create or replace function public.app_is_overall_committee(user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        exists (
            select 1
            from public.user_profiles profile
            where profile.id = user_id
              and lower(trim(profile.role)) = 'committee'
              and lower(trim(profile.approval_status)) = 'approved'
              and regexp_replace(lower(coalesce(profile.assigned_sport_name, '')), '[^a-z0-9]+', '', 'g')
                    in ('overallcommittee', 'overallcoordinator', 'overall')
        ),
        false
    )
$$;

create or replace function public.app_can_manage_match_sport(match_sport_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        public.app_is_admin()
        or public.app_is_overall_committee(auth.uid())
        or exists (
            select 1
            from public.user_profiles profile
            where profile.id = auth.uid()
              and lower(trim(profile.role)) = 'committee'
              and lower(trim(profile.approval_status)) = 'approved'
              and (
                  profile.assigned_sport_id = match_sport_id
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

revoke all on function public.app_is_overall_committee(uuid) from public;
revoke all on function public.app_can_manage_match_sport(bigint) from public;
grant execute on function public.app_is_overall_committee(uuid) to authenticated;
grant execute on function public.app_can_manage_match_sport(bigint) to authenticated;

create or replace function public.admin_assign_account_sport(
    target_user_id uuid,
    assigned_sport_id jsonb,
    assigned_sport_name text
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
    resolved_sport_id bigint;
    resolved_sport_name text := nullif(trim(coalesce(assigned_sport_name, '')), '');
    raw_sport_id text := trim(both '"' from coalesce(assigned_sport_id::text, ''));
begin
    if not public.app_is_admin() then
        raise exception 'Only an approved admin can assign account sports.';
    end if;

    if assigned_sport_id is not null
       and assigned_sport_id <> 'null'::jsonb
       and raw_sport_id <> ''
       and raw_sport_id <> '__overall_committee__'
       and regexp_replace(lower(coalesce(resolved_sport_name, '')), '[^a-z0-9]+', '', 'g') not in ('overallcommittee', 'overallcoordinator', 'overall') then
        resolved_sport_id := raw_sport_id::bigint;
    end if;

    update public.user_profiles
    set
        assigned_sport_id = resolved_sport_id,
        assigned_sport_name = resolved_sport_name
    where id = target_user_id;

    if not found then
        raise exception 'Account profile not found.';
    end if;
end
$$;

revoke all on function public.admin_assign_account_sport(uuid, jsonb, text) from public;
grant execute on function public.admin_assign_account_sport(uuid, jsonb, text) to authenticated;

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

select
    id,
    email,
    full_name,
    role,
    approval_status,
    assigned_sport_id,
    assigned_sport_name,
    public.app_is_overall_committee(id) as has_overall_committee_access
from public.user_profiles
where regexp_replace(lower(coalesce(assigned_sport_name, '')), '[^a-z0-9]+', '', 'g')
      in ('overallcommittee', 'overallcoordinator', 'overall')
order by email;
