-- Day 30: policy issuance (list/get are generated: functions/generated/policy.sql)
SET search_path = learninsurancedb, public;

-- POL-MOT-2026-000042
CREATE OR REPLACE FUNCTION fn_next_policy_no(p_type_code text) RETURNS text
LANGUAGE sql AS $$
    SELECT 'POL-' || left(upper(p_type_code), 3) || '-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('learninsurancedb.seq_policy_no')::text, 6, '0');
$$;

-- Issue a policy from an APPROVED proposal. Everything happens in ONE transaction (the function call):
-- policy row, risk sections, proposal → Issued, status history. If any step fails nothing is saved.
CREATE OR REPLACE FUNCTION fn_policy_create(p_proposal_id bigint, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_prop record;
    v_type text;
    v_policy_id bigint;
    v_section record;
BEGIN
    SELECT p.*, pt.code AS type_code INTO v_prop
    FROM learninsurancedb.proposals p
    JOIN learninsurancedb.insurance_products pr ON pr.id = p.product_id
    JOIN learninsurancedb.insurance_product_types pt ON pt.id = pr.product_type_id
    WHERE p.id = p_proposal_id AND p.is_active
    FOR UPDATE OF p;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proposal % not found', p_proposal_id USING ERRCODE = 'P0002';
    END IF;
    IF v_prop.status <> 'Approved' THEN
        RAISE EXCEPTION 'Only approved proposals can be issued (current status: %)', v_prop.status USING ERRCODE = 'P0001';
    END IF;
    IF EXISTS (SELECT 1 FROM learninsurancedb.policies WHERE proposal_id = p_proposal_id) THEN
        RAISE EXCEPTION 'A policy has already been issued for this proposal' USING ERRCODE = 'P0001';
    END IF;
    IF v_prop.start_date IS NULL THEN
        RAISE EXCEPTION 'The proposal has no start date' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO learninsurancedb.policies
        (policy_no, proposal_id, customer_id, product_id, status, start_date, end_date, policy_term_years, sum_insured,
         net_premium, gst_amount, total_premium, premium_breakup, agent_id, broker_id, issued_by, created_by)
    VALUES (learninsurancedb.fn_next_policy_no(v_prop.type_code), v_prop.id, v_prop.customer_id, v_prop.product_id, 'Active',
            v_prop.start_date, ((v_prop.start_date + make_interval(years => v_prop.policy_term_years))::date - 1), v_prop.policy_term_years,
            v_prop.sum_insured, v_prop.net_premium, v_prop.gst_amount, v_prop.total_premium, v_prop.premium_breakup,
            v_prop.agent_id, v_prop.broker_id, COALESCE(p_user, 'system'), COALESCE(p_user, 'system'))
    RETURNING id INTO v_policy_id;

    -- Every top-level key of the proposal details becomes a section (vehicle, insurance, members ...)
    FOR v_section IN SELECT key, value FROM jsonb_each(v_prop.details) LOOP
        INSERT INTO learninsurancedb.policy_details (policy_id, section_name, section_data, created_by)
        VALUES (v_policy_id, v_section.key, v_section.value, COALESCE(p_user, 'system'));
    END LOOP;

    UPDATE learninsurancedb.proposals SET status = 'Issued', modified_date = now(), modified_by = COALESCE(p_user, 'system') WHERE id = p_proposal_id;
    PERFORM learninsurancedb.fn_status_history_add('PROPOSAL', p_proposal_id, 'Approved', 'Issued', 'Policy issued', p_user);
    PERFORM learninsurancedb.fn_status_history_add('POLICY', v_policy_id, NULL, 'Active', 'Policy issued from ' || v_prop.proposal_no, p_user);

    RETURN learninsurancedb.fn_policy_get_by_id(v_policy_id);
END
$$;
