-- Day 20: user write operations (list/get/status/delete are generated: functions/generated/user.sql)
SET search_path = learninsurancedb, public;

-- Replaces the roles of a user with the given list of role ids ([1,2]).
CREATE OR REPLACE FUNCTION fn_user_set_roles(p_user_id bigint, p_role_ids jsonb, p_by text DEFAULT 'system') RETURNS void
LANGUAGE plpgsql AS $$
DECLARE v_ids bigint[];
BEGIN
    SELECT COALESCE(array_agg(x::bigint), ARRAY[]::bigint[]) INTO v_ids FROM jsonb_array_elements_text(COALESCE(p_role_ids, '[]'::jsonb)) AS x;

    DELETE FROM learninsurancedb.user_roles WHERE user_id = p_user_id AND NOT (role_id = ANY (v_ids));

    INSERT INTO learninsurancedb.user_roles (user_id, role_id, created_by)
    SELECT p_user_id, r.id, COALESCE(p_by, 'system')
    FROM learninsurancedb.roles r WHERE r.id = ANY (v_ids)
    ON CONFLICT (user_id, role_id) DO UPDATE SET is_active = TRUE, modified_date = now(), modified_by = COALESCE(p_by, 'system');
END
$$;

-- p_data: { username, email, fullName, mobile, passwordHash, roleIds: [..] }  (the API hashes the password with bcrypt)
CREATE OR REPLACE FUNCTION fn_user_create(p_data jsonb, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
    INSERT INTO learninsurancedb.users (username, email, full_name, mobile, password_hash, must_change_password, created_by)
    VALUES (p_data->>'username', p_data->>'email', p_data->>'fullName', NULLIF(p_data->>'mobile', ''),
            p_data->>'passwordHash', COALESCE((p_data->>'mustChangePassword')::boolean, FALSE), COALESCE(p_user, 'system'))
    RETURNING id INTO v_id;

    PERFORM learninsurancedb.fn_user_set_roles(v_id, p_data->'roleIds', p_user);
    RETURN learninsurancedb.fn_user_get_by_id(v_id);
END
$$;

-- Username cannot be changed after creation. Roles are only touched when 'roleIds' is present.
CREATE OR REPLACE FUNCTION fn_user_update(p_id bigint, p_data jsonb, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE learninsurancedb.users SET
        email     = CASE WHEN p_data ? 'email'    THEN p_data->>'email' ELSE email END,
        full_name = CASE WHEN p_data ? 'fullName' THEN p_data->>'fullName' ELSE full_name END,
        mobile    = CASE WHEN p_data ? 'mobile'   THEN NULLIF(p_data->>'mobile', '') ELSE mobile END,
        modified_date = now(),
        modified_by = COALESCE(p_user, 'system')
    WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User % not found', p_id USING ERRCODE = 'P0002';
    END IF;

    IF p_data ? 'roleIds' THEN
        PERFORM learninsurancedb.fn_user_set_roles(p_id, p_data->'roleIds', p_user);
    END IF;
    RETURN learninsurancedb.fn_user_get_by_id(p_id);
END
$$;

CREATE OR REPLACE FUNCTION fn_user_set_password(p_id bigint, p_password_hash text, p_must_change boolean DEFAULT FALSE, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE learninsurancedb.users
    SET password_hash = p_password_hash, must_change_password = p_must_change, failed_login_count = 0, locked_until = NULL,
        modified_date = now(), modified_by = COALESCE(p_user, 'system')
    WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User % not found', p_id USING ERRCODE = 'P0002';
    END IF;
    PERFORM learninsurancedb.fn_refresh_token_revoke_all(p_id);   -- sign the user out everywhere
    RETURN jsonb_build_object('id', p_id, 'passwordChanged', TRUE);
END
$$;
