create or replace
procedure courier_salary()
language plpgsql as $$
declare
    v_m timestamp := date_trunc('month', localtimestamp);

begin
    with calc as (
select
	c.courier_id,
	c.status,
	coalesce(cp.coefficient_used, c.coefficient) as coef,
	count(o.order_id) as cnt,
	coalesce(sum(o.commission), 0) as comm
from
	courier c
left join courier_pay cp on
	cp.courier_id = c.courier_id
	and cp.year = extract(year from v_m)
	and cp.month = extract(month from v_m)
left join "order" o on
	o.courier_id = c.courier_id
	and o.status = 'доставлен'
	and o.order_timestamp >= v_m
	and o.order_timestamp < v_m + interval '1 month'
where
	c.dismissal_date is null
	or c.dismissal_date >= v_m::date
group by
	c.courier_id,
	c.status,
	cp.coefficient_used,
	c.coefficient
    ),
ups as (
insert
	into
		courier_pay (year,
		month,
		courier_id,
		amount,
		coefficient_used)
		select
			extract(year from v_m)::int,
			extract(month from v_m)::int,
			courier_id,
			round(coef * comm, 2),
			coef
		from
			calc
        on
			conflict (year,
			month,
			courier_id)
        do
			update
			set
				amount = excluded.amount,
				coefficient_used = excluded.coefficient_used
    )
    update
	courier c
set
	coefficient = case
		when calc.cnt <= 150 then 0.1
		when calc.cnt <= 250 then 0.2
		when calc.cnt <= 500 then 0.3
		else 0.5
	end
from
	calc
where
	c.courier_id = calc.courier_id
	and calc.status <> 'уволен';
end $$;
