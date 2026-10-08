-- Day 29: proposal write operations and the status workflow (list/get are generated: functions/generated/proposal.sql)
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION fn_status_history_add(p_type text, p_id bigint, p_from text, p_to text, p_remarks text, p_user text) RETURNS void
LANGUAGE sql AS $$
    INSERT INTO learninsurancedb.status_history (entity_type, entity_id, from_status, to_status, remarks, created_by)
    VALUES (upper(p_type), p_id, p_from, p_to, NULLIF(p_remarks, ''), COALESCE(p_user, 'system'));
$$;

CREATE OR REPLACE FUNCTION fn_status_history_get(p_type text, p_id bigint) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'id', h.id, 'fromStatus', h.from_status, 'toStatus', h.to_status, 'remarks', h.remarks,
               'changedBy', h.created_by, 'changedDate', h.created_date) ORDER BY h.created_date, h.id), '[]'::jsonb)
    FROM learninsurancedb.status_history h WHERE h.entity_type = upper(p_type) AND h.entity_id = p_id;
$$;

-- Create (p_id NULL) or update a DRAFT proposal. The premium is ALWAYS recalculated here - the client's numbers are never trusted.
-- p_data: { customerId, productId, startDate, policyTermYears, agentId, brokerId, remarks, details:{...} }
CREATE OR REPLACE FUNCTION fn_proposal_save(p_id bigint, p_data jsonb, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_existing record;
    v_customer bigint := (p_data->>'customerId')::bigint;
    v_product bigint := (p_data->>'productId')::bigint;
    v_details jsonb := COALESCE(p_data->'details', '{}'::jsonb);
    v_term int := COALESCE(NULLIF(p_data->>'policyTermYears', '')::int, 1);
    v_type text;
    v_breakup jsonb;
    v_vehicle jsonb;
    v_id bigint := p_id;
    v_kyc text;
BEGIN
    SELECT kyc_status INTO v_kyc FROM learninsurancedb.customers WHERE id = v_customer AND is_active;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % not found or inactive', v_customer USING ERRCODE = 'P0001';
    END IF;
    IF v_kyc = 'Rejected' THEN
        RAISE EXCEPTION 'KYC of this customer was rejected - a proposal cannot be created' USING ERRCODE = 'P0001';
    END IF;

    SELECT pt.code INTO v_type FROM learninsurancedb.insurance_products p
    JOIN learninsurancedb.insurance_product_types pt ON pt.id = p.product_type_id WHERE p.id = v_product;
    IF v_type IS NULL THEN
        RAISE EXCEPTION 'Product % not found', v_product USING ERRCODE = 'P0002';
    END IF;

    IF p_id IS NOT NULL THEN
        SELECT status INTO v_existing FROM learninsurancedb.proposals WHERE id = p_id AND is_active FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Proposal % not found', p_id USING ERRCODE = 'P0002';
        END IF;
        IF v_existing.status <> 'Draft' THEN
            RAISE EXCEPTION 'Only draft proposals can be edited (current status: %)', v_existing.status USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- Motor: keep the vehicle register in sync (same transaction)
    v_vehicle := v_details->'vehicle';
    IF v_type = 'MOTOR' AND NOT COALESCE((p_data->>'partial')::boolean, FALSE) AND COALESCE(v_vehicle->>'registrationNo', '') <> '' THEN
        PERFORM learninsurancedb.fn_vehicle_upsert(v_vehicle || jsonb_build_object('customerId', v_customer), p_user);
    END IF;

    -- A PARTIAL draft (wizard "save & exit" before the form is complete) is stored without a price; it cannot be submitted.
    IF COALESCE((p_data->>'partial')::boolean, FALSE) THEN
        v_breakup := NULL;
    ELSE
        v_breakup := learninsurancedb.fn_premium_calculate(v_product, v_details || jsonb_build_object('policyTermYears', v_term));
    END IF;

    IF p_id IS NULL THEN
        INSERT INTO learninsurancedb.proposals
            (customer_id, product_id, status, sum_insured, policy_term_years, start_date, net_premium, gst_amount, total_premium,
             premium_breakup, details, agent_id, broker_id, remarks, created_by)
        VALUES (v_customer, v_product, 'Draft', COALESCE((v_breakup->>'sumInsured')::numeric, 0), v_term, NULLIF(p_data->>'startDate', '')::date,
                COALESCE((v_breakup->>'netPremium')::numeric, 0), COALESCE((v_breakup->>'gstAmount')::numeric, 0), COALESCE((v_breakup->>'totalPremium')::numeric, 0),
                v_breakup, v_details, NULLIF(p_data->>'agentId', '')::bigint, NULLIF(p_data->>'brokerId', '')::bigint,
                NULLIF(p_data->>'remarks', ''), COALESCE(p_user, 'system'))
        RETURNING id INTO v_id;
        PERFORM learninsurancedb.fn_status_history_add('PROPOSAL', v_id, NULL, 'Draft', 'Proposal created', p_user);
    ELSE
        UPDATE learninsurancedb.proposals SET
            customer_id = v_customer, product_id = v_product, sum_insured = COALESCE((v_breakup->>'sumInsured')::numeric, 0),
            policy_term_years = v_term, start_date = NULLIF(p_data->>'startDate', '')::date,
            net_premium = COALESCE((v_breakup->>'netPremium')::numeric, 0), gst_amount = COALESCE((v_breakup->>'gstAmount')::numeric, 0),
            total_premium = COALESCE((v_breakup->>'totalPremium')::numeric, 0), premium_breakup = v_breakup, details = v_details,
            agent_id = NULLIF(p_data->>'agentId', '')::bigint, broker_id = NULLIF(p_data->>'brokerId', '')::bigint,
            remarks = NULLIF(p_data->>'remarks', ''), modified_date = now(), modified_by = COALESCE(p_user, 'system')
        WHERE id = p_id;
    END IF;

    RETURN learninsurancedb.fn_proposal_get_by_id(v_id);
END
$$;

-- Allowed transitions of the proposal workflow
CREATE OR REPLACE FUNCTION fn_proposal_transition_allowed(p_from text, p_to text) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE p_from
        WHEN 'Draft'        THEN p_to IN ('Submitted', 'Cancelled')
        WHEN 'Submitted'    THEN p_to IN ('Under Review', 'Approved', 'Rejected', 'Cancelled')
        WHEN 'Under Review' THEN p_to IN ('Approved', 'Rejected', 'Cancelled')
        WHEN 'Approved'     THEN p_to IN ('Issued', 'Cancelled')
        ELSE FALSE END;
$$;

CREATE OR REPLACE FUNCTION fn_proposal_change_status(p_id bigint, p_to text, p_remarks text DEFAULT NULL, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_from text;
BEGIN
    SELECT status INTO v_from FROM learninsurancedb.proposals WHERE id = p_id AND is_active FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proposal % not found', p_id USING ERRCODE = 'P0002';
    END IF;
    IF NOT learninsurancedb.fn_proposal_transition_allowed(v_from, p_to) THEN
        RAISE EXCEPTION 'A % proposal cannot move to %', v_from, p_to USING ERRCODE = 'P0001';
    END IF;
    IF p_to = 'Rejected' AND COALESCE(btrim(p_remarks), '') = '' THEN
        RAISE EXCEPTION 'Please give a reason for rejecting the proposal' USING ERRCODE = 'P0001';
    END IF;

    UPDATE learninsurancedb.proposals SET
        status = p_to,
        submitted_date = CASE WHEN p_to = 'Submitted' THEN now() ELSE submitted_date END,
        decision_date  = CASE WHEN p_to IN ('Approved', 'Rejected') THEN now() ELSE decision_date END,
        remarks = CASE WHEN p_to IN ('Rejected', 'Cancelled') AND NULLIF(p_remarks, '') IS NOT NULL THEN p_remarks ELSE remarks END,
        modified_date = now(), modified_by = COALESCE(p_user, 'system')
    WHERE id = p_id;

    PERFORM learninsurancedb.fn_status_history_add('PROPOSAL', p_id, v_from, p_to, p_remarks, p_user);
    RETURN learninsurancedb.fn_proposal_get_by_id(p_id);
END
$$;

-- Draft → Submitted, re-validating the price one more time
CREATE OR REPLACE FUNCTION fn_proposal_submit(p_id bigint, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v record;
    v_breakup jsonb;
BEGIN
    SELECT * INTO v FROM learninsurancedb.proposals WHERE id = p_id AND is_active;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proposal % not found', p_id USING ERRCODE = 'P0002';
    END IF;
    IF v.status <> 'Draft' THEN
        RAISE EXCEPTION 'Only draft proposals can be submitted (current status: %)', v.status USING ERRCODE = 'P0001';
    END IF;
    IF v.start_date IS NULL THEN
        RAISE EXCEPTION 'Choose a policy start date before submitting' USING ERRCODE = 'P0001';
    END IF;

    v_breakup := learninsurancedb.fn_premium_calculate(v.product_id, v.details || jsonb_build_object('policyTermYears', v.policy_term_years));
    UPDATE learninsurancedb.proposals SET
        sum_insured = (v_breakup->>'sumInsured')::numeric, net_premium = (v_breakup->>'netPremium')::numeric,
        gst_amount = (v_breakup->>'gstAmount')::numeric, total_premium = (v_breakup->>'totalPremium')::numeric, premium_breakup = v_breakup
    WHERE id = p_id;

    RETURN learninsurancedb.fn_proposal_change_status(p_id, 'Submitted', 'Submitted for underwriting', p_user);
END
$$;

-- Day 37: unified submission - save (create or update the draft) AND submit in ONE transaction.
-- If the price cannot be calculated or any rule fails, nothing is saved.
CREATE OR REPLACE FUNCTION fn_proposal_save_and_submit(p_id bigint, p_data jsonb, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_saved jsonb;
BEGIN
    v_saved := learninsurancedb.fn_proposal_save(p_id, p_data - 'partial', p_user);
    RETURN learninsurancedb.fn_proposal_submit((v_saved->>'id')::bigint, p_user);
END
$$;