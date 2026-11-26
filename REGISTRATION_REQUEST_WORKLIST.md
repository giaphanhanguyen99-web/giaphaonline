# Account registration workflow worklist

Branch: `gia-pha-development-2026-11-25`

## Completed

- [x] Public registration request form collects email, full name, and phone.
- [x] Submission checks for a pending request with the same email and displays a clear Vietnamese message.
- [x] The database unique partial index remains the final protection against concurrent duplicate submissions.
- [x] Existing Google sign-in and permission loading keep users without active permission in visitor mode.

## Remaining before account registration is complete

- [x] Confirm table metadata: registration statuses are constrained to `pending` / `approved` / `rejected`; RLS is enabled; Root Admin has SELECT on requests and ALL on permissions, with no request UPDATE policy. The privileged review operation therefore needs a narrowly scoped server-side path.
- [x] Add a Root Admin review screen for pending requests, with explicit approve and reject actions (the button is visible only to the Root Admin account).
- [x] Draft invoker-only public RPCs and isolate the privileged update in a `private` schema helper. The helper checks Root Admin, requires a confirmed Auth email, provisions only `member` or `editor`, refuses to overwrite non-pending permissions, and updates review metadata atomically. The SQL is a Development artifact only; it has not been applied.
- [x] Require a confirmed Google/Auth account matching the request email before approval; the review UI explains when no matching account exists.
- [x] Handle already-provisioned non-pending accounts, stale requests, missing RPCs, and review errors without silently granting access.
- [ ] Create or select an isolated Supabase Development branch, confirm its cost, and verify the `private` schema is not exposed in the Data API settings.
- [ ] Apply the reviewed RPC migration only on that Development branch, then verify the full flow with a safe test account.

## Safety boundary

The current registration table fields and the pending-email unique index are confirmed. The accepted request status values, table policies, and a secure server-side approval operation are not confirmed in the repository. A browser client must not receive a Supabase service-role key or directly administer Auth users.

The server-side review RPCs are drafted in `SUPABASE_REGISTRATION_REVIEW_FUNCTIONS.sql`. They have not been applied. Read-only checks confirmed the current status constraint and RLS policies on the connected project. That project has no separate Supabase Development branch, so do not apply SQL there. A separate branch requires a cost confirmation. Verify `private` is not in the Data API exposed-schema list before applying the SQL to an isolated branch. Keep the Development UI work isolated from Production/main until the complete flow is reviewed and separately approved for release.
