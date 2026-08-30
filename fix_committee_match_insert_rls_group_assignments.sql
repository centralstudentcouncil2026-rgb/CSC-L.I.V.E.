-- Fix committee scheduled_matches insert/update RLS for sport-group assignments.
-- Run this in the Supabase SQL Editor for the active CSC L.I.V.E. project.
--
-- Why: committee accounts can be assigned to a general sport group such as
-- "Volleyball", while scheduled_matches rows point to concrete categories such
-- as "Volleyball Boys". This keeps the database policy aligned with the
-- dashboard's assignment picker.

create or replace function public.app_sport_base_key(sport_name text)
returns text
language sql
immutable
set search_path = public
as $$
    select regexp_replace(
        regexp_replace(
            regexp_replace(
                lower(trim(coalesce(sport_name, ''))),
                '[()'']',
                ' ',
                'g'
            ),
            '[-:/]+',
            ' ',
            'g'
        ),
        '\s+',
        ' ',
        'g'
    )
$$;

create or replace function public.app_sport_group_key(sport_name text)
returns text
language sql
immutable
set search_path = public
as $$
    with normalized as (
        select public.app_sport_base_key(sport_name) as name
    )
    select regexp_replace(
        regexp_replace(
            name,
            '\s+(a|b|c|d|e|boys|boy|girls|girl|men|man|mens|male|women|woman|womens|female|mixed|singles|single|doubles|double|relay|backstroke|butterfly|freestyle|division|div|category|cat|bracket|pool|group|class)(\s.*)?$',
            '',
            'i'
        ),
        '[^a-z0-9]+',
        '',
        'g'
    )
    from normalized
$$;

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
            join public.sports sport
              on sport.id = match_sport_id
            where profile.id = auth.uid()
              and lower(trim(profile.role)) = 'committee'
              and lower(trim(profile.approval_status)) = 'approved'
              and (
                  profile.assigned_sport_id = match_sport_id
                  or regexp_replace(lower(coalesce(profile.assigned_sport_name, '')), '[^a-z0-9]+', '', 'g')
                        = regexp_replace(lower(coalesce(sport.sport_name, '')), '[^a-z0-9]+', '', 'g')
                  or public.app_sport_group_key(profile.assigned_sport_name)
                        = public.app_sport_group_key(sport.sport_name)
                  or (
                      length(public.app_sport_group_key(profile.assigned_sport_name)) > 0
                      and (
                          regexp_replace(lower(coalesce(sport.sport_name, '')), '[^a-z0-9]+', '', 'g')
                              like '%' || public.app_sport_group_key(profile.assigned_sport_name) || '%'
                          or regexp_replace(lower(coalesce(profile.assigned_sport_name, '')), '[^a-z0-9]+', '', 'g')
                              like '%' || public.app_sport_group_key(sport.sport_name) || '%'
                      )
                  )
              )
        ),
        false
    )
$$;

revoke all on function public.app_sport_base_key(text) from public;
revoke all on function public.app_sport_group_key(text) from public;
revoke all on function public.app_is_overall_committee(uuid) from public;
revoke all on function public.app_can_manage_match_sport(bigint) from public;
grant execute on function public.app_sport_base_key(text) to authenticated;
grant execute on function public.app_sport_group_key(text) to authenticated;
grant execute on function public.app_is_overall_committee(uuid) to authenticated;
grant execute on function public.app_can_manage_match_sport(bigint) to authenticated;

alter table public.scheduled_matches enable row level security;

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
