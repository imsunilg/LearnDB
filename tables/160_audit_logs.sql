-- Day 50: API audit trail. One row per state-changing request (who, what, when, result) tied together by a correlation id.
-- Bodies are NEVER stored (they can contain passwords, PAN, card digits).
SET search_path = learninsurancedb, public;

CREATE TABLE IF NOT EXISTS audit_logs (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    correlation_id VARCHAR(64)  NOT NULL,
    user_name      VARCHAR(100) NOT NULL DEFAULT 'anonymous',
    method         VARCHAR(10)  NOT NULL,
    path           VARCHAR(300) NOT NULL,
    entity         VARCHAR(50),                  -- first path segment after /api (customers, policies...)
    entity_id      BIGINT,                       -- numeric id in the path, when there is one
    action         VARCHAR(60),                  -- trailing verb segment (issue, refund, status...)
    status_code    INT          NOT NULL,
    duration_ms    INT          NOT NULL,
    ip_address     VARCHAR(45),
    user_agent     VARCHAR(200),
    created_date   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by     VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date  TIMESTAMPTZ,
    modified_by    VARCHAR(100),
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS ix_audit_created ON audit_logs (created_date DESC);
CREATE INDEX IF NOT EXISTS ix_audit_user ON audit_logs (user_name);
CREATE INDEX IF NOT EXISTS ix_audit_entity ON audit_logs (entity, entity_id);
CREATE INDEX IF NOT EXISTS ix_audit_correlation ON audit_logs (correlation_id);
