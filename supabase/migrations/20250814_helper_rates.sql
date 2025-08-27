
-- 20250814_helper_rates.sql
create or replace function cost.get_latest_rate(p_person uuid, p_date date default current_date)
returns table(internal_cost_rate numeric, bill_rate numeric)
language plpgsql stable as $$
begin
  return query
  select r.internal_cost_rate, r.bill_rate
  from cost.cost_rates r
  where r.person_id = p_person and r.effective_from <= p_date
    and (r.effective_to is null or r.effective_to >= p_date)
  order by r.effective_from desc
  limit 1;
end $$;
