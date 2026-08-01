-- Add owner-controlled dashboard tab access for admin and committee accounts.
-- Run this in the Supabase SQL Editor for the CSC L.I.V.E. project.

alter table public.user_profiles
add column if not exists allowed_tabs jsonb not null default '[]'::jsonb;

create or replace function public.admin_set_account_allowed_tabs(
    target_user_id uuid,
    allowed_tabs jsonb
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
    current_admin_email text;
    cleaned_tabs jsonb;
begin
    select lower(trim(email))
    into current_admin_email
    from public.user_profiles
    where id = auth.uid()
      and lower(trim(role)) = 'admin'
      and lower(trim(approval_status)) = 'approved';

    if current_admin_email is distinct from 'centralstudentcouncil2026@gmail.com' then
        raise exception 'Only the main CSC admin account can assign dashboard tab access.';
    end if;

    select coalesce(jsonb_agg(distinct tab_name), '[]'::jsonb)
    into cleaned_tabs
    from jsonb_array_elements_text(coalesce(allowed_tabs, '[]'::jsonb)) as allowed_tab(tab_name)
    where tab_name in ('teams', 'games', 'participants', 'attendance', 'announcements', 'accounts');

    update public.user_profiles
    set allowed_tabs = cleaned_tabs
    where id = target_user_id
      and lower(trim(email)) <> 'centralstudentcouncil2026@gmail.com';

    if not found then
        raise exception 'Account profile not found or main admin access cannot be changed.';
    end if;
end
$$;

revoke all on function public.admin_set_account_allowed_tabs(uuid, jsonb) from public;
grant execute on function public.admin_set_account_allowed_tabs(uuid, jsonb) to authenticated;
