create or replace
procedure erase_test_data()
language plpgsql as $$
begin
    truncate
	table
        review,
	payment,
	order_structure,
	courier_pay,
	"order",
	client_address,
	product,
	client,
	restaurant,
	courier,
	address,
	product_category;
end $$;
