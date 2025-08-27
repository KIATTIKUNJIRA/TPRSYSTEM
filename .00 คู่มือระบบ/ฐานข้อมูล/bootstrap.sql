
-- ============================
-- TPR Digital Hub – bootstrap.sql
-- Safe to run multiple times (idempotent-ish). No data drop. 
-- Requires: Postgres on Supabase. 
-- ============================

-- 0) Extensions (for gen_random_uuid)
create extension if not exists "pgcrypto";

-- 1) Core tables (idempotent)
create table if not exists public.user_permissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  role text not null,
  sub_role text,
  manually_overridden boolean default false,
  created_at timestamptz default now()
);

create unique index if not exists user_permissions_user_role_uidx 
on public.user_permissions (user_id, role);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  check_type text not null,         -- 'check-in' / 'check-out' / 'leave' etc.
  check_time timestamptz default now(),
  note text
);

-- 2) TEAM linking and columns (quotes needed because table name is uppercase)
alter table public."TEAM" add column if not exists user_id uuid;
alter table public."TEAM" add column if not exists manager_email text;
alter table public."TEAM" add column if not exists manager_user_id uuid;

-- 2.1) Foreign keys (added only if not present)
do $$ begin
  if not exists (
    select 1 from pg_constraint 
    where conname = 'team_user_fk'
  ) then
    alter table public."TEAM"
      add constraint team_user_fk
      foreign key (user_id) references auth.users(id) on delete set null;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_constraint 
    where conname = 'team_manager_fk'
  ) then
    alter table public."TEAM"
      add constraint team_manager_fk
      foreign key (manager_user_id) references auth.users(id) on delete set null;
  end if;
end $$;

-- 2.2) Backfill user_id from auth.users by email (case-insensitive)
update public."TEAM" t
set user_id = u.id
from auth.users u
where lower(t.email) = lower(u.email)
  and t.user_id is null;

-- 2.3) Backfill manager_user_id from manager_email (if you already filled it)
update public."TEAM" t
set manager_user_id = u.id
from auth.users u
where t.manager_email is not null
  and lower(t.manager_email) = lower(u.email)
  and t.manager_user_id is null;

-- 3) Enable RLS
alter table public.user_permissions enable row level security;
alter table public.attendance enable row level security;
alter table public."TEAM" enable row level security;

-- 4) Policies (drop + create to avoid duplicates)

-- user_permissions: users can read their own permissions
drop policy if exists users_can_read_own_permissions on public.user_permissions;
create policy users_can_read_own_permissions
  on public.user_permissions
  for select
  using (auth.uid() = user_id);

-- attendance: self / admin / hr
drop policy if exists att_read_self on public.attendance;
create policy att_read_self
  on public.attendance
  for select
  using (auth.uid() = user_id);

drop policy if exists att_read_admin_hr on public.attendance;
create policy att_read_admin_hr
  on public.attendance
  for select
  using (
    exists (
      select 1 from public.user_permissions up
      where up.user_id = auth.uid()
        and up.role in ('admin','hr')
    )
  );

-- TEAM: self, head (manager), admin/hr
drop policy if exists team_read_self on public."TEAM";
create policy team_read_self
  on public."TEAM" for select
  using (auth.uid() = user_id);

drop policy if exists team_read_head on public."TEAM";
create policy team_read_head
  on public."TEAM" for select
  using (manager_user_id = auth.uid());

drop policy if exists team_read_admin_hr on public."TEAM";
create policy team_read_admin_hr
  on public."TEAM" for select
  using (
    exists (
      select 1 from public.user_permissions up
      where up.user_id = auth.uid()
        and up.role in ('admin','hr')
    )
  );

-- Only admin/hr may write TEAM
drop policy if exists team_write_admin_hr on public."TEAM";
create policy team_write_admin_hr
  on public."TEAM" 
  for all
  using (
    exists (
      select 1 from public.user_permissions up
      where up.user_id = auth.uid()
        and up.role in ('admin','hr')
    )
  )
  with check (
    exists (
      select 1 from public.user_permissions up
      where up.user_id = auth.uid()
        and up.role in ('admin','hr')
    )
  );

-- 5) Safe view for UI (hide sensitive columns like password / ID card)
create or replace view public.team_safe as
select
  user_id,
  lower(email) as email,
  prefix,
  firstname as first_name,
  "last name" as last_name,
  role as job_title,
  companyid,
  status,
  employeeid,
  workstartdate,
  phonenumber,
  address,
  manager_user_id
from public."TEAM";

-- Make the view respect RLS of base table
alter view public.team_safe set (security_invoker = on);

-- 6) RBAC bootstrap from TEAM
-- Everyone becomes 'employee' by default
insert into public.user_permissions (user_id, role, sub_role, manually_overridden)
select t.user_id, 'employee', 'staff', true
from public."TEAM" t
where t.user_id is not null
on conflict (user_id, role) do nothing;

-- Heads (manager/หัวหน้า) become 'head'
insert into public.user_permissions (user_id, role, sub_role, manually_overridden)
select t.user_id, 'head', 'manager', true
from public."TEAM" t
where t.user_id is not null
  and (t.role ilike '%ผู้จัดการ%' or t.role ilike '%หัวหน้า%')
on conflict (user_id, role) do nothing;

-- HR
insert into public.user_permissions (user_id, role, sub_role, manually_overridden)
select t.user_id, 'hr', 'staff', true
from public."TEAM" t
where t.user_id is not null
  and (t.role ilike '%บุคคล%' or t.role ilike '%HR%')
on conflict (user_id, role) do nothing;

-- Finance
insert into public.user_permissions (user_id, role, sub_role, manually_overridden)
select t.user_id, 'finance', 'staff', true
from public."TEAM" t
where t.user_id is not null
  and (t.role ilike '%การเงิน%' or t.role ilike '%บัญชี%' or t.role ilike '%Finance%')
on conflict (user_id, role) do nothing;

-- Admin bootstrap for KIATTIKUN (if not already admin)
insert into public.user_permissions (user_id, role, sub_role, manually_overridden)
select u.id, 'admin', 'manager', true
from auth.users u
where lower(u.email) = 'kiattikun@tripeera.com'
on conflict (user_id, role) do nothing;

-- ============================
-- End bootstrap.sql
-- ============================
