-- Day 30: issued policies. A policy is created from an APPROVED proposal and is immutable afterwards (changes = endorsements).
SET search_path = learninsurancedb, public;

CREATE SEQUENCE IF NOT EXISTS seq_policy_no START 1;

CREATE TABLE IF NOT EXISTS policies (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    policy_no         VARCHAR(30)   NOT NULL,
    proposal_id       BIGINT        NOT NULL REFERENCES proposals (id),
    customer_id       BIGINT        NOT NULL REFERENCES customers (id),
    product_id        BIGINT        NOT NULL REFERENCES insurance_products (id),
    status            VARCHAR(20)   NOT NULL DEFAULT 'Active',
    start_date        DATE          NOT NULL,
    end_date          DATE          NOT NULL,
    policy_term_years INT           NOT NULL DEFAULT 1,
    sum_insured       NUMERIC(14,2) NOT NULL,
    net_premium       NUMERIC(14,2) NOT NULL,
    gst_amount        NUMERIC(14,2) NOT NULL,
    total_premium     NUMERIC(14,2) NOT NULL,
    premium_breakup   JSONB,
    agent_id          BIGINT        REFERENCES agents (id),
    broker_id         BIGINT        REFERENCES brokers (id),
    parent_policy_id  BIGINT        REFERENCES policies (id),     -- previous term when this policy is a renewal
    issued_date       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    issued_by         VARCHAR(100),
    remarks           VARCHAR(500),
    created_date      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by        VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date     TIMESTAMPTZ,
    modified_by       VARCHAR(100),
    is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_policies_no UNIQUE (policy_no),
    CONSTRAINT uq_policies_proposal UNIQUE (proposal_id),
    CONSTRAINT ck_policies_status CHECK (status IN ('Active', 'Expired', 'Cancelled', 'Lapsed')),
    CONSTRAINT ck_policies_dates CHECK (end_date >= start_date),
    CONSTRAINT ck_policies_amounts CHECK (sum_insured >= 0 AND net_premium >= 0 AND gst_amount >= 0 AND total_premium >= 0)
);

CREATE INDEX IF NOT EXISTS ix_policies_customer ON policies (customer_id);
CREATE INDEX IF NOT EXISTS ix_policies_product  ON policies (product_id);
CREATE INDEX IF NOT EXISTS ix_policies_status   ON policies (status);
CREATE INDEX IF NOT EXISTS ix_policies_end_date ON policies (end_date);
CREATE INDEX IF NOT EXISTS ix_policies_agent    ON policies (agent_id);

-- Sections of the insured risk (vehicle, insurance, members, property...) copied from the proposal at issue time.
CREATE TABLE IF NOT EXISTS policy_details (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    policy_id     BIGINT       NOT NULL REFERENCES policies (id) ON DELETE CASCADE,
    section_name  VARCHAR(50)  NOT NULL,
    section_data  JSONB        NOT NULL,
    created_date  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_policy_details UNIQUE (policy_id, section_name)
);

-- A one-day trip has end_date = start_date: relax the original (strict) constraint on existing databases
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_policies_dates' AND pg_get_constraintdef(oid) LIKE '%end_date > start_date%') THEN
        ALTER TABLE policies DROP CONSTRAINT ck_policies_dates;
        ALTER TABLE policies ADD CONSTRAINT ck_policies_dates CHECK (end_date >= start_date);
    END IF;
END $$;
