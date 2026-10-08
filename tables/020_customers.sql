-- Day 07: Customers table.
-- ID DECISION: BIGINT identity (see LearnDocuments/Database/Database.md) - compact, fast joins, readable in URLs/logs.
SET search_path = learninsurancedb, public;

CREATE SEQUENCE IF NOT EXISTS seq_customer_code START 1;

CREATE TABLE IF NOT EXISTS customers (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_code  VARCHAR(20)  NOT NULL DEFAULT ('CUST' || lpad(nextval('seq_customer_code')::text, 5, '0')),
    full_name      VARCHAR(150) NOT NULL,
    email          VARCHAR(150) NOT NULL,
    mobile         VARCHAR(15)  NOT NULL,
    date_of_birth  DATE         NOT NULL,
    gender         VARCHAR(10),
    pan_number     VARCHAR(10),
    address_line   VARCHAR(250),
    city           VARCHAR(80),
    state          VARCHAR(80),
    pincode        VARCHAR(6),
    kyc_status     VARCHAR(20)  NOT NULL DEFAULT 'Pending',
    -- audit fields (present on every table)
    created_date   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by     VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date  TIMESTAMPTZ,
    modified_by    VARCHAR(100),
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_customers_gender CHECK (gender IS NULL OR gender IN ('Male', 'Female', 'Other')),
    CONSTRAINT ck_customers_kyc CHECK (kyc_status IN ('Pending', 'Verified', 'Rejected'))
);
