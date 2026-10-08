-- Day 21: role ↔ permission functions (role list/get/create/update are generated: functions/generated/role.sql)
SET search_path = learninsurancedb, public;

-- Catalogue grouped by module: [{ module, permissions: [{ key, action, description }] }]
CREATE OR REPLACE FUNCTION fn_permission_catalog() RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(jsonb_agg(g ORDER BY g->>'module'), '[]'::jsonb) FROM (
        SELECT jsonb_build_object(
                   'module', p.module,
                   'permissions', jsonb_agg(jsonb_build_object('key', p.key, 'action', p.action, 'description', p.description) ORDER BY p.key)) AS g
        FROM learninsurancedb.permissions p WHERE p.is_active
        GROUP BY p.module
    ) x;
$$;

CREATE OR REPLACE FUNCTION fn_role_get_permissions(p_role_id bigint) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(jsonb_agg(rp.permission ORDER BY rp.permission), '[]'::jsonb)
    FROM learninsurancedb.role_permissions rp WHERE rp.role_id = p_role_id AND rp.is_active;
$$;

-- Replaces the permission set of a role. Unknown permission keys are rejected.
CREATE OR REPLACE FUNCTION fn_role_set_permissions(p_role_id bigint, p_permissions jsonb, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_keys text[];
    v_unknown text[];
BEGIN
    IF NOT EXISTS (SELECT 1 FROM learninsurancedb.roles WHERE id = p_role_id) THEN
        RAISE EXCEPTION 'Role % not found', p_role_id USING ERRCODE = 'P0002';
    END IF;

    SELECT COALESCE(array_agg(DISTINCT x), ARRAY[]::text[]) INTO v_keys FROM jsonb_array_elements_text(COALESCE(p_permissions, '[]'::jsonb)) AS x;

    SELECT array_agg(k) INTO v_unknown FROM unnest(v_keys) AS k
    WHERE NOT EXISTS (SELECT 1 FROM learninsurancedb.permissions p WHERE p.key = k);
    IF v_unknown IS NOT NULL THEN
        RAISE EXCEPTION 'Unknown permission(s): %', array_to_string(v_unknown, ', ') USING ERRCODE = 'P0001';
    END IF;

    DELETE FROM learninsurancedb.role_permissions WHERE role_id = p_role_id AND NOT (permission = ANY (v_keys));

    INSERT INTO learninsurancedb.role_permissions (role_id, permission, created_by)
    SELECT p_role_id, k, COALESCE(p_user, 'system') FROM unnest(v_keys) AS k
    ON CONFLICT (role_id, permission) DO UPDATE SET is_active = TRUE;

    UPDATE learninsurancedb.roles SET modified_date = now(), modified_by = COALESCE(p_user, 'system') WHERE id = p_role_id;
    RETURN learninsurancedb.fn_role_get_permissions(p_role_id);
END
$$;
