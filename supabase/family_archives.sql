-- Kho tư liệu dòng họ
-- Chạy toàn bộ script này trong Supabase SQL Editor của dự án gia phả.

create table if not exists public.family_archives (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null check (category in (
    'Ảnh xưa của dòng họ',
    'Gia phả và văn bản',
    'Nhà thờ họ và di tích',
    'Sự kiện dòng họ',
    'Tài liệu và kỷ vật'
  )),
  archive_date text,
  contributor text,
  related_member_id text,
  description text,
  is_public boolean not null default false,
  attachments jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.family_archives enable row level security;

grant select on public.family_archives to anon, authenticated;
grant insert, update, delete on public.family_archives to authenticated;

drop policy if exists "Public can read public family archives" on public.family_archives;
create policy "Public can read public family archives"
on public.family_archives for select
using (
  is_public = true
  or auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
);

drop policy if exists "Admin can insert family archives" on public.family_archives;
create policy "Admin can insert family archives"
on public.family_archives for insert to authenticated
with check (
  auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
  and (created_by is null or created_by = auth.uid())
);

drop policy if exists "Admin can update family archives" on public.family_archives;
create policy "Admin can update family archives"
on public.family_archives for update to authenticated
using (auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid)
with check (auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid);

drop policy if exists "Admin can delete family archives" on public.family_archives;
create policy "Admin can delete family archives"
on public.family_archives for delete to authenticated
using (auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid);

-- Kho tệp riêng tư; khách chỉ nhận được liên kết có thời hạn cho tệp thuộc tư liệu công khai.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'family-archives',
  'family-archives',
  false,
  52428800,
  array[
    'image/jpeg','image/png','image/webp',
    'application/pdf','application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'audio/mpeg','audio/wav','audio/x-wav','audio/mp4','audio/x-m4a',
    'audio/aac','audio/ogg','application/ogg'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = 52428800,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Readers can access public archive files" on storage.objects;
create policy "Readers can access public archive files"
on storage.objects for select
using (
  bucket_id = 'family-archives'
  and (
    auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
    or exists (
      select 1
      from public.family_archives a
      where a.is_public = true
        and a.attachments @> jsonb_build_array(jsonb_build_object('path', name))
    )
  )
);

drop policy if exists "Admin can upload archive files" on storage.objects;
create policy "Admin can upload archive files"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'family-archives'
  and auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
);

drop policy if exists "Admin can update archive files" on storage.objects;
create policy "Admin can update archive files"
on storage.objects for update to authenticated
using (
  bucket_id = 'family-archives'
  and auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
)
with check (
  bucket_id = 'family-archives'
  and auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
);

drop policy if exists "Admin can delete archive files" on storage.objects;
create policy "Admin can delete archive files"
on storage.objects for delete to authenticated
using (
  bucket_id = 'family-archives'
  and auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
);
