-- Day 42: renewal actions. A policy is "renewed" when a policy exists with parent_policy_id = its id; this table records
-- the other outcomes (declined / notified) and the quoted renewal premium for audit.
SET search_path = learninsurancedb, public;

CREATE TABLE IF NOT EXISTS renewals (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    policy_id        BIGINT        NOT NULL REFERENCES policies (id),
    renewal_due_date DATE          NOT NULL,
    status           VARCHAR(20)   NOT NULL DEFAULT 'Due',
    new_policy_id    BIGINT        REFERENCES policies (id),
    previous_premium NUMERIC(14,2),
    renewal_premium  NUMERIC(14,2),
    remarks          VARCHAR(500),
    notified_date    TIMESTAMPTZ,
    created_date     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by       VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date    TIMESTAMPTZ,
    modified_by      VARCHAR(100),
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_renewals_policy UNIQUE (policy_id),
    CONSTRAINT ck_renewals_status CHECK (status IN ('Due', 'Renewed', 'Declined', 'Lapsed'))
);

CREATE INDEX IF NOT EXISTS ix_renewals_status ON renewals (status);
CREATE INDEX IF NOT EXISTS ix_renewals_due_date ON renewals (renewal_due_date);
