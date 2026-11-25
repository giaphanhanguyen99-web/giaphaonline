-- Đặt mức mặc định cho thông báo người trong gia phả qua đời là KHẨN CẤP.
-- Có thể chạy an toàn kể cả khi chưa chạy migration priority trước đó.

alter table public.family_funeral_notices
  add column if not exists priority text not null default 'urgent';

alter table public.family_funeral_notices
  alter column priority set default 'urgent';

alter table public.family_funeral_notices
  drop constraint if exists family_funeral_notices_priority_check;

alter table public.family_funeral_notices
  add constraint family_funeral_notices_priority_check
  check (priority in ('urgent', 'important', 'normal'));

-- Các thông báo tang sự đã có được đặt về Khẩn cấp.
-- Quản trị viên có thể điều chỉnh từng thông báo thành Quan trọng sau này.
update public.family_funeral_notices
set priority = 'urgent'
where priority is null or priority = 'important';
