-- Day 22: insurance agents. broker_id is linked to brokers on Day 23 (tables/032_agents_broker_fk.sql).
SET search_path = learninsurancedb, public;

CREATE SEQUENCE IF NOT EXISTS seq_agent_code START 1;

CREATE TABLE IF NOT EXISTS agents (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    agent_code           VARCHAR(20)   NOT NULL DEFAULT ('AGT' || lpad(nextval('seq_agent_code')::text, 5, '0')),
    full_name            VARCHAR(150)  NOT NULL,
    email                VARCHAR(150)  NOT NULL,
    mobile               VARCHAR(15)   NOT NULL,
    license_number       VARCHAR(30)   NOT NULL,
    license_expiry_date  DATE          NOT NULL,
    commission_percent   NUMERIC(5,2)  NOT NULL DEFAULT 10,
    broker_id            BIGINT,
    city                 VARCHAR(80),
    state                VARCHAR(80),
    status               VARCHAR(20)   NOT NULL DEFAULT 'Active',
    joined_date          DATE          NOT NULL DEFAULT CURRENT_DATE,
    created_date         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by           VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date        TIMESTAMPTZ,
    modified_by          VARCHAR(100),
    is_active            BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_agents_commission CHECK (commission_percent >= 0 AND commission_percent <= 100),
    CONSTRAINT ck_agents_status CHECK (status IN ('Active', 'Suspended', 'Terminated')),
    CONSTRAINT ck_agents_mobile CHECK (mobile ~ '^[6-9][0-9]{9}$')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_agents_agent_code ON agents (agent_code);
CREATE UNIQUE INDEX IF NOT EXISTS ux_agents_license    ON agents (upper(license_number));
CREATE UNIQUE INDEX IF NOT EXISTS ux_agents_email      ON agents (lower(email));
CREATE INDEX IF NOT EXISTS ix_agents_name   ON agents (lower(full_name));
CREATE INDEX IF NOT EXISTS ix_agents_status ON agents (status);
CREATE INDEX IF NOT EXISTS ix_agents_expiry ON agents (license_expiry_date);
