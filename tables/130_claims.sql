-- Day 44: claims against issued policies. Workflow history lives in status_history (entity_type = 'CLAIM').
SET search_path = learninsurancedb, public;

CREATE SEQUENCE IF NOT EXISTS seq_claim_no START 1;

CREATE TABLE IF NOT EXISTS claims (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_no          VARCHAR(30)   NOT NULL DEFAULT ('CLM-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('seq_claim_no')::text, 6, '0')),
    policy_id         BIGINT        NOT NULL REFERENCES policies (id),
    customer_id       BIGINT        NOT NULL REFERENCES customers (id),
    claim_type        VARCHAR(30)   NOT NULL,                  -- master data CLAIM_TYPE code, e.g. ACCIDENT
    incident_date     DATE          NOT NULL,
    incident_location VARCHAR(250),
    description       VARCHAR(1000) NOT NULL,
    claimed_amount    NUMERIC(14,2) NOT NULL,
    approved_amount   NUMERIC(14,2),
    status            VARCHAR(20)   NOT NULL DEFAULT 'Intimated',
    intimation_date   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    decision_date     TIMESTAMPTZ,
    settled_date      TIMESTAMPTZ,
    remarks           VARCHAR(500),
    created_date      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by        VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date     TIMESTAMPTZ,
    modified_by       VARCHAR(100),
    is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_claims_no UNIQUE (claim_no),
    CONSTRAINT ck_claims_status CHECK (status IN ('Intimated', 'Under Review', 'Documents Pending', 'Approved', 'Rejected', 'Settled', 'Withdrawn')),
    CONSTRAINT ck_claims_amounts CHECK (claimed_amount > 0 AND (approved_amount IS NULL OR approved_amount >= 0)),
    CONSTRAINT ck_claims_approved_le_claimed CHECK (approved_amount IS NULL OR approved_amount <= claimed_amount)
);

CREATE INDEX IF NOT EXISTS ix_claims_policy   ON claims (policy_id);
CREATE INDEX IF NOT EXISTS ix_claims_customer ON claims (customer_id);
CREATE INDEX IF NOT EXISTS ix_claims_status   ON claims (status);
CREATE INDEX IF NOT EXISTS ix_claims_incident ON claims (incident_date DESC);
