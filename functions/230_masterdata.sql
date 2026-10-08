-- Day 25: dropdown-oriented master data reads (admin CRUD is generated: functions/generated/master_data.sql)
SET search_path = learninsurancedb, public;

-- Active items of one type (optionally the children of a parent) ordered for dropdowns. Cached by the API.
CREATE OR REPLACE FUNCTION fn_masterdata_get_by_type(p_type text, p_parent_id bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'id', m.id, 'code', m.code, 'name', m.name, 'parentId', m.parent_id, 'meta', m.meta
           ) ORDER BY m.sort_order, m.name), '[]'::jsonb)
    FROM learninsurancedb.master_data m
    WHERE m.type = upper(p_type) AND m.is_active
      AND (p_parent_id IS NULL OR m.parent_id = p_parent_id);
$$;

-- Types with item counts, for the admin screen
CREATE OR REPLACE FUNCTION fn_masterdata_get_types() RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object('type', t.type, 'count', t.cnt) ORDER BY t.type), '[]'::jsonb)
    FROM (SELECT type, count(*) AS cnt FROM learninsurancedb.master_data GROUP BY type) t;
$$;
