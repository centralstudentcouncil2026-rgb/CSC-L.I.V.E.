-- Require committee account registrations to choose a sport assignment.
-- Admin can still change assignments later with admin_assign_account_sport.

create or replace function public.save_pending_user_profile(
    p_email text,
    p_full_name text,
    p_mobile_number text,
    p_role text,
    p_assigned_sport_id jsonb default null,
    p_assigned_sport_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
    current_user_id uuid := auth.uid();
    normalized_role text := lower(trim(coalesce(p_role, '')));
    authenticated_email text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
    resolved_sport_id bigint;
    resolved_sport_name text := nullif(trim(coalesce(p_assigned_sport_name, '')), '');
begin
    if current_user_id is null then
        raise exception 'You must be logged in to create a profile.';
    end if;

    if normalized_role not in ('admin', 'committee') then
        raise exception 'Invalid dashboard role.';
    end if;

    if authenticated_email = ''
       or authenticated_email <> lower(trim(coalesce(p_email, ''))) then
        raise exception 'The authenticated email does not match the registered account.';
    end if;

    if p_assigned_sport_id is not null and p_assigned_sport_id <> 'null'::jsonb then
        resolved_sport_id := trim(both '"' from p_assigned_sport_id::text)::bigint;
    end if;

    if normalized_role = 'committee' and resolved_sport_id is null and resolved_sport_name is null then
        raise exception 'Committee accounts must choose a sport assignment.';
    end if;

    if normalized_role = 'committee' and lower(coalesce(resolved_sport_name, '')) = 'overall committee' then
        raise exception 'Overall Committee access can only be assigned by an admin.';
    end if;

    insert into public.user_profiles (
        id, email, full_name, mobile_number, role, approval_status,
        reviewed_at, reviewed_by, assigned_sport_id, assigned_sport_name
    )
    values (
        current_user_id, trim(p_email), trim(p_full_name), trim(p_mobile_number),
        normalized_role, 'pending', null, null, resolved_sport_id, resolved_sport_name
    )
    on conflict (id)
    do update set
        email = excluded.email,
        full_name = excluded.full_name,
        mobile_number = excluded.mobile_number,
        role = excluded.role,
        assigned_sport_id = excluded.assigned_sport_id,
        assigned_sport_name = excluded.assigned_sport_name
    where lower(trim(public.user_profiles.approval_status)) = 'pending';

    return current_user_id;
end
$$;

revoke all on function public.save_pending_user_profile(text, text, text, text, jsonb, text) from public;
grant execute on function public.save_pending_user_profile(text, text, text, text, jsonb, text) to authenticated;
