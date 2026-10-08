-- Day 26: proposals (quotes that become policies) and a generic status history used for timelines
SET search_path = learninsurancedb, public;

CREATE SEQUENCE IF NOT EXISTS seq_proposal_no START 1;

CREATE TABLE IF NOT EXISTS proposals (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proposal_no         VARCHAR(30)   NOT NULL DEFAULT ('PRP-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('seq_proposal_no')::text, 6, '0')),
    customer_id         BIGINT        NOT NULL REFERENCES customers (id),
    product_id          BIGINT        NOT NULL REFERENCES insurance_products (id),
    status              VARCHAR(20)   NOT NULL DEFAULT 'Draft',
    sum_insured         NUMERIC(14,2) NOT NULL DEFAULT 0,
    policy_term_years   INT           NOT NULL DEFAULT 1,
    start_date          DATE,
    net_premium         NUMERIC(14,2) NOT NULL DEFAULT 0,
    gst_amount          NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_premium       NUMERIC(14,2) NOT NULL DEFAULT 0,
    premium_breakup     JSONB,
    details             JSONB         NOT NULL DEFAULT '{}'::jsonb,   -- everything the product form collected
    agent_id            BIGINT        REFERENCES agents (id),
    broker_id           BIGINT        REFERENCES brokers (id),
    remarks             VARCHAR(500),
    submitted_date      TIMESTAMPTZ,
    decision_date       TIMESTAMPTZ,
    created_date        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by          VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date       TIMESTAMPTZ,
    modified_by         VARCHAR(100),
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_proposals_no UNIQUE (proposal_no),
    CONSTRAINT ck_proposals_status CHECK (status IN ('Draft', 'Submitted', 'Under Review', 'Approved', 'Rejected', 'Issued', 'Cancelled')),
    CONSTRAINT ck_proposals_term CHECK (policy_term_years BETWEEN 1 AND 5),
    CONSTRAINT ck_proposals_amounts CHECK (sum_insured >= 0 AND net_premium >= 0 AND gst_amount >= 0 AND total_premium >= 0)
);

CREATE INDEX IF NOT EXISTS ix_proposals_customer ON proposals (customer_id);
CREATE INDEX IF NOT EXISTS ix_proposals_product  ON proposals (product_id);
CREATE INDEX IF NOT EXISTS ix_proposals_status   ON proposals (status);
CREATE INDEX IF NOT EXISTS ix_proposals_created  ON proposals (created_date DESC);

-- Status history for any workflow entity (PROPOSAL, POLICY, CLAIM ...) - drives timeline components.
CREATE TABLE IF NOT EXISTS status_history (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_type   VARCHAR(30)  NOT NULL,
    entity_id     BIGINT       NOT NULL,
    from_status   VARCHAR(30),
    to_status     VARCHAR(30)  NOT NULL,
    remarks       VARCHAR(500),
    created_date  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS ix_status_history_entity ON status_history (entity_type, entity_id, created_date);
