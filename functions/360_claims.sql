-- Day 44: claim intimation and the claim workflow (list/get generated: functions/generated/claim.sql)
SET search_path = learninsurancedb, public;

-- Which claim types make sense for a product line
CREATE OR REPLACE FUNCTION fn_claim_type_allowed(p_product_type text, p_claim_type text) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE p_product_type
        WHEN 'MOTOR'  THEN p_claim_type IN ('ACCIDENT', 'THEFT', 'FIRE', 'NATURAL_CALAMITY')
        WHEN 'HEALTH' THEN p_claim_type IN ('HOSPITALISATION')
        WHEN 'HOME'   THEN p_claim_type IN ('FIRE', 'THEFT', 'NATURAL_CALAMITY')
        WHEN 'TRAVEL' THEN p_claim_type IN ('TRIP_CANCELLATION', 'BAGGAGE_LOSS', 'HOSPITALISATION', 'ACCIDENT')
        ELSE FALSE END;
$$;

-- p_data: { policyId, claimType, incidentDate, incidentLocation, description, claimedAmount }
CREATE OR REPLACE FUNCTION fn_claim_create(p_data jsonb, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_pol record;
    v_incident date := (p_data->>'incidentDate')::date;
    v_amount numeric := (p_data->>'claimedAmount')::numeric;
    v_type text := upper(p_data->>'claimType');
    v_id bigint;
BEGIN
    SELECT p.*, pt.code AS type_code INTO v_pol
    FROM learninsurancedb.policies p
    JOIN learninsurancedb.insurance_products pr ON pr.id = p.product_id
    JOIN learninsurancedb.insurance_product_types pt ON pt.id = pr.product_type_id
    WHERE p.id = (p_data->>'policyId')::bigint AND p.is_active;
    IF NOT FOUND THEN RAISE EXCEPTION 'Policy not found' USING ERRCODE = 'P0002'; END IF;
    IF v_pol.status IN ('Cancelled', 'Lapsed') THEN RAISE EXCEPTION 'Claims cannot be made on a % policy', lower(v_pol.status) USING ERRCODE = 'P0001'; END IF;

    IF v_incident > CURRENT_DATE THEN RAISE EXCEPTION 'The incident date cannot be in the future' USING ERRCODE = 'P0001'; END IF;
    IF v_incident < v_pol.start_date OR v_incident > v_pol.end_date THEN
        RAISE EXCEPTION 'The incident (%) happened outside the policy period (% to %)', v_incident, v_pol.start_date, v_pol.end_date USING ERRCODE = 'P0001';
    END IF;
    IF NOT learninsurancedb.fn_claim_type_allowed(v_pol.type_code, v_type) THEN
        RAISE EXCEPTION 'A % claim is not applicable to a % policy', v_type, v_pol.type_code USING ERRCODE = 'P0001';
    END IF;
    IF v_amount IS NULL OR v_amount <= 0 THEN RAISE EXCEPTION 'The claimed amount must be greater than zero' USING ERRCODE = 'P0001'; END IF;
    IF v_amount > v_pol.sum_insured THEN
        RAISE EXCEPTION 'The claimed amount cannot exceed the sum insured (%)', v_pol.sum_insured USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO learninsurancedb.claims (policy_id, customer_id, claim_type, incident_date, incident_location, description, claimed_amount, created_by)
    VALUES (v_pol.id, v_pol.customer_id, v_type, v_incident, NULLIF(p_data->>'incidentLocation', ''), p_data->>'description', v_amount, COALESCE(p_user, 'system'))
    RETURNING id INTO v_id;

    PERFORM learninsurancedb.fn_status_history_add('CLAIM', v_id, NULL, 'Intimated', 'Claim intimated', p_user);
    RETURN learninsurancedb.fn_claim_get_by_id(v_id);
END
$$;

CREATE OR REPLACE FUNCTION fn_claim_transition_allowed(p_from text, p_to text) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE p_from
        WHEN 'Intimated'         THEN p_to IN ('Under Review', 'Documents Pending', 'Rejected', 'Withdrawn')
        WHEN 'Under Review'      THEN p_to IN ('Documents Pending', 'Approved', 'Rejected', 'Withdrawn')
        WHEN 'Documents Pending' THEN p_to IN ('Under Review', 'Rejected', 'Withdrawn')
        WHEN 'Approved'          THEN p_to IN ('Settled')
        ELSE FALSE END;
$$;

CREATE OR REPLACE FUNCTION fn_claim_change_status(p_id bigint, p_to text, p_remarks text DEFAULT NULL, p_approved_amount numeric DEFAULT NULL, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    c record;
    v_sum numeric;
BEGIN
    SELECT * INTO c FROM learninsurancedb.claims WHERE id = p_id AND is_active FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Claim % not found', p_id USING ERRCODE = 'P0002'; END IF;
    IF NOT learninsurancedb.fn_claim_transition_allowed(c.status, p_to) THEN
        RAISE EXCEPTION 'A % claim cannot move to %', c.status, p_to USING ERRCODE = 'P0001';
    END IF;
    IF p_to IN ('Rejected', 'Documents Pending') AND COALESCE(btrim(p_remarks), '') = '' THEN
        RAISE EXCEPTION 'Please give a % for this decision', CASE WHEN p_to = 'Rejected' THEN 'reason' ELSE 'note about the documents needed' END USING ERRCODE = 'P0001';
    END IF;
    IF p_to = 'Approved' THEN
        SELECT sum_insured INTO v_sum FROM learninsurancedb.policies WHERE id = c.policy_id;
        IF p_approved_amount IS NULL OR p_approved_amount <= 0 THEN RAISE EXCEPTION 'Enter the approved amount' USING ERRCODE = 'P0001'; END IF;
        IF p_approved_amount > c.claimed_amount THEN RAISE EXCEPTION 'The approved amount cannot exceed the claimed amount (%)', c.claimed_amount USING ERRCODE = 'P0001'; END IF;
        IF p_approved_amount > v_sum THEN RAISE EXCEPTION 'The approved amount cannot exceed the sum insured (%)', v_sum USING ERRCODE = 'P0001'; END IF;
    END IF;

    UPDATE learninsurancedb.claims SET
        status = p_to,
        approved_amount = CASE WHEN p_to = 'Approved' THEN p_approved_amount WHEN p_to = 'Rejected' THEN NULL ELSE approved_amount END,
        decision_date = CASE WHEN p_to IN ('Approved', 'Rejected') THEN now() ELSE decision_date END,
        settled_date = CASE WHEN p_to = 'Settled' THEN now() ELSE settled_date END,
        remarks = COALESCE(NULLIF(p_remarks, ''), remarks),
        modified_date = now(), modified_by = COALESCE(p_user, 'system')
    WHERE id = p_id;

    PERFORM learninsurancedb.fn_status_history_add('CLAIM', p_id, c.status, p_to, p_remarks, p_user);
    RETURN learninsurancedb.fn_claim_get_by_id(p_id);
END
$$;
