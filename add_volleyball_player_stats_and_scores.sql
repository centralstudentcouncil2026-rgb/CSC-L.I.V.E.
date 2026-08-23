alter table public.basketball_match_player_stats
    add column if not exists receiving integer not null default 0,
    add column if not exists digging integer not null default 0,
    add column if not exists setting integer not null default 0,
    add column if not exists attacks integer not null default 0,
    add column if not exists blockings integer not null default 0,
    add column if not exists service_ace integer not null default 0;

do $$
begin
    alter table public.basketball_match_player_stats
        add constraint basketball_match_player_stats_receiving_nonnegative check (receiving >= 0);
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.basketball_match_player_stats
        add constraint basketball_match_player_stats_digging_nonnegative check (digging >= 0);
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.basketball_match_player_stats
        add constraint basketball_match_player_stats_setting_nonnegative check (setting >= 0);
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.basketball_match_player_stats
        add constraint basketball_match_player_stats_attacks_nonnegative check (attacks >= 0);
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.basketball_match_player_stats
        add constraint basketball_match_player_stats_blockings_nonnegative check (blockings >= 0);
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.basketball_match_player_stats
        add constraint basketball_match_player_stats_service_ace_nonnegative check (service_ace >= 0);
exception
    when duplicate_object then null;
end $$;

create table if not exists public.volleyball_match_period_scores (
    id uuid primary key default gen_random_uuid(),
    match_id bigint not null references public.scheduled_matches(id) on delete cascade,
    team_id bigint not null references public.sports_leaderboard(id) on delete cascade,
    team_name text not null,
    game_period integer not null default 1,
    points integer not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint volleyball_match_period_scores_period_check check (game_period between 1 and 5),
    constraint volleyball_match_period_scores_points_nonnegative check (points >= 0),
    constraint volleyball_match_period_scores_unique_team_period unique (match_id, team_id, game_period)
);

create index if not exists volleyball_match_period_scores_match_idx
    on public.volleyball_match_period_scores(match_id);

create index if not exists volleyball_match_period_scores_period_idx
    on public.volleyball_match_period_scores(match_id, team_id, game_period);

alter table public.volleyball_match_period_scores enable row level security;

drop policy if exists "Volleyball scores are readable by dashboard users" on public.volleyball_match_period_scores;
create policy "Volleyball scores are readable by dashboard users"
on public.volleyball_match_period_scores
for select
to authenticated, anon
using (true);

drop policy if exists "Committee and admin can insert volleyball scores" on public.volleyball_match_period_scores;
create policy "Committee and admin can insert volleyball scores"
on public.volleyball_match_period_scores
for insert
to authenticated, anon
with check (true);

drop policy if exists "Committee and admin can update volleyball scores" on public.volleyball_match_period_scores;
create policy "Committee and admin can update volleyball scores"
on public.volleyball_match_period_scores
for update
to authenticated, anon
using (true)
with check (true);

drop policy if exists "Committee and admin can delete volleyball scores" on public.volleyball_match_period_scores;
create policy "Committee and admin can delete volleyball scores"
on public.volleyball_match_period_scores
for delete
to authenticated, anon
using (true);

do $$
begin
    alter publication supabase_realtime add table public.volleyball_match_period_scores;
exception
    when duplicate_object then null;
    when undefined_object then null;
end $$;
