create or replace
view how_much_money as
with recursive ord as materialized (
select
	date_trunc('month', order_timestamp) as m,
	sum(order_amount) as sum_no_commission,
	sum(total_amount) as sum_with_commission
from
	"order"
where
	status = 'доставлен'
group by
	date_trunc('month', order_timestamp)
),
months as (
select
	min(m) as m,
	max(m) as last_m
from
	ord
having
	min(m) is not null
union all
select
	m + interval '1 month',
	last_m
from
	months
where
	m < last_m
),
pay as (
select
	make_timestamp(year, month, 1, 0, 0, 0) as m,
	sum(amount) as courier_pay
from
	courier_pay
group by
	year,
	month
),
base as (
select
	months.m,
	coalesce(ord.sum_no_commission, 0) as sum_no_commission,
	coalesce(ord.sum_with_commission, 0) as sum_with_commission,
	coalesce(ord.sum_with_commission, 0) - coalesce(ord.sum_no_commission, 0) as commission,
	coalesce(pay.courier_pay, 0) as courier_pay
from
	months
left join ord on
	ord.m = months.m
left join pay on
	pay.m = months.m
)
select
	to_char(m, 'YYYY-MM') as year_month,
	sum_no_commission,
	sum_with_commission,
	commission,
	lag(commission) over (
	order by m) as prev_commission,
	commission - lag(commission) over (
	order by m) as commission_diff,
	courier_pay,
	commission - courier_pay as net_profit
from
	base
order by
	m;
