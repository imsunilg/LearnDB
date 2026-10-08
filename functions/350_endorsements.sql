-- Day 43: endorsement request + decision (list/get are generated: functions/generated/endorsement.sql)
SET search_path = learninsurancedb, public;

-- [{field, from, to}] for every key whose value differs between two JSON objects
CREATE OR REPLACE FUNCTION fn_json_diff(p_before jsonb, p_after jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object('field', k.key, 'from', p_before->k.key, 'to', p_after->k.key) ORDER BY k.key), '[]'::jsonb)
    FROM (SELECT key FROM jsonb_each(COALESCE(p_before, '{}'::jsonb)) UNION SELECT key FROM jsonb_each(COALESCE(p_after, '{}'::jsonb))) k
    WHERE (p_before->k.key) IS DISTINCT FROM (p_after->k.key);
$$;

-- p_data depends on the type:
--   ADDRESS_CHANGE: { addressLine, state, city, pincode }
--   ADD_NOMINEE:    { name, relationship, sharePercent, dateOfBirth }
--   VEHICLE_CHANGE: { registrationNo, make, model, variant, fuelType, manufactureYear, cubicCapacity, idv }   (motor only)
CREATE OR REPLACE FUNCTION fn_endorsement_create(p_policy_id bigint, p_type text, p_effective date, p_data jsonb, p_remarks text DEFAULT NULL, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_pol record;
    v_type_code text;
    v_section text;
    v_before jsonb;
    v_after jsonb;
    v_adjust numeric := 0;
    v_details jsonb := '{}'::jsonb;
    v_sec record;
    v_old_total numeric; v_new_total numeric;
    v_remaining int; v_total_days int;
    v_new_idv numeric;
    v_id bigint;
BEGIN
    SELECT p.*, pt.code AS type_code INTO v_pol
    FROM learninsurancedb.policies p
    JOIN learninsurancedb.insurance_products pr ON pr.id = p.product_id
    JOIN learninsurancedb.insurance_product_types pt ON pt.id = pr.product_type_id
    WHERE p.id = p_policy_id FOR UPDATE OF p;
    IF NOT FOUND THEN RAISE EXCEPTION 'Policy % not found', p_policy_id USING ERRCODE = 'P0002'; END IF;
    v_type_code := v_pol.type_code;

    IF v_pol.status <> 'Active' OR v_pol.end_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Only active, unexpired policies can be endorsed' USING ERRCODE = 'P0001';
    END IF;
    IF p_effective < v_pol.start_date OR p_effective > v_pol.end_date THEN
        RAISE EXCEPTION 'The effective date must be within the policy period (% to %)', v_pol.start_date, v_pol.end_date USING ERRCODE = 'P0001';
    END IF;
    IF EXISTS (SELECT 1 FROM learninsurancedb.endorsements WHERE policy_id = p_policy_id AND status = 'Requested') THEN
        RAISE EXCEPTION 'This policy already has a pending endorsement - decide it first' USING ERRCODE = 'P0001';
    END IF;

    IF p_type = 'ADDRESS_CHANGE' THEN
        v_section := CASE WHEN v_type_code = 'HOME' THEN 'property' ELSE 'address' END;
        SELECT section_data INTO v_before FROM learninsurancedb.policy_details WHERE policy_id = p_policy_id AND section_name = v_section;
        v_after := COALESCE(v_before, '{}'::jsonb) || (p_data - 'sharePercent');
        IF COALESCE(p_data->>'addressLine', '') = '' THEN RAISE EXCEPTION 'The new address is required' USING ERRCODE = 'P0001'; END IF;

    ELSIF p_type = 'ADD_NOMINEE' THEN
        v_section := 'nominee';
        IF COALESCE(p_data->>'name', '') = '' THEN RAISE EXCEPTION 'Nominee name is required' USING ERRCODE = 'P0001'; END IF;
        IF COALESCE((p_data->>'sharePercent')::numeric, 0) NOT BETWEEN 1 AND 100 THEN
            RAISE EXCEPTION 'Nominee share must be between 1 and 100 percent' USING ERRCODE = 'P0001';
        END IF;
        SELECT section_data INTO v_before FROM learninsurancedb.policy_details WHERE policy_id = p_policy_id AND section_name = v_section;
        v_after := p_data;

    ELSIF p_type = 'VEHICLE_CHANGE' THEN
        IF v_type_code <> 'MOTOR' THEN RAISE EXCEPTION 'Vehicle change applies to motor policies only' USING ERRCODE = 'P0001'; END IF;
        v_section := 'vehicle';
        SELECT section_data INTO v_before FROM learninsurancedb.policy_details WHERE policy_id = p_policy_id AND section_name = 'vehicle';
        v_after := COALESCE(v_before, '{}'::jsonb) || (p_data - 'idv');

        -- re-price the policy with the new vehicle / IDV and charge or refund the pro-rata difference
        FOR v_sec IN SELECT section_name, section_data FROM learninsurancedb.policy_details WHERE policy_id = p_policy_id LOOP
            v_details := v_details || jsonb_build_object(v_sec.section_name, v_sec.section_data);
        END LOOP;
        v_new_idv := COALESCE(NULLIF(p_data->>'idv', '')::numeric, (v_details#>>'{insurance,idv}')::numeric);
        v_details := jsonb_set(jsonb_set(v_details, '{vehicle}', v_after), '{insurance,idv}', to_jsonb(v_new_idv));
        v_new_total := (learninsurancedb.fn_premium_calculate(v_pol.product_id, v_details || jsonb_build_object('policyTermYears', v_pol.policy_term_years))->>'totalPremium')::numeric;
        v_old_total := v_pol.total_premium;
        v_total_days := GREATEST(v_pol.end_date - v_pol.start_date + 1, 1);
        v_remaining := GREATEST(v_pol.end_date - p_effective + 1, 0);
        v_adjust := round((v_new_total - v_old_total) * v_remaining / v_total_days, 2);
        v_after := v_after || jsonb_build_object('idv', v_new_idv);
        v_before := COALESCE(v_before, '{}'::jsonb) || jsonb_build_object('idv', (SELECT (section_data->>'idv')::numeric FROM learninsurancedb.policy_details WHERE policy_id = p_policy_id AND section_name = 'insurance'));
    ELSE
        RAISE EXCEPTION 'Unknown endorsement type %', p_type USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO learninsurancedb.endorsements (policy_id, endorsement_type, effective_date, section_name, before_data, after_data, changes, premium_adjustment, remarks, created_by)
    VALUES (p_policy_id, p_type, p_effective, v_section, v_before, v_after, learninsurancedb.fn_json_diff(v_before, v_after), v_adjust, NULLIF(p_remarks, ''), COALESCE(p_user, 'system'))
    RETURNING id INTO v_id;

    RETURN learninsurancedb.fn_endorsement_get_by_id(v_id);
END
$$;

CREATE OR REPLACE FUNCTION fn_endorsement_decide(p_id bigint, p_approve boolean, p_remarks text, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    e record;
BEGIN
    SELECT * INTO e FROM learninsurancedb.endorsements WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Endorsement % not found', p_id USING ERRCODE = 'P0002'; END IF;
    IF e.status <> 'Requested' THEN RAISE EXCEPTION 'This endorsement was already %', lower(e.status) USING ERRCODE = 'P0001'; END IF;
    IF NOT p_approve AND COALESCE(btrim(p_remarks), '') = '' THEN RAISE EXCEPTION 'Please give a reason for rejecting' USING ERRCODE = 'P0001'; END IF;

    IF p_approve THEN
        INSERT INTO learninsurancedb.policy_details (policy_id, section_name, section_data, created_by)
        VALUES (e.policy_id, e.section_name, e.after_data - 'idv', COALESCE(p_user, 'system'))
        ON CONFLICT (policy_id, section_name) DO UPDATE SET section_data = EXCLUDED.section_data, modified_date = now(), modified_by = COALESCE(p_user, 'system');
        IF e.endorsement_type = 'VEHICLE_CHANGE' AND e.after_data ? 'idv' THEN
            UPDATE learninsurancedb.policy_details SET section_data = jsonb_set(section_data, '{idv}', e.after_data->'idv'), modified_date = now()
            WHERE policy_id = e.policy_id AND section_name = 'insurance';
        END IF;
        PERFORM learninsurancedb.fn_status_history_add('POLICY', e.policy_id, 'Active', 'Active', 'Endorsement ' || e.endorsement_no || ' applied (' || e.endorsement_type || ')', p_user);
    END IF;

    UPDATE learninsurancedb.endorsements SET status = CASE WHEN p_approve THEN 'Approved' ELSE 'Rejected' END,
        remarks = COALESCE(NULLIF(p_remarks, ''), remarks), decided_by = COALESCE(p_user, 'system'), decided_date = now(),
        modified_date = now(), modified_by = COALESCE(p_user, 'system')
    WHERE id = p_id;
    RETURN learninsurancedb.fn_endorsement_get_by_id(p_id);
END
$$;
