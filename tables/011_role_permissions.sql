-- Day 19: permissions assigned to roles. A permission is a string like 'customers.delete'.
SET search_path = learninsurancedb, public;

CREATE TABLE IF NOT EXISTS role_permissions (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_id       BIGINT       NOT NULL REFERENCES roles (id) ON DELETE CASCADE,
    permission    VARCHAR(80)  NOT NULL,
    created_date  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_role_permissions UNIQUE (role_id, permission),
    CONSTRAINT ck_role_permissions_format CHECK (permission ~ '^[a-z]+\.[a-z]+$')
);

CREATE INDEX IF NOT EXISTS ix_role_permissions_role ON role_permissions (role_id);
