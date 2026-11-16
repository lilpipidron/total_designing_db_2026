create role inspector login password 'NetoSQL2025';

grant all privileges on
schema kramskoi_food to inspector;

grant all privileges on
all tables in schema kramskoi_food to inspector;

grant all privileges on
all routines in schema kramskoi_food to inspector;

grant usage on
schema exts to inspector;

grant execute on
all functions in schema exts to inspector;
