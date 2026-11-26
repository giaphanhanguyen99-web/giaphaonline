# Account registration workflow worklist

Branch: `gia-pha-development-2026-11-25`

## Completed

- [x] Public registration request form collects email, full name, and phone.
- [x] Submission checks for a pending request with the same email and displays a clear Vietnamese message.
- [x] The database unique partial index remains the final protection against concurrent duplicate submissions.
- [x] Existing Google sign-in and permission loading keep users without active permission in visitor mode.

## Remaining before account registration is complete

- [ ] Confirm the allowed status values and Row Level Security policies for `family_registration_requests`.
- [x] Add a Root Admin review screen for pending requests, with explicit approve and reject actions (the button is visible only to the Root Admin account).
- [x] Draft server-side Supabase RPC functions that restrict reads and reviews to Root Admin, require a confirmed Auth email, provision only `member` or `editor`, and atomically record the request outcome and reviewer. The SQL is a Development artifact only; it has not been applied.
- [x] Require a confirmed Google/Auth account matching the request email before approval; the review UI explains when no matching account exists.
- [x] Handle already-provisioned non-pending accounts, stale requests, missing RPCs, and review errors without silently granting access.
- [ ] After the migration is reviewed and applied to the intended Development Supabase environment, verify the full flow with a safe test account.

## Safety boundary

The current registration table fields and the pending-email unique index are confirmed. The accepted request status values, table policies, and a secure server-side approval operation are not confirmed in the repository. A browser client must not receive a Supabase service-role key or directly administer Auth users.

The server-side review RPCs are drafted in `SUPABASE_REGISTRATION_REVIEW_FUNCTIONS.sql`. They have not been applied. Confirm allowed request status values and table policies, then obtain explicit approval before applying SQL to Supabase. Keep the Development UI work isolated from Production/main until the complete flow is reviewed and separately approved for release.
