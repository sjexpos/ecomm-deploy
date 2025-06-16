#!/usr/bin/env bash

sed -r "s#TO_BE_REPLACED#1234#g" /mnt/create_databases.sql > /tmp/create_databases.sql

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /tmp/create_databases.sql

echo "------------ Databases were created ------------"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

-- GRANT ALL PRIVILEGES ON DATABASE ecomm_users TO users_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO users_service;

-- GRANT ALL PRIVILEGES ON DATABASE ecomm_products TO products_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO products_service;

-- GRANT ALL PRIVILEGES ON DATABASE ecomm_orders TO orders_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO orders_service;

-- GRANT ALL PRIVILEGES ON DATABASE ecomm_payments TO payments_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO payments_service;

EOSQL

echo "------------ Grants were executed ------------"

