-- Shared evaluation form link setting for admin and student dashboards.
-- Run this in the Supabase SQL Editor for the CSC L.I.V.E. project.

create table if not exists public.app_settings (
    setting_key text primary key,
    setting_value text,
    updated_by uuid references public.user_profiles(id) on delete set null,
    updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;

drop policy if exists "Anyone can read app settings" on public.app_settings;
create policy "Anyone can read app settings"
on public.app_settings
for select
to anon, authenticated
using (true);

drop policy if exists "Approved admins can insert app settings" on public.app_settings;
create policy "Approved admins can insert app settings"
on public.app_settings
for insert
to authenticated
with check (
    exists (
        select 1
        from public.user_profiles profile
        where profile.id = auth.uid()
          and lower(trim(profile.role)) = 'admin'
          and lower(trim(profile.approval_status)) = 'approved'
    )
);

drop policy if exists "Approved admins can update app settings" on public.app_settings;
create policy "Approved admins can update app settings"
on public.app_settings
for update
to authenticated
using (
    exists (
        select 1
        from public.user_profiles profile
        where profile.id = auth.uid()
          and lower(trim(profile.role)) = 'admin'
          and lower(trim(profile.approval_status)) = 'approved'
    )
)
with check (
    exists (
        select 1
        from public.user_profiles profile
        where profile.id = auth.uid()
          and lower(trim(profile.role)) = 'admin'
          and lower(trim(profile.approval_status)) = 'approved'
    )
);

do $$
begin
    alter publication supabase_realtime add table public.app_settings;
exception
    when duplicate_object then null;
    when undefined_object then null;
end $$;
