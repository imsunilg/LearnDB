-- Day 28: premium rate tables and the log of calculated quotes
SET search_path = learninsurancedb, public;

-- Rating factors. unit: 'factor' (multiplier), 'percent' (of a base amount), 'flat' (rupees), 'value' (plain number)
CREATE TABLE IF NOT EXISTS premium_rates (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rate_group    VARCHAR(40)   NOT NULL,       -- e.g. MOTOR_AGE_FACTOR, MOTOR_TP, MOTOR_NCB, MOTOR_ADDON, GST
    rate_key      VARCHAR(60)   NOT NULL,       -- band upper bound or code, e.g. '3', 'CAR:1000', 'ZERO_DEP'
    rate_value    NUMERIC(12,4) NOT NULL,
    unit          VARCHAR(10)   NOT NULL DEFAULT 'factor',
    label         VARCHAR(150),
    sort_order    INT           NOT NULL DEFAULT 0,
    created_date  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by    VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_premium_rates UNIQUE (rate_group, rate_key),
    CONSTRAINT ck_premium_rates_unit CHECK (unit IN ('factor', 'percent', 'flat', 'value'))
);

CREATE TABLE IF NOT EXISTS premium_calculations (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id      BIGINT        NOT NULL REFERENCES insurance_products (id),
    customer_id     BIGINT        REFERENCES customers (id),
    product_type    VARCHAR(20)   NOT NULL,
    input           JSONB         NOT NULL,
    breakup         JSONB         NOT NULL,
    sum_insured     NUMERIC(14,2) NOT NULL,
    total_premium   NUMERIC(14,2) NOT NULL,
    created_date    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by      VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date   TIMESTAMPTZ,
    modified_by     VARCHAR(100),
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS ix_premium_calc_product ON premium_calculations (product_id, created_date DESC);
