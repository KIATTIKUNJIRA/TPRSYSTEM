
-- 20250814_core_hr_cost_project.sql
-- Core schemas
create schema if not exists core;
create schema if not exists hr;
create schema if not exists proj;
create schema if not exists cost;
create schema if not exists audit;

-- Organizations/companies/departments
create table if not exists core.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz default now()
);

create table if not exists core.companies (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references core.orgs(id) on delete cascade,
  name text not null unique,
  created_at timestamptz default now()
);

create table if not exists core.departments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references core.companies(id) on delete cascade,
  name text not null,
  created_at timestamptz default now()
);

-- People (keeps backward-compatible fields)
create table if not exists hr.people (
  id uuid primary key default gen_random_uuid(),
  auth_uid uuid,                     -- auth.users.id (nullable until invited)
  email text not null unique,
  first_name text,
  last_name text,
  phone text,
  company_id uuid references core.companies(id) on delete set null,
  department_id uuid references core.departments(id) on delete set null,
  role_x text,        -- position
  role_y text,        -- privilege (admin/hr/head/staff/user)
  status_x text default 'active',  -- ACTIVE/INACTIVE/etc
  employee_id text,
  work_start_date date,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Role history (audit)
create table if not exists hr.role_history (
  id bigserial primary key,
  person_id uuid references hr.people(id) on delete cascade,
  actor_uid uuid,            -- who changed
  old_role_y text,
  new_role_y text,
  changed_at timestamptz default now()
);

-- Projects
create table if not exists proj.projects (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references core.companies(id) on delete cascade,
  code text,
  name text not null,
  status text default 'active',
  starts_on date,
  ends_on date,
  created_at timestamptz default now()
);

create table if not exists proj.project_members (
  project_id uuid references proj.projects(id) on delete cascade,
  person_id uuid references hr.people(id) on delete cascade,
  project_role text,
  can_edit bool default false,
  primary key (project_id, person_id)
);

-- Boards (simplified)
create table if not exists proj.board_columns (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references proj.projects(id) on delete cascade,
  name text not null,
  kind text default 'text',
  position int default 0
);

create table if not exists proj.board_items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references proj.projects(id) on delete cascade,
  title text not null,
  status text default 'todo',
  assignee uuid references hr.people(id) on delete set null,
  created_at timestamptz default now()
);

create table if not exists proj.board_item_values (
  item_id uuid references proj.board_items(id) on delete cascade,
  column_id uuid references proj.board_columns(id) on delete cascade,
  value jsonb,
  primary key (item_id, column_id)
);

-- Cost & timesheets
create table if not exists cost.cost_rates (
  id bigserial primary key,
  person_id uuid references hr.people(id) on delete cascade,
  internal_cost_rate numeric(12,2),
  bill_rate numeric(12,2),
  currency text default 'THB',
  effective_from date not null,
  effective_to date
);
create index if not exists ix_rates_person_from on cost.cost_rates(person_id, effective_from desc);

create table if not exists cost.timesheets (
  id bigserial primary key,
  person_id uuid references hr.people(id) on delete cascade,
  project_id uuid references proj.projects(id) on delete cascade,
  work_date date not null,
  hours numeric(6,2) not null check (hours>=0),
  rate_snapshot numeric(12,2),
  bill_rate_snapshot numeric(12,2),
  created_at timestamptz default now()
);
create index if not exists ix_ts_person_date on cost.timesheets(person_id, work_date desc);

-- Backward compatible view for existing UI "employees_with_roles"
create or replace view public.employees_with_roles as
select
  p.id as employee_id_uuid,
  p.first_name,
  p.last_name,
  p.email,
  p.phone,
  coalesce(c.name,'') as company_id,    -- kept as text label for legacy UI
  p.role_x,
  p.role_y,
  p.status_x,
  p.employee_id,
  p.work_start_date,
  d.name as department_id
from hr.people p
left join core.companies c on c.id = p.company_id
left join core.departments d on d.id = p.department_id;

-- RLS
alter table hr.people enable row level security;
alter table hr.role_history enable row level security;
alter table proj.projects enable row level security;
alter table proj.project_members enable row level security;
alter table proj.board_items enable row level security;
alter table cost.timesheets enable row level security;

-- helper: determine if request user is admin/hr
create or replace function public.is_admin_or_hr() returns boolean
language sql stable security definer as $$
  select exists (
    select 1
    from hr.people p
    where p.auth_uid = auth.uid() and p.role_y in ('admin','hr')
  );
$$;

-- policies (minimal examples)
drop policy if exists ppl_read_all on hr.people;
create policy ppl_read_all on hr.people
for select using (
  public.is_admin_or_hr() or (auth.uid() is not null and auth.uid() = auth_uid)
);

drop policy if exists ppl_admin_write on hr.people;
create policy ppl_admin_write on hr.people
for insert with check (public.is_admin_or_hr())
;
create policy ppl_admin_update on hr.people
for update using (public.is_admin_or_hr());

drop policy if exists proj_read on proj.projects;
create policy proj_read on proj.projects for select using (
  public.is_admin_or_hr()
);

drop policy if exists ts_read on cost.timesheets;
create policy ts_read on cost.timesheets for select using (
  public.is_admin_or_hr() or auth.uid() in (
    select auth_uid from hr.people where id = cost.timesheets.person_id
  )
);
