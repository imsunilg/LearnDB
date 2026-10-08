-- Day 21: permission catalogue (what can be granted). role_permissions.permission references permissions.key by value.
SET search_path = learninsurancedb, public;

CREATE TABLE IF NOT EXISTS permissions (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key           VARCHAR(80)  NOT NULL,
    module        VARCHAR(40)  NOT NULL,
    action        VARCHAR(40)  NOT NULL,
    description   VARCHAR(250),
    created_date  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_permissions_key UNIQUE (key)
);
