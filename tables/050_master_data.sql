-- Day 25: generic, hierarchical reference data (states → cities, vehicle make → model, relationships, occupations...)
SET search_path = learninsurancedb, public;

CREATE TABLE IF NOT EXISTS master_data (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type          VARCHAR(40)  NOT NULL,     -- STATE, CITY, VEHICLE_MAKE, VEHICLE_MODEL, RELATIONSHIP, OCCUPATION ...
    code          VARCHAR(60)  NOT NULL,
    name          VARCHAR(150) NOT NULL,
    parent_id     BIGINT       REFERENCES master_data (id),
    sort_order    INT          NOT NULL DEFAULT 0,
    meta          JSONB,                     -- type-specific extras, e.g. {"vehicleType":"Car","basePrice":700000}
    created_date  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_master_data UNIQUE (type, code),
    CONSTRAINT ck_master_data_type CHECK (type ~ '^[A-Z][A-Z_]{1,39}$')
);

CREATE INDEX IF NOT EXISTS ix_master_data_type_parent ON master_data (type, parent_id, sort_order);
