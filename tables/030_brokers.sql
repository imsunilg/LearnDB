-- Day 23: insurance brokers (firms registered with IRDAI)
SET search_path = learninsurancedb, public;

CREATE SEQUENCE IF NOT EXISTS seq_broker_code START 1;

CREATE TABLE IF NOT EXISTS brokers (
    id                       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    broker_code              VARCHAR(20)   NOT NULL DEFAULT ('BRK' || lpad(nextval('seq_broker_code')::text, 5, '0')),
    firm_name                VARCHAR(200)  NOT NULL,
    contact_person           VARCHAR(150)  NOT NULL,
    email                    VARCHAR(150)  NOT NULL,
    mobile                   VARCHAR(15)   NOT NULL,
    irdai_registration_no    VARCHAR(30)   NOT NULL,
    registration_expiry_date DATE          NOT NULL,
    gst_number               VARCHAR(15),
    address_line             VARCHAR(250),
    city                     VARCHAR(80),
    state                    VARCHAR(80),
    commission_percent       NUMERIC(5,2)  NOT NULL DEFAULT 15,
    created_date             TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by               VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date            TIMESTAMPTZ,
    modified_by              VARCHAR(100),
    is_active                BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_brokers_commission CHECK (commission_percent >= 0 AND commission_percent <= 100),
    CONSTRAINT ck_brokers_mobile CHECK (mobile ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT ck_brokers_gst CHECK (gst_number IS NULL OR gst_number ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_brokers_code  ON brokers (broker_code);
CREATE UNIQUE INDEX IF NOT EXISTS ux_brokers_irdai ON brokers (upper(irdai_registration_no));
CREATE UNIQUE INDEX IF NOT EXISTS ux_brokers_email ON brokers (lower(email));
CREATE INDEX IF NOT EXISTS ix_brokers_firm ON brokers (lower(firm_name));
