create or replace
function get_statistic()
returns table (
    restaurant_name varchar,
    best_product_name varchar,
    total_amount numeric,
    avg_amount numeric,
    best_user varchar
)
language sql stable as $$
    with ord as materialized (
select
	o.order_id,
	o.restaurant_id,
	o.client_id,
	o.total_amount
from
	"order" o
where
	o.status = 'доставлен'
    ),
    sums as (
select
	ord.restaurant_id,
	sum(ord.total_amount) as total_amount,
	round(avg(ord.total_amount), 2) as avg_amount
from
	ord
group by
	ord.restaurant_id
    ),
    best_prod as (
select
	distinct on
	(ord.restaurant_id)
               ord.restaurant_id,
	p.product_name
from
	ord
join order_structure os on
	os.order_id = ord.order_id
join product p on
	p.product_id = os.product_id
group by
	ord.restaurant_id,
	p.product_id,
	p.product_name
order by
	ord.restaurant_id,
	sum(os.quantity) desc,
	random()
    ),
    best_cli as (
select
	distinct on
	(ord.restaurant_id)
               ord.restaurant_id,
	c.login
from
	ord
join client c on
	c.client_id = ord.client_id
group by
	ord.restaurant_id,
	c.client_id,
	c.login
order by
	ord.restaurant_id,
	count(*) desc,
	random()
    )
    select
	r.restaurant_name,
	bp.product_name,
	s.total_amount,
	s.avg_amount,
	bc.login
from
	restaurant r
left join sums s on
	s.restaurant_id = r.restaurant_id
left join best_prod bp on
	bp.restaurant_id = r.restaurant_id
left join best_cli bc on
	bc.restaurant_id = r.restaurant_id;

$$;
