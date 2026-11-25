# Checkpoint — Thông báo tang sự

- Branch: `gia-pha-development-2026-11-25` (development only)
- Current phase: implement only the first three agreed items.
- Scope: add a dedicated admin entry; select an existing deceased member from family records; provide a draft form for announcement text and funeral date/time/location.
- Not implemented in this phase: multi-step confirmations, publication, push notifications, or sending to family members.
- Safety design: no announcement should be broadcast from this draft form. Future publication must have explicit, multiple confirmations.
- Preserve existing OAuth, Supabase configuration, and family data.
- Work is incremental; the user tests this phase before proceeding.
