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

drop policy if exists "Committee can update assigned sport matches" on public.scheduled_matches;
create policy "Committee can update assigned sport matches"
on public.scheduled_matches
for update
to authenticated
using (public.app_can_manage_match_sport(sport_id))
with check (public.app_can_manage_match_sport(sport_id));

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
