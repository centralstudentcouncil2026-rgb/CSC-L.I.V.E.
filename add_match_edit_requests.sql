create table if not exists public.match_edit_requests (
    id uuid primary key default gen_random_uuid(),
    match_id bigint not null references public.scheduled_matches(id) on delete cascade,
    requested_by text,
    requested_by_name text,
    requested_payload jsonb not null,
    status text not null default 'pending',
    reviewed_by text,
    requested_at timestamptz not null default now(),
    reviewed_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint match_edit_requests_status_check check (status in ('pending', 'approved', 'rejected'))
);

create index if not exists match_edit_requests_match_idx
on public.match_edit_requests(match_id);

create index if not exists match_edit_requests_status_idx
on public.match_edit_requests(status, requested_at desc);

create unique index if not exists match_edit_requests_one_pending_per_match_idx
on public.match_edit_requests(match_id)
where status = 'pending';

create or replace function public.set_match_edit_requests_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists set_match_edit_requests_updated_at on public.match_edit_requests;
create trigger set_match_edit_requests_updated_at
before update on public.match_edit_requests
for each row
execute function public.set_match_edit_requests_updated_at();

alter table public.match_edit_requests enable row level security;

drop policy if exists "Match edit requests are readable by dashboard users" on public.match_edit_requests;
create policy "Match edit requests are readable by dashboard users"
on public.match_edit_requests
for select
to authenticated, anon
using (true);

drop policy if exists "Committee can create match edit requests" on public.match_edit_requests;
create policy "Committee can create match edit requests"
on public.match_edit_requests
for insert
to authenticated, anon
with check (true);

drop policy if exists "Admins can review match edit requests" on public.match_edit_requests;
create policy "Admins can review match edit requests"
on public.match_edit_requests
for update
to authenticated, anon
using (true)
with check (true);

do $$
begin
    alter publication supabase_realtime add table public.match_edit_requests;
exception
    when duplicate_object then null;
    when undefined_object then null;
end $$;
