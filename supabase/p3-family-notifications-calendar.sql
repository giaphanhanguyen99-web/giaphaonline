-- P3: unified family notifications, calendar events, audience targeting, and history
create table if not exists public.family_notifications (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in (
    'member_deceased','serious_incident','funeral_schedule','anniversary_change',
    'family_major_event','family_activity','birthday','anniversary','family_event','general'
  )),
  title text not null check (length(btrim(title)) between 2 and 180),
  body text not null default '' check (length(body) <= 8000),
  priority text not null default 'normal' check (priority in ('urgent','important','normal')),
  related_member_id text references public.family_members(id) on delete set null,
  event_date date,
  event_time time,
  event_end_date date,
  event_end_time time,
  event_location text,
  is_all_day boolean not null default false,
  repeat_annually boolean not null default false,
  remind_before_minutes integer not null default 1440 check (remind_before_minutes between 0 and 525600),
  send_at timestamptz not null default now(),
  expires_at timestamptz,
  audience_type text not null default 'all' check (audience_type in ('all','roles','members')),
  audience_roles text[] not null default array['member','editor','admin']::text[],
  recipient_member_ids text[] not null default '{}'::text[],
  is_public boolean not null default false,
  status text not null default 'draft' check (status in ('draft','scheduled','published','archived','deleted')),
  dedupe_key text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id) on delete set null,
  constraint family_notifications_event_window_check
    check (event_end_date is null or event_date is null or event_end_date >= event_date),
  constraint family_notifications_roles_check
    check (audience_roles <@ array['member','editor','admin']::text[])
);
create unique index if not exists family_notifications_dedupe_key_unique
  on public.family_notifications (dedupe_key)
  where dedupe_key is not null and status <> 'deleted';
create index if not exists family_notifications_schedule_idx
  on public.family_notifications (status, send_at);
create index if not exists family_notifications_event_date_idx
  on public.family_notifications (event_date)
  where event_date is not null;

alter table public.family_notifications enable row level security;
revoke all on public.family_notifications from anon, authenticated;
grant select on public.family_notifications to anon;
grant select, insert, update on public.family_notifications to authenticated;

drop policy if exists family_notifications_public_read on public.family_notifications;
create policy family_notifications_public_read on public.family_notifications
  for select to anon, authenticated
  using (
    is_public and audience_type = 'all' and status in ('published','scheduled')
    and send_at <= now() and (expires_at is null or expires_at > now())
  );
drop policy if exists family_notifications_member_read on public.family_notifications;
create policy family_notifications_member_read on public.family_notifications
  for select to authenticated
  using (
    status in ('published','scheduled') and send_at <= now()
    and (expires_at is null or expires_at > now())
    and (
      family_is_root_admin()
      or (
        family_current_status() = 'active'
        and family_current_role() = any(audience_roles)
        and audience_type in ('all','roles')
      )
      or (
        family_current_status() = 'active'
        and audience_type = 'members'
        and exists (
          select 1 from public.family_user_permissions p
          where p.user_id = auth.uid()
            and p.status = 'active'
            and p.linked_member_id = any(recipient_member_ids)
        )
      )
    )
  );
drop policy if exists family_notifications_manager_read on public.family_notifications;
create policy family_notifications_manager_read on public.family_notifications
  for select to authenticated
  using (
    family_is_root_admin()
    or (family_current_status() = 'active' and family_current_role() = 'admin')
  );
drop policy if exists family_notifications_manager_insert on public.family_notifications;
create policy family_notifications_manager_insert on public.family_notifications
  for insert to authenticated
  with check (
    family_is_root_admin()
    or (family_current_status() = 'active' and family_current_role() = 'admin')
  );
drop policy if exists family_notifications_manager_update on public.family_notifications;
create policy family_notifications_manager_update on public.family_notifications
  for update to authenticated
  using (
    family_is_root_admin()
    or (family_current_status() = 'active' and family_current_role() = 'admin')
  )
  with check (
    family_is_root_admin()
    or (family_current_status() = 'active' and family_current_role() = 'admin')
  );

create table if not exists public.family_notification_reads (
  notification_id uuid not null references public.family_notifications(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz,
  dismissed_at timestamptz,
  primary key (notification_id, user_id)
);
alter table public.family_notification_reads enable row level security;
revoke all on public.family_notification_reads from anon, authenticated;
grant select, insert, update on public.family_notification_reads to authenticated;
drop policy if exists family_notification_reads_self_select on public.family_notification_reads;
create policy family_notification_reads_self_select on public.family_notification_reads
  for select to authenticated using (user_id = auth.uid());
drop policy if exists family_notification_reads_self_insert on public.family_notification_reads;
create policy family_notification_reads_self_insert on public.family_notification_reads
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists family_notification_reads_self_update on public.family_notification_reads;
create policy family_notification_reads_self_update on public.family_notification_reads
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.family_notification_history (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.family_notifications(id) on delete restrict,
  action text not null,
  actor_id uuid references auth.users(id) on delete set null,
  old_data jsonb,
  new_data jsonb,
  changed_at timestamptz not null default now()
);
alter table public.family_notification_history enable row level security;
revoke all on public.family_notification_history from anon, authenticated;
grant select on public.family_notification_history to authenticated;
drop policy if exists family_notification_history_manager_read on public.family_notification_history;
create policy family_notification_history_manager_read on public.family_notification_history
  for select to authenticated
  using (
    family_is_root_admin()
    or (family_current_status() = 'active' and family_current_role() = 'admin')
  );

create or replace function public.audit_family_notification_changes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.family_notification_history
    (notification_id, action, actor_id, old_data, new_data)
  values (
    coalesce(new.id, old.id),
    tg_op,
    auth.uid(),
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end
  );
  return coalesce(new, old);
end;
$$;
revoke all on function public.audit_family_notification_changes() from public, anon, authenticated;
drop trigger if exists family_notifications_audit on public.family_notifications;
create trigger family_notifications_audit
  after insert or update or delete on public.family_notifications
  for each row execute function public.audit_family_notification_changes();

-- Preserve old funeral notices while enabling archive/soft-delete and auditable schedule changes.
alter table public.family_funeral_notices
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references auth.users(id) on delete set null,
  add column if not exists schedule_updated_at timestamptz,
  add column if not exists schedule_updated_by uuid references auth.users(id) on delete set null,
  add column if not exists schedule_update_note text;

alter table public.family_funeral_notices
  drop constraint if exists family_funeral_notices_status_check;
alter table public.family_funeral_notices
  add constraint family_funeral_notices_status_check
  check (status = any(array['published','archived','deleted']::text[]));

drop policy if exists family_funeral_notices_root_manage_read on public.family_funeral_notices;
create policy family_funeral_notices_root_manage_read on public.family_funeral_notices
  for select to authenticated using (family_is_root_admin());

create table if not exists public.family_funeral_notice_history (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.family_funeral_notices(id) on delete restrict,
  action text not null,
  actor_id uuid references auth.users(id) on delete set null,
  reason text,
  old_data jsonb,
  new_data jsonb,
  changed_at timestamptz not null default now()
);
alter table public.family_funeral_notice_history enable row level security;
revoke all on public.family_funeral_notice_history from anon, authenticated;
grant select on public.family_funeral_notice_history to authenticated;
drop policy if exists family_funeral_notice_history_root_read on public.family_funeral_notice_history;
create policy family_funeral_notice_history_root_read on public.family_funeral_notice_history
  for select to authenticated using (family_is_root_admin());

create or replace function public.audit_family_funeral_notice_changes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_action text := 'updated';
begin
  if tg_op = 'INSERT' then
    v_action := 'published';
  elsif old.status is distinct from new.status then
    v_action := new.status;
  elsif (old.funeral_date, old.funeral_time, old.funeral_location, old.message)
        is distinct from
        (new.funeral_date, new.funeral_time, new.funeral_location, new.message) then
    v_action := 'schedule_updated';
  end if;
  insert into public.family_funeral_notice_history
    (notice_id, action, actor_id, reason, old_data, new_data)
  values (
    coalesce(new.id, old.id), v_action, auth.uid(), new.schedule_update_note,
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end
  );
  return coalesce(new, old);
end;
$$;
revoke all on function public.audit_family_funeral_notice_changes() from public, anon, authenticated;
drop trigger if exists family_funeral_notices_audit on public.family_funeral_notices;
create trigger family_funeral_notices_audit
  after insert or update or delete on public.family_funeral_notices
  for each row execute function public.audit_family_funeral_notice_changes();

create or replace function public.root_update_family_funeral_schedule(
  p_notice_id uuid,
  p_funeral_date date,
  p_funeral_time time,
  p_funeral_location text,
  p_reason text,
  p_family_consulted boolean
) returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null or not public.family_is_root_admin() then
    raise exception 'Chỉ Root Admin được cập nhật lịch tang lễ.';
  end if;
  if not coalesce(p_family_consulted, false) then
    raise exception 'Cần xác nhận gia đình đã thống nhất lịch mới.';
  end if;
  if length(btrim(coalesce(p_reason,''))) < 8 then
    raise exception 'Hãy ghi lý do cập nhật lịch (ít nhất 8 ký tự).';
  end if;
  update public.family_funeral_notices
  set funeral_date = p_funeral_date,
      funeral_time = p_funeral_time,
      funeral_location = nullif(btrim(p_funeral_location),''),
      schedule_updated_at = now(),
      schedule_updated_by = auth.uid(),
      schedule_update_note = btrim(p_reason),
      updated_at = now()
  where id = p_notice_id and status = 'published';
  if not found then
    raise exception 'Không tìm thấy thông báo đang phát hành.';
  end if;
end;
$$;
revoke all on function public.root_update_family_funeral_schedule(uuid,date,time,text,text,boolean) from public, anon;
grant execute on function public.root_update_family_funeral_schedule(uuid,date,time,text,text,boolean) to authenticated;

create or replace function public.root_archive_family_funeral_notice(p_notice_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null or not public.family_is_root_admin() then
    raise exception 'Chỉ Root Admin được lưu trữ thông báo.';
  end if;
  update public.family_funeral_notices
  set status = 'archived', updated_at = now(), schedule_update_note = 'Lưu trữ thông báo'
  where id = p_notice_id and status = 'published';
  if not found then raise exception 'Thông báo không còn ở trạng thái đang phát hành.'; end if;
end;
$$;
revoke all on function public.root_archive_family_funeral_notice(uuid) from public, anon;
grant execute on function public.root_archive_family_funeral_notice(uuid) to authenticated;

create or replace function public.root_delete_family_funeral_notice(p_notice_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null or not public.family_is_root_admin() then
    raise exception 'Chỉ Root Admin được gỡ thông báo.';
  end if;
  if length(btrim(coalesce(p_reason,''))) < 8 then
    raise exception 'Hãy ghi lý do gỡ thông báo (ít nhất 8 ký tự).';
  end if;
  update public.family_funeral_notices
  set status = 'deleted', deleted_at = now(), deleted_by = auth.uid(),
      schedule_update_note = btrim(p_reason), updated_at = now()
  where id = p_notice_id and status in ('published','archived');
  if not found then raise exception 'Không tìm thấy thông báo có thể gỡ.'; end if;
end;
$$;
revoke all on function public.root_delete_family_funeral_notice(uuid,text) from public, anon;
grant execute on function public.root_delete_family_funeral_notice(uuid,text) to authenticated;
