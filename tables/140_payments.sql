-- Day 45: premium payments. One row per payment ATTEMPT; a policy is "paid" when successful payments cover its total premium.
SET search_path = learninsurancedb, public;

CREATE SEQUENCE IF NOT EXISTS seq_payment_no START 1;
CREATE SEQUENCE IF NOT EXISTS seq_receipt_no START 1;

CREATE TABLE IF NOT EXISTS payments (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_no       VARCHAR(30)   NOT NULL DEFAULT ('PAY-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('seq_payment_no')::text, 6, '0')),
    policy_id        BIGINT        NOT NULL REFERENCES policies (id),
    customer_id      BIGINT        NOT NULL REFERENCES customers (id),
    amount           NUMERIC(14,2) NOT NULL,
    payment_mode     VARCHAR(20)   NOT NULL,            -- master data PAYMENT_MODE code: UPI, CARD, NETBANKING, CASH, CHEQUE
    status           VARCHAR(20)   NOT NULL DEFAULT 'Pending',
    transaction_ref  VARCHAR(60),
    gateway_response JSONB,
    paid_date        TIMESTAMPTZ,
    receipt_no       VARCHAR(30),
    idempotency_key  VARCHAR(80),                       -- the same key never creates (or charges) twice
    parent_payment_id BIGINT       REFERENCES payments (id),   -- the failed attempt this one retries
    remarks          VARCHAR(500),
    created_date     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by       VARCHAR(100)  NOT NULL DEFAULT 'system',
    modified_date    TIMESTAMPTZ,
    modified_by      VARCHAR(100),
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_payments_no UNIQUE (payment_no),
    CONSTRAINT ck_payments_status CHECK (status IN ('Pending', 'Success', 'Failed', 'Refunded')),
    CONSTRAINT ck_payments_amount CHECK (amount > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_payments_idempotency ON payments (idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_payments_receipt ON payments (receipt_no) WHERE receipt_no IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_payments_policy ON payments (policy_id);
CREATE INDEX IF NOT EXISTS ix_payments_customer ON payments (customer_id);
CREATE INDEX IF NOT EXISTS ix_payments_status ON payments (status);
CREATE INDEX IF NOT EXISTS ix_payments_paid_date ON payments (paid_date DESC);
