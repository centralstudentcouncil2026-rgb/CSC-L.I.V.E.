# CSC LIVE Security Test Checklist

## Admin and Committee Page Access

- Anonymous visitor opens `AdminDashboard.html`: dashboard content must not render; user must be redirected to login.
- Anonymous visitor opens `CommitteeDashboard.html`: dashboard content must not render; user must be redirected to login.
- User edits `sessionStorage.user` to `{"role":"admin"}` without a Supabase session: access must fail.
- Suspended, hold, rejected, or pending account opens Admin/Committee: access must fail.
- Committee account opens Admin: access must fail.
- Approved admin opens Admin: access succeeds.
- Approved committee opens Committee: access succeeds.

## Direct Supabase API Checks

- Anonymous request to protected tables such as `attendance`, `student_feedback`, `user_profiles`, `messages`, and `security_audit_logs` must fail.
- Committee user attempts to update their own `role`, `approval_status`, `assigned_sport_id`, `assigned_sport_name`, or `allowed_tabs`: request must fail.
- Committee user attempts to delete attendance, profiles, or audit logs: request must fail.
- Admin can read `security_audit_logs`.

## Public Pages

- Student dashboard can still read public schedules, standings, game history, announcements, and evaluation link.
- Registration page can still submit participant registrations.
- Public users cannot read unnecessary private participant information unless intentionally allowed by reviewed RLS policies.

## Browser/Input Checks

- Submit stored-XSS payloads such as `<img src=x onerror=alert(1)>` in feedback/announcements/matches and verify they render as text.
- Try disallowed upload file types and oversized files.
- Try changing record IDs in requests from browser dev tools.
