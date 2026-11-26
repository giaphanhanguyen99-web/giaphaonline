-- 62 mục Thánh mặc định trích nguyên vẹn từ SAINTS_DEF trong index.html
-- Chạy trong Supabase SQL Editor. Không xóa/sửa dữ liệu gia phả hoặc family_settings.
-- Chạy lại an toàn: mục trùng tên + ngày lễ sẽ được giữ nguyên (DO NOTHING).

begin;

create table if not exists public.family_saints (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  feast_day text not null check (feast_day ~ '^(0[1-9]|[12][0-9]|3[01])/(0[1-9]|1[0-2])$'),
  description text not null default '',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint family_saints_name_feast_day_unique unique (name, feast_day)
);

alter table public.family_saints enable row level security;

drop policy if exists "Public read active family saints" on public.family_saints;
create policy "Public read active family saints"
on public.family_saints for select
to anon, authenticated
using (is_active = true);

drop policy if exists "Admin insert family saints" on public.family_saints;
create policy "Admin insert family saints"
on public.family_saints for insert
to authenticated
with check (auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid);

drop policy if exists "Admin update family saints" on public.family_saints;
create policy "Admin update family saints"
on public.family_saints for update
to authenticated
using (auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid)
with check (auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid);

drop policy if exists "Admin delete family saints" on public.family_saints;
create policy "Admin delete family saints"
on public.family_saints for delete
to authenticated
using (auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid);

grant select on public.family_saints to anon, authenticated;
grant insert, update, delete on public.family_saints to authenticated;

insert into public.family_saints (name, feast_day, description, sort_order, is_active)
values
  ('Anê', '21/01', 'Trinh nữ, Tử đạo', 1, true),
  ('Phaolô Trở Lại', '25/01', '', 2, true),
  ('Tôma Aquinô', '28/01', 'Linh mục, Tiến sĩ Hội Thánh', 3, true),
  ('Gioan Bosco', '31/01', 'Linh mục', 4, true),
  ('Agatha', '05/02', 'Trinh nữ, Tử đạo', 5, true),
  ('Phaolô Miki', '06/02', 'Tử đạo, cùng các bạn', 6, true),
  ('Scholastica', '10/02', 'Trinh nữ', 7, true),
  ('Patrick', '17/03', 'Giám mục', 8, true),
  ('Giuse', '19/03', 'Bạn trăm năm Đức Maria', 9, true),
  ('Máccô', '25/04', 'Thánh sử', 10, true),
  ('Catarina thành Siena', '29/04', 'Trinh nữ, Tiến sĩ Hội Thánh', 11, true),
  ('Giuse Thợ', '01/05', '', 12, true),
  ('Philipphê', '03/05', 'Tông đồ', 13, true),
  ('Giacôbê', '03/05', 'Tông đồ', 14, true),
  ('Mátthia', '14/05', 'Tông đồ', 15, true),
  ('Gioan thành Arc', '30/05', '', 16, true),
  ('Antôn thành Padova', '13/06', 'Linh mục, Tiến sĩ Hội Thánh', 17, true),
  ('Gioan Tẩy Giả', '24/06', 'Sinh nhật', 18, true),
  ('Phêrô', '29/06', 'Tông đồ', 19, true),
  ('Phaolô', '29/06', 'Tông đồ', 20, true),
  ('Tôma', '03/07', 'Tông đồ', 21, true),
  ('Bênêđíctô', '11/07', 'Viện phụ', 22, true),
  ('Maria Mađalêna', '22/07', '', 23, true),
  ('Giacôbê', '25/07', 'Tông đồ', 24, true),
  ('Gioakim', '26/07', 'Song thân Đức Maria', 25, true),
  ('Anna', '26/07', 'Song thân Đức Maria', 26, true),
  ('Mácta', '29/07', '', 27, true),
  ('Maria', '29/07', '', 28, true),
  ('Ladarô', '29/07', '', 29, true),
  ('Gioan Maria Vianney', '04/08', 'Linh mục', 30, true),
  ('Đaminh', '08/08', 'Linh mục', 31, true),
  ('Têrêsa Bênêđicta Thánh Giá', '09/08', '', 32, true),
  ('Lôrensô', '10/08', 'Phó tế, Tử đạo', 33, true),
  ('Clara', '11/08', 'Trinh nữ', 34, true),
  ('Maximilianô Kolbe', '14/08', 'Linh mục, Tử đạo', 35, true),
  ('Báctôlômêô', '24/08', 'Tông đồ', 36, true),
  ('Mônica', '27/08', '', 37, true),
  ('Augustinô', '28/08', 'Giám mục, Tiến sĩ Hội Thánh', 38, true),
  ('Grêgôriô Cả', '03/09', 'Giáo hoàng, Tiến sĩ Hội Thánh', 39, true),
  ('Têrêsa thành Calcutta', '05/09', '', 40, true),
  ('Mátthêu', '21/09', 'Tông đồ, Thánh sử', 41, true),
  ('Piô Năm Dấu', '23/09', 'Linh mục', 42, true),
  ('Vinh Sơn Phaolô', '27/09', 'Linh mục', 43, true),
  ('Micae', '29/09', 'Tổng lãnh Thiên thần', 44, true),
  ('Gabriel', '29/09', 'Tổng lãnh Thiên thần', 45, true),
  ('Raphael', '29/09', 'Tổng lãnh Thiên thần', 46, true),
  ('Têrêsa Hài Đồng Giêsu', '01/10', 'Trinh nữ, Tiến sĩ Hội Thánh', 47, true),
  ('Phanxicô Assisi', '04/10', '', 48, true),
  ('Têrêsa Avila', '15/10', 'Trinh nữ, Tiến sĩ Hội Thánh', 49, true),
  ('Luca', '18/10', 'Thánh sử', 50, true),
  ('Gioan Phaolô II', '22/10', 'Giáo hoàng', 51, true),
  ('Simon', '28/10', 'Tông đồ', 52, true),
  ('Giuđa', '28/10', 'Tông đồ', 53, true),
  ('Martinô de Porres', '03/11', 'Tu sĩ', 54, true),
  ('Cêcilia', '22/11', 'Trinh nữ, Tử đạo', 55, true),
  ('Anrê', '30/11', 'Tông đồ', 56, true),
  ('Phanxicô Xaviê', '03/12', 'Linh mục', 57, true),
  ('Nicôla', '06/12', 'Giám mục', 58, true),
  ('Lucia', '13/12', 'Trinh nữ, Tử đạo', 59, true),
  ('Gioan Thánh Giá', '14/12', 'Linh mục, Tiến sĩ Hội Thánh', 60, true),
  ('Stêphanô', '26/12', 'Tử đạo tiên khởi', 61, true),
  ('Gioan', '27/12', 'Tông đồ, Thánh sử', 62, true)
on conflict (name, feast_day) do nothing;

commit;

-- Kiểm tra: nếu bảng ban đầu trống, tổng số phải là 62.
select count(*) as tong_so_thanh,
       count(*) filter (where is_active) as dang_hoat_dong
from public.family_saints;

select sort_order, name, feast_day, description
from public.family_saints
order by sort_order, name;
