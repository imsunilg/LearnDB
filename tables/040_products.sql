-- Day 24: insurance product types (Motor, Health, Home, Travel) and the products sold under them
SET search_path = learninsurancedb, public;

CREATE TABLE IF NOT EXISTS insurance_product_types (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          VARCHAR(20)  NOT NULL,
    name          VARCHAR(80)  NOT NULL,
    description   VARCHAR(250),
    icon          VARCHAR(10),
    sort_order    INT          NOT NULL DEFAULT 0,
    created_date  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_product_types_code UNIQUE (code),
    CONSTRAINT ck_product_types_code CHECK (code ~ '^[A-Z]{3,20}$')
);

CREATE SEQUENCE IF NOT EXISTS seq_product_code START 1;

CREATE TABLE IF NOT EXISTS insurance_products (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_code       VARCHAR(20)   NOT NULL DEFAULT ('PRD' || lpad(nextval('seq_product_code')::text, 4, '0')),
    name               VARCHAR(150)  NOT NULL,
    product_type_id    BIGINT        NOT NULL REFERENCES insurance_product_types (id),
    description        VARCHAR(500),
    base_rate          NUMERIC(7,4)  NOT NULL,           -- annual premium as % of sum insured (before loadings/discounts)
    min_sum_insured    NUMERIC(14,2) NOT NULL DEFAULT 0,
    max_sum_insured    NUMERIC(14,2) NOT NULL,
    effective_from     DATE          NOT NULL DEFAULT CURRENT_DATE,
    effective_to       DATE,
    created_date       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by         VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date      TIMESTAMPTZ,
    modified_by        VARCHAR(100),
    is_active          BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_products_code UNIQUE (product_code),
    CONSTRAINT ck_products_rate CHECK (base_rate > 0 AND base_rate <= 100),
    CONSTRAINT ck_products_sum CHECK (min_sum_insured >= 0 AND max_sum_insured >= min_sum_insured),
    CONSTRAINT ck_products_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_products_name_type ON insurance_products (product_type_id, lower(name));
CREATE INDEX IF NOT EXISTS ix_products_type ON insurance_products (product_type_id);
CREATE INDEX IF NOT EXISTS ix_products_effective ON insurance_products (effective_from, effective_to);
