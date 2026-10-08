-- Day 43: endorsements = mid-term changes to an issued policy (address, nominee, vehicle ...), with a premium adjustment.
SET search_path = learninsurancedb, public;

CREATE SEQUENCE IF NOT EXISTS seq_endorsement_no START 1;

CREATE TABLE IF NOT EXISTS endorsements (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    endorsement_no     VARCHAR(30)   NOT NULL DEFAULT ('END-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('seq_endorsement_no')::text, 6, '0')),
    policy_id          BIGINT        NOT NULL REFERENCES policies (id),
    endorsement_type   VARCHAR(30)   NOT NULL,
    effective_date     DATE          NOT NULL,
    status             VARCHAR(20)   NOT NULL DEFAULT 'Requested',
    section_name       VARCHAR(50)   NOT NULL,          -- which policy_details section the change applies to
    before_data        JSONB,
    after_data         JSONB         NOT NULL,
    changes            JSONB         NOT NULL DEFAULT '[]'::jsonb,   -- [{field, from, to}]
    premium_adjustment NUMERIC(14,2) NOT NULL DEFAULT 0,             -- incl. GST; negative = refund
    remarks            VARCHAR(500),
    decided_by         VARCHAR(100),
    decided_date       TIMESTAMPTZ,
    created_date       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by         VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date      TIMESTAMPTZ,
    modified_by        VARCHAR(100),
    is_active          BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_endorsements_no UNIQUE (endorsement_no),
    CONSTRAINT ck_endorsements_type CHECK (endorsement_type IN ('ADDRESS_CHANGE', 'ADD_NOMINEE', 'VEHICLE_CHANGE')),
    CONSTRAINT ck_endorsements_status CHECK (status IN ('Requested', 'Approved', 'Rejected'))
);

CREATE INDEX IF NOT EXISTS ix_endorsements_policy ON endorsements (policy_id);
CREATE INDEX IF NOT EXISTS ix_endorsements_status ON endorsements (status);
