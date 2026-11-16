create or replace
procedure add_product(
    p_restaurant_id uuid,
    p_product_category_id uuid,
    p_name varchar,
    p_price numeric,
    p_rating numeric,
    p_status product_status,
    p_description text,
    p_photo_url text default null
)
language plpgsql as $$
begin
    if not exists (
select
	1
from
	restaurant
where
	restaurant_id = p_restaurant_id) then
        raise exception 'Ресторан % не найден',
p_restaurant_id;
end if;

if not exists (
select
	1
from
	product_category
where
	product_category_id = p_product_category_id) then
        raise exception 'Категория % не найдена',
p_product_category_id;
end if;

insert
	into
	product (product_name,
	product_category_id,
	price,
	restaurant_id,
	photo_url,
	rating,
	status,
	description)
values (p_name,
p_product_category_id,
p_price,
p_restaurant_id,
            p_photo_url,
p_rating,
p_status,
p_description);
end $$;
