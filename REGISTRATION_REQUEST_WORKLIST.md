# Account registration workflow worklist

Branch: `gia-pha-development-2026-11-25`

## Completed

- [x] Public registration request form collects email, full name, and phone.
- [x] Submission checks for a pending request with the same email and displays a clear Vietnamese message.
- [x] The database unique partial index remains the final protection against concurrent duplicate submissions.
- [x] Existing Google sign-in and permission loading keep users without active permission in visitor mode.

## Remaining before account registration is complete

- [ ] Confirm the allowed status values and Row Level Security policies for `family_registration_requests`.
- [ ] Add a Root Admin review screen for pending requests, with explicit approve and reject actions.
- [ ] Add a server-side Supabase function that, in one transaction, verifies the caller is the Root Admin, finds the authenticated Google account by the request email, provisions or updates `family_user_permissions`, and records `reviewed_at` / `reviewed_by` plus the request outcome.
- [ ] Require the applicant to sign in with Google using the same email as the request before approval can activate access; explain the next step when no matching Auth account exists.
- [ ] Handle already-provisioned accounts, stale requests, database errors, and repeated review attempts without granting unintended access.
- [ ] Verify the complete flow in a Development preview with a safe test account, without creating a real registration request or changing real Supabase data during code review.

## Safety boundary

The current registration table fields and the pending-email unique index are confirmed. The accepted request status values, table policies, and a secure server-side approval operation are not confirmed in the repository. A browser client must not receive a Supabase service-role key or directly administer Auth users.

The server-side approval function requires a reviewed Supabase SQL change. This worklist does not run SQL or change Supabase schema or data. Keep the Development UI work isolated from Production/main until the complete flow is reviewed and separately approved for release.
