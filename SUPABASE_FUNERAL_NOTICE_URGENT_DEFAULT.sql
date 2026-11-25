-- Đặt mức mặc định cho thông báo người trong gia phả qua đời là KHẨN CẤP.
-- Chạy một lần trong Supabase SQL Editor.
-- Quản trị viên vẫn có thể chọn QUAN TRỌNG khi xét vai vế và hoàn cảnh.

alter table public.family_funeral_notices
  alter column priority set default 'urgent';

update public.family_funeral_notices
set priority = 'urgent'
where priority is null or priority = 'important';
