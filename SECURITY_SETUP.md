# CSC LIVE Security Setup

CSC LIVE is hosted on GitHub Pages, so every HTML, JavaScript, route, URL, and Supabase anon key shipped to the browser is public. The Admin and Committee pages are hidden until Supabase verifies the logged-in account, but real protection must come from Supabase Auth and Row Level Security.

## Required Supabase Steps

1. Run `security_hardening_rls.sql` in the Supabase SQL Editor after reviewing it.
2. Confirm Row Level Security is enabled on every table exposed to the browser.
3. Keep the anon key in frontend code only. Never add a service-role key to any HTML, JavaScript, GitHub Pages file, or browser variable.
4. Rotate any key that was ever committed as a secret or service-role key.
5. In Authentication settings, require email confirmation if practical and disable unused auth providers.
6. Review public policies. Public reads should be limited to schedules, standings, announcements, and other intentionally public event information.
7. Sensitive operations such as creating admins, deleting accounts, changing roles, bulk imports, or changing finalized scores should be done through Supabase RPC or Edge Functions that re-check `auth.uid()` and `user_profiles`.

## Required GitHub Steps

1. Enforce HTTPS for GitHub Pages.
2. Enable GitHub secret scanning and push protection.
3. Enable branch protection for `main`.
4. Do not store `.env`, private keys, database dumps, or service-role keys in the repo.
5. If using GitHub Actions later, set least-privilege workflow permissions.

## Manual Checks

- Open `AdminDashboard.html` in a private/incognito browser. It should show only “Checking admin access...” and then redirect to login.
- Try editing `sessionStorage.user` in browser dev tools. The dashboard may briefly start checking, but Supabase must reject unauthorized data requests.
- In Supabase SQL Editor, verify `security_audit_logs` is readable only by approved admins.
