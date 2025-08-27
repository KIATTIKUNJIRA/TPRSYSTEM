
-- 20250814_smoketests.sql
-- sanity checks
select 'tables', count(*) from information_schema.tables where table_schema in ('core','hr','proj','cost');
select * from public.employees_with_roles limit 1;
