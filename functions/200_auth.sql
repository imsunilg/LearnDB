-- Day 17: authentication functions. Permissions are added to fn_user_get_by_username on Day 19.
SET search_path = learninsurancedb, public;

-- Returns the user (including the password hash - used ONLY by the API to verify credentials) or NULL.
CREATE OR REPLACE FUNCTION fn_user_get_by_username(p_username text) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT jsonb_build_object(
        'id', u.id,
        'username', u.username,
        'email', u.email,
        'fullName', u.full_name,
        'passwordHash', u.password_hash,
        'isActive', u.is_active,
        'failedLoginCount', u.failed_login_count,
        'lockedUntil', u.locked_until,
        'mustChangePassword', u.must_change_password,
        'roles', COALESCE((SELECT jsonb_agg(r.name ORDER BY r.name)
                           FROM learninsurancedb.user_roles ur
                           JOIN learninsurancedb.roles r ON r.id = ur.role_id AND r.is_active
                           WHERE ur.user_id = u.id AND ur.is_active), '[]'::jsonb),
        'permissions', '[]'::jsonb
    )
    FROM learninsurancedb.users u
    WHERE lower(u.username) = lower(p_username);
$$;

CREATE OR REPLACE FUNCTION fn_user_get_auth_by_id(p_id bigint) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT learninsurancedb.fn_user_get_by_username(u.username) FROM learninsurancedb.users u WHERE u.id = p_id;
$$;

CREATE OR REPLACE FUNCTION fn_auth_login_succeeded(p_user_id bigint) RETURNS void
LANGUAGE sql AS $$
    UPDATE learninsurancedb.users
    SET last_login_date = now(), failed_login_count = 0, locked_until = NULL
    WHERE id = p_user_id;
$$;

-- 5 consecutive failures lock the account for 15 minutes (brute-force protection).
CREATE OR REPLACE FUNCTION fn_auth_login_failed(p_user_id bigint) RETURNS void
LANGUAGE sql AS $$
    UPDATE learninsurancedb.users
    SET failed_login_count = failed_login_count + 1,
        locked_until = CASE WHEN failed_login_count + 1 >= 5 THEN now() + interval '15 minutes' ELSE locked_until END
    WHERE id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION fn_refresh_token_create(p_user_id bigint, p_token_hash text, p_expires_at timestamptz, p_ip text DEFAULT NULL) RETURNS void
LANGUAGE sql AS $$
    INSERT INTO learninsurancedb.refresh_tokens (user_id, token_hash, expires_at, created_ip)
    VALUES (p_user_id, p_token_hash, p_expires_at, p_ip);
$$;

CREATE OR REPLACE FUNCTION fn_refresh_token_get(p_token_hash text) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT jsonb_build_object('userId', t.user_id, 'expiresAt', t.expires_at, 'revokedAt', t.revoked_at)
    FROM learninsurancedb.refresh_tokens t WHERE t.token_hash = p_token_hash;
$$;

CREATE OR REPLACE FUNCTION fn_refresh_token_revoke(p_token_hash text) RETURNS void
LANGUAGE sql AS $$
    UPDATE learninsurancedb.refresh_tokens SET revoked_at = now() WHERE token_hash = p_token_hash AND revoked_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION fn_refresh_token_revoke_all(p_user_id bigint) RETURNS void
LANGUAGE sql AS $$
    UPDATE learninsurancedb.refresh_tokens SET revoked_at = now() WHERE user_id = p_user_id AND revoked_at IS NULL;
$$;
