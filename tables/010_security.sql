-- Day 17: authentication tables - roles, users, user_roles, refresh_tokens
SET search_path = learninsurancedb, public;

CREATE TABLE IF NOT EXISTS roles (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(50)  NOT NULL,
    description   VARCHAR(250),
    is_system     BOOLEAN      NOT NULL DEFAULT FALSE,   -- system roles cannot be deleted
    created_date  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_roles_name UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS users (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username            VARCHAR(50)  NOT NULL,
    email               VARCHAR(150) NOT NULL,
    full_name           VARCHAR(150) NOT NULL,
    mobile              VARCHAR(15),
    password_hash       VARCHAR(100) NOT NULL,          -- bcrypt, never the plain password
    last_login_date     TIMESTAMPTZ,
    failed_login_count  INT          NOT NULL DEFAULT 0,
    locked_until        TIMESTAMPTZ,
    must_change_password BOOLEAN     NOT NULL DEFAULT FALSE,
    created_date        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by          VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date       TIMESTAMPTZ,
    modified_by         VARCHAR(100),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT ck_users_username CHECK (username ~ '^[A-Za-z0-9_.-]{3,50}$')
);

CREATE TABLE IF NOT EXISTS user_roles (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role_id       BIGINT       NOT NULL REFERENCES roles (id) ON DELETE CASCADE,
    created_date  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_user_roles UNIQUE (user_id, role_id)
);

-- Only a SHA-256 hash of the refresh token is stored, so a database leak cannot be replayed.
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash    VARCHAR(64)  NOT NULL,
    expires_at    TIMESTAMPTZ  NOT NULL,
    revoked_at    TIMESTAMPTZ,
    created_ip    VARCHAR(45),
    created_date  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    VARCHAR(100) NOT NULL DEFAULT 'system',
    modified_date TIMESTAMPTZ,
    modified_by   VARCHAR(100),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_refresh_tokens_hash UNIQUE (token_hash)
);

CREATE INDEX IF NOT EXISTS ix_user_roles_user ON user_roles (user_id);
CREATE INDEX IF NOT EXISTS ix_user_roles_role ON user_roles (role_id);
CREATE INDEX IF NOT EXISTS ix_refresh_tokens_user ON refresh_tokens (user_id);
