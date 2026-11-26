-- Cội Nguồn P3: Web Push subscriptions for authenticated family accounts.
-- Apply only after reviewing the Development implementation and confirming the target Supabase project.
create table if not exists public.family_push_subscriptions (
  endpoint text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  subscription jsonb not null check (jsonb_typeof(subscription) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.family_push_subscriptions enable row level security;

-- The Edge Function validates the caller and is the only role allowed to manage
-- subscriptions. Browser clients must never read other users' push endpoints.
revoke all on table public.family_push_subscriptions from public, anon, authenticated;
grant all on table public.family_push_subscriptions to service_role;

comment on table public.family_push_subscriptions is
  'Private Web Push endpoint registrations, managed only by the authenticated push Edge Function.';
