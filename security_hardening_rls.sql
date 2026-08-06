-- CSC LIVE security hardening migration.
-- Review in Supabase SQL Editor before running in production.
-- This file strengthens role checks, protects profile role fields, and adds audit logging.

create extension if not exists pgcrypto;

create table if not exists public.security_audit_logs (
    id uuid primary key default gen_random_uuid(),
    actor_id uuid,
    actor_email text,
    action text not null,
    target_table text,
    target_id text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

alter table public.security_audit_logs enable row level security;

drop policy if exists "Admins can read security audit logs" on public.security_audit_logs;
create policy "Admins can read security audit logs"
on public.security_audit_logs
for select
to authenticated
using (public.app_is_admin());

drop policy if exists "No direct audit log writes" on public.security_audit_logs;
create policy "No direct audit log writes"
on public.security_audit_logs
for all
to authenticated
using (false)
with check (false);

create or replace function public.write_security_audit_log(
    p_action text,
    p_target_table text default null,
    p_target_id text default null,
    p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
    insert into public.security_audit_logs (
        actor_id,
        actor_email,
        action,
        target_table,
        target_id,
        metadata
    )
    values (
        auth.uid(),
        lower(trim(coalesce(auth.jwt() ->> 'email', ''))),
        left(trim(coalesce(p_action, 'unknown')), 120),
        nullif(trim(coalesce(p_target_table, '')), ''),
        nullif(trim(coalesce(p_target_id, '')), ''),
        coalesce(p_metadata, '{}'::jsonb)
    );
end;
$$;

revoke all on function public.write_security_audit_log(text, text, text, jsonb) from public;
grant execute on function public.write_security_audit_log(text, text, text, jsonb) to authenticated;

create or replace function public.prevent_profile_privilege_self_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() = old.id
       and (
           new.role is distinct from old.role
           or new.approval_status is distinct from old.approval_status
           or new.assigned_sport_id is distinct from old.assigned_sport_id
           or new.assigned_sport_name is distinct from old.assigned_sport_name
           or new.allowed_tabs is distinct from old.allowed_tabs
       ) then
        raise exception 'Users cannot change their own role, approval, sport assignment, or tab access.';
    end if;

    return new;
end;
$$;

drop trigger if exists prevent_profile_privilege_self_edit on public.user_profiles;
create trigger prevent_profile_privilege_self_edit
before update on public.user_profiles
for each row
execute function public.prevent_profile_privilege_self_edit();

create or replace function public.audit_user_profile_changes()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
    perform public.write_security_audit_log(
        tg_op || '_user_profile',
        'user_profiles',
        coalesce(new.id::text, old.id::text),
        jsonb_build_object(
            'old_role', old.role,
            'new_role', new.role,
            'old_status', old.approval_status,
            'new_status', new.approval_status,
            'old_assigned_sport_id', old.assigned_sport_id,
            'new_assigned_sport_id', new.assigned_sport_id
        )
    );
    return coalesce(new, old);
end;
$$;

drop trigger if exists audit_user_profile_changes on public.user_profiles;
create trigger audit_user_profile_changes
after update on public.user_profiles
for each row
when (
    old.role is distinct from new.role
    or old.approval_status is distinct from new.approval_status
    or old.assigned_sport_id is distinct from new.assigned_sport_id
    or old.assigned_sport_name is distinct from new.assigned_sport_name
)
execute function public.audit_user_profile_changes();

-- Make sure RLS is enabled on sensitive app tables.
alter table public.user_profiles enable row level security;
alter table public.attendance enable row level security;
alter table public.student_feedback enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.security_audit_logs force row level security;

-- Replace overly broad RFID cache policies if the cache exists.
do $$
begin
    if to_regclass('public.rfid_profiles') is not null then
        execute 'alter table public.rfid_profiles enable row level security';
        execute 'drop policy if exists "Allow public upsert rfid profiles" on public.rfid_profiles';
        execute 'drop policy if exists "Allow public update rfid profiles" on public.rfid_profiles';
        execute 'drop policy if exists "Allow public read rfid profiles" on public.rfid_profiles';
        execute 'create policy "Dashboard users can read rfid profiles" on public.rfid_profiles for select to authenticated using (public.app_is_dashboard_user())';
        execute 'create policy "Dashboard users can insert rfid profiles" on public.rfid_profiles for insert to authenticated with check (public.app_is_dashboard_user())';
        execute 'create policy "Dashboard users can update rfid profiles" on public.rfid_profiles for update to authenticated using (public.app_is_dashboard_user()) with check (public.app_is_dashboard_user())';
    end if;
end $$;

-- Optional stricter participant privacy. Run only after confirming the public registration
-- page does not need to list all participant rows.
-- drop policy if exists "Public can read participants" on public.participants;
-- create policy "Dashboard users can read participants"
-- on public.participants for select to authenticated
-- using (public.app_is_dashboard_user());
