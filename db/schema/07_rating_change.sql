create index if not exists review_entity_idx on
review (entity_type,
entity_id);

create or replace
function rating_change() returns trigger
language plpgsql as $$
begin
    update
	product p
set
	rating = (
	select
		round(avg(r.rating), 2)
	from
		review r
	where
		r.entity_type = 'блюдо'
		and r.entity_id = p.product_id)
where
	(old.entity_type = 'блюдо'
		and p.product_id = old.entity_id)
	or (new.entity_type = 'блюдо'
		and p.product_id = new.entity_id);

update
	restaurant t
set
	rating = (
	select
		round(avg(r.rating), 2)
	from
		review r
	where
		r.entity_type = 'ресторан'
		and r.entity_id = t.restaurant_id)
where
	(old.entity_type = 'ресторан'
		and t.restaurant_id = old.entity_id)
	or (new.entity_type = 'ресторан'
		and t.restaurant_id = new.entity_id);

return null;
end $$;

create or replace
trigger review_rating_trg
after
insert
	or
update
	or
delete
	on
	review
for each row execute function rating_change();
