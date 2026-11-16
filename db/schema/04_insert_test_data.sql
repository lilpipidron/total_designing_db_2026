create or replace
procedure insert_test_data(value int)
language plpgsql as $$
declare
    v_categories uuid[];

v_couriers uuid[];

v_addresses uuid[];

v_restaurants uuid[];

v_clients uuid[];

v_products uuid[];

v_prices numeric[];

v_c_hire date[];

v_c_dismiss date[];

v_os_orders uuid[];

v_os_products uuid[];

v_os_qty numeric[];

v_orders uuid[];

v_courier_phone_base bigint;

v_client_base bigint;

v_client_phone_base bigint;

v_from date := (date_trunc('month', current_date) - interval '5 months')::date;

begin
    if value is null
or value < 1 then
        raise exception 'insert_test_data: value должен быть >= 1, получено %',
value;
end if;

with ins as (
insert
	into
		product_category (product_category_name)
		select
			substring(md5(random()::text), 1, 1 + floor(random() * 32)::int)
		from
			generate_series(1, value)
        returning product_category_id
    )
    select
	array_agg(product_category_id)
into
	v_categories
from
	ins;

select
	coalesce(max(trim(substr(phone_number, 3))::bigint), 9000000000)
    into
	v_courier_phone_base
from
	courier;

with src as (
select
	g,
	case
		when g = 1 then 'свободен'::courier_status
		else (enum_range(null::courier_status))[
                            1 + floor(random() * cardinality(enum_range(null::courier_status)))::int]
	end as st,
	v_from + floor(random() * (current_date - v_from + 1))::int as hire
from
	generate_series(1, value) g
    ),
ins as (
insert
	into
		courier (fio,
		phone_number,
		status,
		hire_date,
		dismissal_date,
		coefficient)
		select
			substring(md5(random()::text), 1, 1 + floor(random() * 32)::int),
			'+7' || (v_courier_phone_base + g)::text,
			st,
			hire,
			case
				when st = 'уволен'
                    then hire + floor(random() * (current_date - hire + 1))::int
			end,
			0.1
		from
			src
        returning courier_id,
			hire_date,
			dismissal_date
    )
    select
	array_agg(courier_id),
	array_agg(hire_date),
	array_agg(dismissal_date)
    into
	v_couriers,
	v_c_hire,
	v_c_dismiss
from
	ins;

with ins as (
insert
	into
		address (street,
		house_number,
		apartment_office)
		select
			substring(md5(random()::text), 1, 1 + floor(random() * 32)::int),
			(1 + floor(random() * 150))::int::text,
			case
				when random() < 0.3 then null
				else (1 + floor(random() * 300))::int::text
			end
		from
			generate_series(1, value * 5)
        returning address_id
    )
    select
	array_agg(address_id)
into
	v_addresses
from
	ins;

with src as (
select
	g,
	time '06:00' + floor(random() * 6)::int * interval '1 hour' as ws
from
	generate_series(1, value) g
    ),
ins as (
insert
	into
		restaurant (restaurant_name,
		address_id,
		description,
		work_start,
		work_end,
		company_details,
		rating,
		status)
		select
			substring(md5(random()::text), 1, 1 + floor(random() * 32)::int),
			v_addresses[g],
			case
				when random() < 0.2 then null
				else md5(random()::text)
			end,
			ws,
			ws + (8 + floor(random() * 5)::int) * interval '1 hour',
			md5(random()::text),
			null,
			(enum_range(null::restaurant_status))[
                   1 + floor(random() * cardinality(enum_range(null::restaurant_status)))::int]
		from
			src
        returning restaurant_id
    )
    select
	array_agg(restaurant_id)
into
	v_restaurants
from
	ins;

select
	coalesce(max(substr(login, 6)::bigint), 0),
	coalesce(max(trim(substr(phone_number, 3))::bigint), 9100000000)
    into
	v_client_base,
	v_client_phone_base
from
	client
where
	login ~ '^user_[0-9]+$';

with ins as (
insert
	into
		client (login,
		password,
		phone_number)
		select
			'user_' || (v_client_base + g),
			md5(random()::text),
			'+7' || (v_client_phone_base + g)::text
		from
			generate_series(1, value) g
        returning client_id
    )
    select
	array_agg(client_id)
into
	v_clients
from
	ins;

insert
	into
	client_address (client_id,
	address_id)
    select
	v_clients[(i - 1) % value + 1],
	v_addresses[value + i]
from
	generate_series(1, value * 4) i;

insert
	into
	client_address (client_id,
	address_id)
    select
	v_clients[g],
	v_addresses[value + 1 + floor(random() * value * 4)::int]
from
	generate_series(1, value) g
where
	random() < 0.3
    on
	conflict do nothing;

with src as materialized (
select
	g,
	exts.uuid_generate_v4() as id,
	round((150 + random() * 1350)::numeric, 2) as price
from
	generate_series(1, value * 5) g
    ),
ins as (
insert
	into
		product (product_id,
		product_name,
		product_category_id,
		price,
		restaurant_id,
		photo_url,
		rating,
		status,
		description)
		select
			id,
			substring(md5(random()::text), 1, 1 + floor(random() * 32)::int),
			v_categories[1 + floor(random() * cardinality(v_categories))::int],
			price,
			v_restaurants[(g - 1) % value + 1],
			case
				when random() < 0.3 then null
				else 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
			end,
			null,
			(enum_range(null::product_status))[
                   1 + floor(random() * cardinality(enum_range(null::product_status)))::int],
			case
				when random() < 0.3 then null
				else md5(random()::text)
			end
		from
			src
    )
    select
	array_agg(id order by g),
	array_agg(price order by g)
    into
	v_products,
	v_prices
from
	src;

with o as materialized (
select
	exts.uuid_generate_v4() as order_id,
	1 + floor(random() * cardinality(v_couriers))::int as c,
	1 + floor(random() * value * 4)::int as ca,
	1 + floor(random() * value)::int as r,
	1 + floor(random() * 5)::int as k,
	floor(random() * 5)::int as s,
	random() as ts_part,
	case
		when random() < 0.6 then 'доставлен'::order_status
		else (enum_range(null::order_status))[
                             1 + floor(random() * cardinality(enum_range(null::order_status)))::int]
	end as st
from
	generate_series(1, value * 5)
    ),
it as materialized (
select
	o.order_id,
	o.r + ((o.s + t) % 5) * value as p,
	1 + floor(random() * 3)::int as q
from
	o
cross join lateral generate_series(0, o.k - 1) t
    ),
tot as materialized (
select
	order_id,
	greatest(1, ceil(910 / sum(v_prices[p] * q)))::int as f,
	sum(v_prices[p] * q) as amount
from
	it
group by
	order_id
    ),
d as (
select
	o.*,
	tot.amount * tot.f as order_amount,
	v_c_hire[o.c]::timestamp + o.ts_part * (
                   least(coalesce((v_c_dismiss[o.c] + 1)::timestamp, localtimestamp), localtimestamp)
                   - v_c_hire[o.c]::timestamp) as order_ts
from
	o
join tot
		using (order_id)
    ),
ins as (
insert
	into
		"order" (order_id,
		courier_id,
		client_id,
		address_id,
		restaurant_id,
		order_timestamp,
		delivery_timestamp,
		order_amount,
		status,
		pay_status,
		description)
		select
			order_id,
			v_couriers[c],
			-- пара (клиент, адрес) по той же формуле, что и round-robin в client_address
			v_clients[(ca - 1) % value + 1],
			v_addresses[value + ca],
			v_restaurants[r],
			order_ts,
			case
				when st = 'доставлен'
                    then least(order_ts + (20 + floor(random() * 70)::int) * interval '1 minute',
                               localtimestamp)
			end,
			order_amount,
			st,
			case
				st when 'создан' then 'ожидает'::order_pay_status
				when 'отменён' then 'ошибка'::order_pay_status
				else 'оплачен'::order_pay_status
			end,
			case
				when random() < 0.2 then md5(random()::text)
			end
		from
			d
    )
    select
	array_agg(it.order_id),
	array_agg(v_products[it.p]),
	array_agg(it.q * tot.f)
    into
	v_os_orders,
	v_os_products,
	v_os_qty
from
	it
join tot
		using (order_id);

insert
	into
	order_structure (order_id,
	product_id,
	quantity)
    select
	*
from
	unnest(v_os_orders, v_os_products, v_os_qty);

v_orders := array(select distinct unnest(v_os_orders));

insert
	into
	payment (order_id,
	pay_type,
	amount,
	transaction_id,
	payment_timestamp,
	status)
    select
	o.order_id,
	(enum_range(null::payment_type))[
               1 + floor(random() * cardinality(enum_range(null::payment_type)))::int],
	o.total_amount,
	'txn_' || replace(exts.uuid_generate_v4()::text, '-', ''),
	least(o.order_timestamp + (1 + floor(random() * 10)::int) * interval '1 minute',
                 localtimestamp),
	case
		o.pay_status when 'оплачен' then 'успех'::payment_status
		when 'ошибка' then 'ошибка'::payment_status
		else 'в_обработке'::payment_status
	end
from
	"order" o
where
	o.order_id = any(v_orders);

with ord as materialized (
select
	order_id,
	client_id,
	restaurant_id,
	status,
	coalesce(delivery_timestamp, order_timestamp) as ts
from
	"order"
where
	order_id = any(v_orders)
    ),
cand as (
select
	order_id,
	'заказ'::review_entity_type as et,
	order_id as eid
from
	ord
union all
select
	order_id,
	'ресторан'::review_entity_type,
	restaurant_id
from
	ord
union all
select
	u.o,
	'блюдо'::review_entity_type,
	u.p
from
	unnest(v_os_orders, v_os_products) u(o, p)
    )
    insert
	into
	review (client_id,
	review_timestamp,
	entity_id,
	entity_type,
	order_id,
	description,
	photo_url,
	rating)
    select
	ord.client_id,
	least(ord.ts + random() * interval '3 days', localtimestamp),
	cand.eid,
	cand.et,
	cand.order_id,
	case
		when random() < 0.2 then null
		else md5(random()::text)
	end,
	case
		when random() < 0.7 then null
		else 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
	end,
	1 + floor(random() * 5)::int
from
	cand
join ord
		using (order_id)
order by
	(ord.status = 'доставлен') desc,
	random()
limit value * 5;

update
	product p
set
	rating = a.r
from
	(
	select
		entity_id,
		round(avg(rating), 2) as r
	from
		review
	where
		entity_type = 'блюдо'
		and entity_id = any(v_products)
	group by
		entity_id) a
where
	p.product_id = a.entity_id;

update
	restaurant r
set
	rating = a.r
from
	(
	select
		entity_id,
		round(avg(rating), 2) as r
	from
		review
	where
		entity_type = 'ресторан'
		and entity_id = any(v_restaurants)
	group by
		entity_id) a
where
	r.restaurant_id = a.entity_id;

insert
	into
	courier_pay (year,
	month,
	courier_id,
	amount,
	coefficient_used)
    select
	extract(year from g.m)::int,
	extract(month from g.m)::int,
	c.id,
	round(0.1 * coalesce(sum(o.commission), 0), 2),
	0.1
from
	unnest(v_couriers, v_c_dismiss) c(id, dis)
cross join generate_series(v_from::timestamp, date_trunc('month', localtimestamp),
                               interval '1 month') g(m)
left join "order" o on
	o.courier_id = c.id
	and o.status = 'доставлен'
	and date_trunc('month', o.order_timestamp) = g.m
where
	c.dis is null
	or g.m <= date_trunc('month', c.dis)
group by
	g.m,
	c.id;
end $$;
