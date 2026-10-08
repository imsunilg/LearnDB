-- Day 42: renewals - due list, quote and renew in one transaction.
SET search_path = learninsurancedb, public;

-- Policies in the renewal window (ended up to 90 days ago or ending within 90 days). Travel is one-off and never renews.
DROP VIEW IF EXISTS learninsurancedb.vw_renewals CASCADE;
CREATE VIEW learninsurancedb.vw_renewals AS
SELECT p.id AS policy_id, p.policy_no, p.customer_id, c.full_name AS customer_name, c.mobile AS customer_mobile, c.email AS customer_email,
       p.product_id, pr.name AS product_name, pt.code AS product_type_code, pt.icon AS product_type_icon,
       p.start_date, p.end_date, (p.end_date - CURRENT_DATE) AS days_to_expiry, p.total_premium AS current_premium, p.sum_insured,
       p.agent_id, a.full_name AS agent_name,
       r.status AS record_status, r.remarks AS record_remarks,
       (SELECT n.id FROM learninsurancedb.policies n WHERE n.parent_policy_id = p.id LIMIT 1) AS renewed_policy_id,
       CASE WHEN EXISTS (SELECT 1 FROM learninsurancedb.policies n WHERE n.parent_policy_id = p.id) THEN 'Renewed'
            WHEN r.status = 'Declined' THEN 'Declined'
            WHEN p.end_date < CURRENT_DATE THEN 'Overdue'
            ELSE 'Due' END AS renewal_status
FROM learninsurancedb.policies p
JOIN learninsurancedb.customers c ON c.id = p.customer_id
JOIN learninsurancedb.insurance_products pr ON pr.id = p.product_id
JOIN learninsurancedb.insurance_product_types pt ON pt.id = pr.product_type_id
LEFT JOIN learninsurancedb.agents a ON a.id = p.agent_id
LEFT JOIN learninsurancedb.renewals r ON r.policy_id = p.id
WHERE p.status = 'Active' AND pt.code <> 'TRAVEL'
  AND p.end_date BETWEEN CURRENT_DATE - 90 AND CURRENT_DATE + 90;

-- filters: days (window: end date <= today + N), renewalStatus, productTypeCode, agentId
DROP FUNCTION IF EXISTS learninsurancedb.fn_renewal_get_due(text, int, int, text, text, jsonb);
CREATE FUNCTION learninsurancedb.fn_renewal_get_due(
    p_search text DEFAULT NULL, p_page int DEFAULT 1, p_page_size int DEFAULT 10,
    p_sort_by text DEFAULT NULL, p_sort_dir text DEFAULT NULL, p_filters jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_page int := GREATEST(COALESCE(p_page, 1), 1);
    v_size int := LEAST(GREATEST(COALESCE(p_page_size, 10), 1), 200);
    v_sort text := learninsurancedb.fn_to_snake(p_sort_by);
    v_dir  text := CASE WHEN lower(COALESCE(p_sort_dir, 'asc')) = 'desc' THEN 'DESC' ELSE 'ASC' END;
    v_f    jsonb := COALESCE(p_filters, '{}'::jsonb);
    v_where text := 'WHERE TRUE';
    v_like text; v_total bigint; v_items jsonb; v_facets jsonb;
BEGIN
    IF v_sort IS NULL OR NOT (v_sort = ANY (ARRAY['policy_no','customer_name','product_name','end_date','days_to_expiry','current_premium','renewal_status'])) THEN
        v_sort := 'end_date'; IF p_sort_by IS NULL THEN v_dir := 'ASC'; END IF;
    END IF;
    IF p_search IS NOT NULL AND btrim(p_search) <> '' THEN
        v_like := '%' || btrim(p_search) || '%';
        v_where := v_where || format(' AND (policy_no ILIKE %1$L OR customer_name ILIKE %1$L OR customer_mobile ILIKE %1$L OR product_name ILIKE %1$L)', v_like);
    END IF;
    IF NULLIF(v_f->>'days', '') IS NOT NULL THEN v_where := v_where || format(' AND end_date <= CURRENT_DATE + %s', (v_f->>'days')::int); END IF;
    IF NULLIF(v_f->>'renewalStatus', '') IS NOT NULL THEN v_where := v_where || format(' AND renewal_status = %L', v_f->>'renewalStatus'); END IF;
    IF NULLIF(v_f->>'productTypeCode', '') IS NOT NULL THEN v_where := v_where || format(' AND product_type_code = %L', upper(v_f->>'productTypeCode')); END IF;
    IF NULLIF(v_f->>'agentId', '') IS NOT NULL THEN v_where := v_where || format(' AND agent_id = %L::bigint', v_f->>'agentId'); END IF;

    EXECUTE format('SELECT count(*) FROM learninsurancedb.vw_renewals %s', v_where) INTO v_total;
    EXECUTE format('SELECT COALESCE(jsonb_agg(learninsurancedb.fn_to_camel(to_jsonb(q))), ''[]''::jsonb)
                    FROM (SELECT * FROM learninsurancedb.vw_renewals %s ORDER BY %I %s, policy_id LIMIT %s OFFSET %s) q',
                   v_where, v_sort, v_dir, v_size, (v_page - 1) * v_size) INTO v_items;
    EXECUTE format('SELECT COALESCE(jsonb_object_agg(renewal_status, c), ''{}''::jsonb)
                    FROM (SELECT renewal_status, count(*) AS c FROM learninsurancedb.vw_renewals %s GROUP BY renewal_status) f', v_where) INTO v_facets;

    RETURN jsonb_build_object('items', v_items, 'totalCount', v_total, 'page', v_page, 'pageSize', v_size, 'facets', v_facets);
END
$$;

-- Next NCB slab (0 → 20 → 25 → 35 → 45 → 50). A claim during the term resets it to 0.
CREATE OR REPLACE FUNCTION fn_next_ncb(p_current numeric, p_had_claim boolean) RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT CASE WHEN p_had_claim THEN 0::numeric
                ELSE COALESCE((SELECT rate_value FROM learninsurancedb.premium_rates
                               WHERE rate_group = 'MOTOR_NCB' AND rate_value > p_current ORDER BY rate_value LIMIT 1), p_current) END;
$$;

-- Builds the renewal proposal data (same product when still on sale) and prices it.
CREATE OR REPLACE FUNCTION fn_renewal_quote(p_policy_id bigint) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_pol record;
    v_type text;
    v_details jsonb := '{}'::jsonb;
    v_section record;
    v_claims int := 0;
    v_old_ncb numeric; v_new_ncb numeric;
    v_idv jsonb;
    v_changes jsonb := '[]'::jsonb;
    v_start date;
    v_breakup jsonb;
    v_product bigint;
BEGIN
    SELECT p.*, pt.code AS type_code INTO v_pol
    FROM learninsurancedb.policies p
    JOIN learninsurancedb.insurance_products pr ON pr.id = p.product_id
    JOIN learninsurancedb.insurance_product_types pt ON pt.id = pr.product_type_id
    WHERE p.id = p_policy_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Policy % not found', p_policy_id USING ERRCODE = 'P0002'; END IF;
    v_type := v_pol.type_code;
    IF v_type = 'TRAVEL' THEN RAISE EXCEPTION 'Travel policies are single-trip and cannot be renewed' USING ERRCODE = 'P0001'; END IF;

    FOR v_section IN SELECT section_name, section_data FROM learninsurancedb.policy_details WHERE policy_id = p_policy_id LOOP
        v_details := v_details || jsonb_build_object(v_section.section_name, v_section.section_data);
    END LOOP;

    -- Motor: claims-free years step the NCB up; IDV follows depreciation of the (now older) vehicle
    IF v_type = 'MOTOR' THEN
        IF to_regclass('learninsurancedb.claims') IS NOT NULL THEN
            EXECUTE 'SELECT count(*) FROM learninsurancedb.claims WHERE policy_id = $1 AND status NOT IN (''Rejected'', ''Withdrawn'')' INTO v_claims USING p_policy_id;
        END IF;
        v_old_ncb := COALESCE((v_details#>>'{insurance,ncbPercent}')::numeric, 0);
        v_new_ncb := learninsurancedb.fn_next_ncb(v_old_ncb, v_claims > 0);
        v_details := jsonb_set(v_details, '{insurance,ncbPercent}', to_jsonb(v_new_ncb));
        IF v_new_ncb <> v_old_ncb THEN
            v_changes := v_changes || jsonb_build_object('field', 'No Claim Bonus', 'from', v_old_ncb::int || '%', 'to', v_new_ncb::int || '%');
        ELSIF v_claims > 0 THEN
            v_changes := v_changes || jsonb_build_object('field', 'No Claim Bonus', 'from', v_old_ncb::int || '%', 'to', '0% (claim made)');
        END IF;

        v_idv := learninsurancedb.fn_motor_idv_suggest(v_details#>>'{vehicle,model}', (v_details#>>'{vehicle,manufactureYear}')::int);
        IF v_idv IS NOT NULL THEN
            v_details := jsonb_set(v_details, '{insurance,idv}', v_idv->'suggestedIdv');
            v_changes := v_changes || jsonb_build_object('field', 'IDV', 'from', (v_pol.sum_insured)::text, 'to', (v_idv->>'suggestedIdv'));
        END IF;
    END IF;

    v_start := GREATEST(v_pol.end_date + 1, CURRENT_DATE);
    v_product := v_pol.product_id;
    -- if the old plan is no longer on sale, move to the newest live plan of the same line
    IF NOT EXISTS (SELECT 1 FROM learninsurancedb.insurance_products WHERE id = v_product AND is_active AND effective_from <= CURRENT_DATE
                   AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)) THEN
        SELECT pr.id INTO v_product FROM learninsurancedb.insurance_products pr JOIN learninsurancedb.insurance_product_types pt ON pt.id = pr.product_type_id
        WHERE pt.code = v_type AND pr.is_active AND pr.effective_from <= CURRENT_DATE AND (pr.effective_to IS NULL OR pr.effective_to >= CURRENT_DATE)
        ORDER BY pr.effective_from DESC LIMIT 1;
        IF v_product IS NULL THEN RAISE EXCEPTION 'No plan of this product line is currently on sale' USING ERRCODE = 'P0001'; END IF;
        v_changes := v_changes || jsonb_build_object('field', 'Plan', 'from', 'previous plan', 'to', 'newest live plan');
    END IF;

    v_breakup := learninsurancedb.fn_premium_calculate(v_product, v_details || jsonb_build_object('policyTermYears', v_pol.policy_term_years));

    RETURN jsonb_build_object(
        'policyId', p_policy_id, 'policyNo', v_pol.policy_no, 'customerId', v_pol.customer_id, 'productId', v_product,
        'agentId', v_pol.agent_id, 'termYears', v_pol.policy_term_years, 'newStartDate', v_start,
        'newEndDate', ((v_start + make_interval(years => v_pol.policy_term_years))::date - 1),
        'previousPremium', v_pol.total_premium, 'renewalPremium', (v_breakup->>'totalPremium')::numeric,
        'difference', (v_breakup->>'totalPremium')::numeric - v_pol.total_premium,
        'differencePercent', CASE WHEN v_pol.total_premium = 0 THEN 0 ELSE round(((v_breakup->>'totalPremium')::numeric - v_pol.total_premium) / v_pol.total_premium * 100, 1) END,
        'breakup', v_breakup, 'details', v_details, 'changes', v_changes);
END
$$;

-- Renew: quote → proposal → approved → new policy linked to the old one. ONE transaction.
CREATE OR REPLACE FUNCTION fn_renewal_create(p_policy_id bigint, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_pol record;
    v_q jsonb;
    v_prop jsonb;
    v_pid bigint;
    v_new jsonb;
BEGIN
    SELECT * INTO v_pol FROM learninsurancedb.policies WHERE id = p_policy_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Policy % not found', p_policy_id USING ERRCODE = 'P0002'; END IF;
    IF v_pol.status <> 'Active' THEN RAISE EXCEPTION 'Only active policies can be renewed' USING ERRCODE = 'P0001'; END IF;
    IF EXISTS (SELECT 1 FROM learninsurancedb.policies WHERE parent_policy_id = p_policy_id) THEN
        RAISE EXCEPTION 'This policy has already been renewed' USING ERRCODE = 'P0001';
    END IF;
    IF v_pol.end_date > CURRENT_DATE + 90 OR v_pol.end_date < CURRENT_DATE - 90 THEN
        RAISE EXCEPTION 'Renewal is possible from 90 days before expiry until 90 days after' USING ERRCODE = 'P0001';
    END IF;

    v_q := learninsurancedb.fn_renewal_quote(p_policy_id);
    v_prop := learninsurancedb.fn_proposal_save(NULL, jsonb_build_object(
        'customerId', v_q->'customerId', 'productId', v_q->'productId', 'startDate', v_q->'newStartDate', 'policyTermYears', v_q->'termYears',
        'agentId', v_q->'agentId', 'remarks', 'Renewal of ' || v_pol.policy_no, 'details', v_q->'details'), p_user);
    v_pid := (v_prop->>'id')::bigint;
    PERFORM learninsurancedb.fn_proposal_submit(v_pid, p_user);
    PERFORM learninsurancedb.fn_proposal_change_status(v_pid, 'Approved', 'Auto-approved renewal', p_user);
    v_new := learninsurancedb.fn_policy_create(v_pid, p_user);

    UPDATE learninsurancedb.policies SET parent_policy_id = p_policy_id WHERE id = (v_new->>'id')::bigint;

    INSERT INTO learninsurancedb.renewals (policy_id, renewal_due_date, status, new_policy_id, previous_premium, renewal_premium, created_by)
    VALUES (p_policy_id, v_pol.end_date + 1, 'Renewed', (v_new->>'id')::bigint, v_pol.total_premium, (v_q->>'renewalPremium')::numeric, COALESCE(p_user, 'system'))
    ON CONFLICT (policy_id) DO UPDATE SET status = 'Renewed', new_policy_id = EXCLUDED.new_policy_id, renewal_premium = EXCLUDED.renewal_premium,
        previous_premium = EXCLUDED.previous_premium, modified_date = now(), modified_by = COALESCE(p_user, 'system');

    RETURN learninsurancedb.fn_policy_get_by_id((v_new->>'id')::bigint);
END
$$;

CREATE OR REPLACE FUNCTION fn_renewal_decline(p_policy_id bigint, p_remarks text, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE v_end date;
BEGIN
    SELECT end_date INTO v_end FROM learninsurancedb.policies WHERE id = p_policy_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Policy % not found', p_policy_id USING ERRCODE = 'P0002'; END IF;
    IF EXISTS (SELECT 1 FROM learninsurancedb.policies WHERE parent_policy_id = p_policy_id) THEN
        RAISE EXCEPTION 'This policy has already been renewed' USING ERRCODE = 'P0001';
    END IF;
    INSERT INTO learninsurancedb.renewals (policy_id, renewal_due_date, status, remarks, created_by)
    VALUES (p_policy_id, v_end + 1, 'Declined', NULLIF(p_remarks, ''), COALESCE(p_user, 'system'))
    ON CONFLICT (policy_id) DO UPDATE SET status = 'Declined', remarks = EXCLUDED.remarks, modified_date = now(), modified_by = COALESCE(p_user, 'system');
    RETURN jsonb_build_object('policyId', p_policy_id, 'status', 'Declined');
END
$$;
