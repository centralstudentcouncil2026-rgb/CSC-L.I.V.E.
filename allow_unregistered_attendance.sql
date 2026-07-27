alter table if exists public.attendance
    alter column participant_id drop not null;

alter table if exists public.attendance
    add column if not exists attendance_rfid_value text,
    add column if not exists attendance_course text,
    add column if not exists attendance_source text;
