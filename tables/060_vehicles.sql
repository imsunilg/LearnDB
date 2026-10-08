-- Day 26: vehicles registered by customers (used by motor proposals)
SET search_path = learninsurancedb, public;

CREATE TABLE IF NOT EXISTS vehicles (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    registration_no   VARCHAR(15)  NOT NULL,                -- e.g. MH12AB1234 (stored upper-case, no spaces)
    customer_id       BIGINT       NOT NULL REFERENCES customers (id),
    vehicle_type      VARCHAR(20)  NOT NULL,                -- CAR | TWO_WHEELER | COMMERCIAL  (master data VEHICLE_TYPE)
    make              VARCHAR(60)  NOT NULL,
    model             VARCHAR(60)  NOT NULL,
    variant           VARCHAR(60),
    fuel_type         VARCHAR(20)  NOT NULL,
    manufacture_year  INT          NOT NULL,
    registration_date DATE,
    engine_no         VARCHAR(30),
    chassis_no        VARCHAR(30),
    cubic_capacity    INT          NOT NULL,
    seating_capacity  INT          NOT NULL DEFAULT 5,
    created_date      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by        VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date     TIMESTAMPTZ,
    modified_by       VARCHAR(100),
    is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_vehicles_regno CHECK (registration_no ~ '^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{4}$'),
    CONSTRAINT ck_vehicles_type CHECK (vehicle_type IN ('CAR', 'TWO_WHEELER', 'COMMERCIAL')),
    CONSTRAINT ck_vehicles_year CHECK (manufacture_year BETWEEN 1990 AND 2100),
    CONSTRAINT ck_vehicles_cc CHECK (cubic_capacity > 0 AND cubic_capacity <= 20000),
    CONSTRAINT ck_vehicles_seats CHECK (seating_capacity BETWEEN 1 AND 60)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_vehicles_regno ON vehicles (registration_no);
CREATE INDEX IF NOT EXISTS ix_vehicles_customer ON vehicles (customer_id);
