-- Day 32: the form definition of a product line, nested (groups contain their children), ready for the React engine.
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

CREATE OR REPLACE FUNCTION fn_product_get_fields(p_type_code text) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(jsonb_agg(
        learninsurancedb.fn_product_field_json(f) ||
        CASE WHEN f.field_type = 'group' THEN
            jsonb_build_object('fields', COALESCE((
                SELECT jsonb_agg(learninsurancedb.fn_product_field_json(c) ORDER BY c.sort_order, c.id)
                FROM learninsurancedb.product_field_config c
                WHERE c.product_type_code = f.product_type_code AND c.parent_key = f.field_key AND c.is_active), '[]'::jsonb))
        ELSE '{}'::jsonb END
        ORDER BY f.sort_order, f.id), '[]'::jsonb)
    FROM learninsurancedb.product_field_config f
    WHERE f.product_type_code = upper(p_type_code) AND f.parent_key IS NULL AND f.is_active;
$$;
