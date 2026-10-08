-- Day 10: unique constraints (as unique indexes, so they can be case-insensitive / partial) and search/sort indexes
SET search_path = learninsurancedb, public;

CREATE UNIQUE INDEX IF NOT EXISTS ux_customers_email         ON customers (lower(email));
CREATE UNIQUE INDEX IF NOT EXISTS ux_customers_customer_code ON customers (customer_code);
CREATE UNIQUE INDEX IF NOT EXISTS ux_customers_pan_number    ON customers (upper(pan_number)) WHERE pan_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_customers_full_name    ON customers (lower(full_name));
CREATE INDEX IF NOT EXISTS ix_customers_mobile       ON customers (mobile);
CREATE INDEX IF NOT EXISTS ix_customers_city         ON customers (city);
CREATE INDEX IF NOT EXISTS ix_customers_created_date ON customers (created_date DESC);
