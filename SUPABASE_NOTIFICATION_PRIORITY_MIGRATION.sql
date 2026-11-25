-- Migration: phân cấp thông báo dòng họ
-- Chạy một lần trong Supabase SQL Editor trước khi thử phát hành thông báo theo cấp độ.

alter table public.family_funeral_notices
  add column if not exists priority text not null default 'important';

alter table public.family_funeral_notices
  drop constraint if exists family_funeral_notices_priority_check;

alter table public.family_funeral_notices
  add constraint family_funeral_notices_priority_check
  check (priority in ('urgent', 'important', 'normal'));

-- Các thông báo tang sự hiện có mặc định là QUAN TRỌNG.
update public.family_funeral_notices
set priority = 'important'
where priority is null;

