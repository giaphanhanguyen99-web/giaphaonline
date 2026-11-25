-- Cội Nguồn: thông báo tang sự (development branch)
-- Chạy trong Supabase SQL Editor của dự án, sau khi xem lại.
create table if not exists public.family_funeral_notices (
  id uuid primary key default gen_random_uuid(),
  member_id text not null,
  deceased_name text not null,
  death_date date,
  death_time time,
  message text not null,
  funeral_date date,
  funeral_time time,
  funeral_location text,
  status text not null default 'published' check (status in ('published','archived')),
  confirmed_at timestamptz not null,
  confirmed_by uuid not null references auth.users(id),
  published_at timestamptz not null default now(),
  published_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.family_funeral_notices enable row level security;

-- Public viewers may read published notices only.
drop policy if exists "Public read published funeral notices" on public.family_funeral_notices;
create policy "Public read published funeral notices"
on public.family_funeral_notices for select
to anon, authenticated
using (status = 'published');

-- Only the designated administrator may create or modify notices.
drop policy if exists "Admin insert funeral notices" on public.family_funeral_notices;
create policy "Admin insert funeral notices"
on public.family_funeral_notices for insert
to authenticated
with check (auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
  and confirmed_by = auth.uid() and published_by = auth.uid());

drop policy if exists "Admin update funeral notices" on public.family_funeral_notices;
create policy "Admin update funeral notices"
on public.family_funeral_notices for update
to authenticated
using (auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid)
with check (auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid);

-- No DELETE policy: preserve published notice history.
