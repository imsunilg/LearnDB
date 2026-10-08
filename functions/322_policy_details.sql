-- Day 41: everything the policy details page needs in ONE call (one round trip instead of six).
-- Later days extend it with renewals, endorsements, claims, payments and documents.
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION fn_policy_get_details(p_id bigint) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_policy jsonb;
BEGIN
    v_policy := learninsurancedb.fn_policy_get_by_id(p_id);
    IF v_policy IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN jsonb_build_object(
        'policy', v_policy,
        'customer', (SELECT learninsurancedb.fn_to_camel(to_jsonb(c)) - 'createdBy' - 'modifiedBy'
                     FROM learninsurancedb.customers c WHERE c.id = (v_policy->>'customerId')::bigint),
        'sections', COALESCE((SELECT jsonb_agg(jsonb_build_object('name', d.section_name, 'data', d.section_data) ORDER BY d.id)
                              FROM learninsurancedb.policy_details d WHERE d.policy_id = p_id AND d.is_active), '[]'::jsonb),
        'history', learninsurancedb.fn_status_history_get('POLICY', p_id)
    );
END
$$;
