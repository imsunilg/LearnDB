-- Day 32/35: the form definition of a product line as a nested tree (groups contain their children, groups may nest),
-- ready for the React engine.
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION fn_product_field_json(p_row learninsurancedb.product_field_config) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT jsonb_strip_nulls(jsonb_build_object(
        'key', p_row.field_key, 'label', p_row.label, 'type', p_row.field_type, 'valueType', p_row.value_type,
        'required', p_row.required, 'section', p_row.section, 'options', p_row.options,
        'masterType', p_row.master_type, 'valueKey', p_row.value_key, 'parentField', p_row.parent_field, 'parentMasterType', p_row.parent_master_type,
        'showIf', p_row.show_if, 'validation', p_row.validation, 'defaultValue', p_row.default_value,
        'hint', p_row.hint, 'placeholder', p_row.placeholder));
$$;

-- Recursive (plpgsql, because a SQL function cannot reference itself while being created)
CREATE OR REPLACE FUNCTION fn_product_field_tree(p_type_code text, p_parent_key text) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(
               learninsurancedb.fn_product_field_json(f) ||
               CASE WHEN f.field_type = 'group'
                    THEN jsonb_build_object('fields', learninsurancedb.fn_product_field_tree(p_type_code, f.field_key))
                    ELSE '{}'::jsonb END
               ORDER BY f.sort_order, f.id), '[]'::jsonb)
    INTO v_result
    FROM learninsurancedb.product_field_config f
    WHERE f.product_type_code = upper(p_type_code) AND f.is_active AND f.parent_key IS NOT DISTINCT FROM p_parent_key;
    RETURN v_result;
END
$$;

CREATE OR REPLACE FUNCTION fn_product_get_fields(p_type_code text) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT learninsurancedb.fn_product_field_tree(p_type_code, NULL);
$$;
