# Account registration workflow worklist

Branch: `gia-pha-development-2026-11-25`

## Completed

- [x] Public registration request form collects email, full name, and phone.
- [x] Submission checks for a pending request with the same email and displays a clear Vietnamese message. The database partial unique index remains the final protection against concurrent duplicates.
- [x] Registration copy explains the required order: submit the request, then sign in with Google using the same email.
- [x] Root Admin-only review screen lists pending requests using the existing Root SELECT policy.
- [x] Review actions call the existing `approve_family_registration` and `reject_family_registration` RPCs. Approval provisions the default `member` role.
- [x] Error handling covers missing/expired requests, non-confirmed Auth accounts, non-Root callers, conflicting permission status, and RPC failures.
- [x] Applied Supabase migration `harden_family_registration_functions` (version `20261126085832`) to harden the existing submit/approve/reject RPCs. It sets a fixed `pg_catalog` search path, validates inputs, confirms the Auth email before approval, refuses to reactivate non-pending permission records, and restricts function execution grants. It does not modify table rows.

## Remaining before account registration is fully verified

- [ ] Verify the Development preview and complete Google Auth → request → Root review flow with a safe test account and test request. The connected project has no separate Supabase Development branch, and the user declined creating one, so avoid using a real family member's account or request for testing.

## Root account permission management

- [x] Added a Root-only account management card to Quản trị gia phả and a dialog listing accounts that already have permission records.
- [x] Root can raise/lower roles (member, editor, admin) and change account status (pending, active, suspended, revoked).
- [x] Sensitive actions show a confirmation; active access cannot be granted while the Auth email is unverified.
- [x] Added fixed-search-path, Root-guarded RPCs for listing and updating permissions. Updates compare the expected old role/status to prevent overwriting a concurrent change.
- [x] Applied Supabase migration root_account_permission_management (version 20261126091855). It creates/replaces functions and grants only; it changes no tables or rows.

## Environment and safety notes

- Live metadata confirmed the request status constraint (`pending`, `approved`, `rejected`), RLS enabled, Root SELECT on registration requests, and Root ALL on `family_user_permissions`.
- The migration changed function definitions only. No registration rows, permission rows, member records, or files were changed.
- The Supabase project has no Development branch. The user authorized Supabase changes and declined creating a billed branch; the authorized hardening migration was applied to the connected project.
- GitHub `main` and Production code were not changed. The website work remains on `gia-pha-development-2026-11-25`.
- A generic Supabase security advisor warning remains for SECURITY DEFINER functions exposed to authenticated/anon roles. Registration functions have fixed search paths, explicit Root UID guards where required, and narrow EXECUTE grants; the public submit RPC intentionally accepts anon requests.
- Do not expose a service-role key in the browser.
