-- Day 35: HEALTH premium.
-- details = { cover:{planType:'INDIVIDUAL'|'FLOATER', sumInsured, policyTermYears}, members:[{dateOfBirth, preExisting, conditions:[..]}] }
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION fn_premium_health(p_base_rate numeric, p_min numeric, p_max numeric, p_details jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_plan   text := COALESCE(p_details#>>'{cover,planType}', 'INDIVIDUAL');
    v_si     numeric := NULLIF(p_details#>>'{cover,sumInsured}', '')::numeric;
    v_term   int := COALESCE(NULLIF(p_details->>'policyTermYears', '')::int, 1);
    v_mem    record;
    v_count  int := 0;
    v_flagged int := 0;
    v_age    int;
    v_age_f  numeric;
    v_eldest_f numeric := 0;
    v_member_prem numeric;
    v_base   numeric := 0;
    v_lines  jsonb := '[]'::jsonb;
    v_adds   jsonb := '[]'::jsonb;
    v_disc   jsonb := '[]'::jsonb;
    v_add_total numeric := 0;
    v_disc_total numeric := 0;
    v_amt    numeric;
    v_pre_rate numeric := COALESCE(learninsurancedb.fn_rate('HEALTH_LOADING', 'PRE_EXISTING'), 15);
    v_net    numeric;
    v_gst    numeric := COALESCE(learninsurancedb.fn_rate('GST', 'GST'), 18);
    v_gst_amt numeric;
    v_sum_insured numeric;
BEGIN
    IF v_si IS NULL THEN
        RAISE EXCEPTION 'Choose a sum insured' USING ERRCODE = 'P0001';
    END IF;
    IF v_plan NOT IN ('INDIVIDUAL', 'FLOATER') THEN
        RAISE EXCEPTION 'Unknown plan type %', v_plan USING ERRCODE = 'P0001';
    END IF;
    IF v_si < p_min OR v_si > p_max THEN
        RAISE EXCEPTION 'Sum insured must be between % and % for this plan', p_min, p_max USING ERRCODE = 'P0001';
    END IF;

    FOR v_mem IN SELECT value FROM jsonb_array_elements(COALESCE(p_details->'members', '[]'::jsonb)) LOOP
        v_count := v_count + 1;
        v_age := extract(year FROM age((v_mem.value->>'dateOfBirth')::date))::int;
        v_age_f := COALESCE(learninsurancedb.fn_rate_band('HEALTH_AGE_FACTOR', v_age), 4.5);
        v_eldest_f := GREATEST(v_eldest_f, v_age_f);
        IF COALESCE((v_mem.value->>'preExisting')::boolean, FALSE) THEN
            v_flagged := v_flagged + 1;
        END IF;

        IF v_plan = 'INDIVIDUAL' THEN
            -- every member has own cover and own price
            v_member_prem := learninsurancedb.fn_money(v_si * p_base_rate / 100 * v_age_f);
            v_base := v_base + v_member_prem;
            v_lines := v_lines || jsonb_build_object('name', COALESCE(v_mem.value->>'name', 'Member ' || v_count), 'age', v_age, 'ageFactor', v_age_f, 'premium', v_member_prem);
            IF COALESCE((v_mem.value->>'preExisting')::boolean, FALSE) THEN
                v_amt := learninsurancedb.fn_money(v_member_prem * v_pre_rate / 100);
                v_adds := v_adds || jsonb_build_object('code', 'PRE_' || v_count, 'name', 'Pre-existing loading - ' || COALESCE(v_mem.value->>'name', 'Member ' || v_count), 'amount', v_amt);
                v_add_total := v_add_total + v_amt;
            END IF;
        ELSE
            v_lines := v_lines || jsonb_build_object('name', COALESCE(v_mem.value->>'name', 'Member ' || v_count), 'age', v_age, 'ageFactor', v_age_f);
        END IF;
    END LOOP;

    IF v_count = 0 THEN
        RAISE EXCEPTION 'Add at least one member' USING ERRCODE = 'P0001';
    END IF;

    IF v_plan = 'FLOATER' THEN
        IF v_count < 2 THEN
            RAISE EXCEPTION 'A family floater needs at least two members' USING ERRCODE = 'P0001';
        END IF;
        -- one shared cover: priced on the eldest member, plus a loading for each additional member
        v_base := learninsurancedb.fn_money(v_si * p_base_rate / 100 * v_eldest_f);
        v_amt := learninsurancedb.fn_money(v_base * COALESCE(learninsurancedb.fn_rate('HEALTH_LOADING', 'FLOATER_MEMBER'), 20) / 100 * (v_count - 1));
        v_adds := v_adds || jsonb_build_object('code', 'FLOATER_MEMBERS', 'name', 'Additional members (' || (v_count - 1) || ')', 'amount', v_amt);
        v_add_total := v_add_total + v_amt;
        IF v_flagged > 0 THEN
            v_amt := learninsurancedb.fn_money(v_base * v_pre_rate / 100);
            v_adds := v_adds || jsonb_build_object('code', 'PRE_EXISTING', 'name', 'Pre-existing condition loading', 'amount', v_amt);
            v_add_total := v_add_total + v_amt;
        END IF;
        v_sum_insured := v_si;
    ELSE
        v_sum_insured := v_si * v_count;
    END IF;

    IF v_term > 1 THEN
        v_amt := COALESCE(learninsurancedb.fn_rate('HEALTH_TERM_DISCOUNT', v_term::text), 0);
        IF v_amt > 0 THEN
            v_amt := learninsurancedb.fn_money((v_base + v_add_total) * v_amt / 100);
            v_disc := v_disc || jsonb_build_object('code', 'TERM', 'name', v_term || '-year term discount', 'amount', v_amt);
            v_disc_total := v_amt;
        END IF;
    END IF;

    v_net     := learninsurancedb.fn_money((v_base + v_add_total - v_disc_total) * v_term);
    v_gst_amt := learninsurancedb.fn_money(v_net * v_gst / 100);

    RETURN jsonb_build_object(
        'productType', 'HEALTH', 'sumInsured', v_sum_insured, 'basePremium', v_base, 'additions', v_adds, 'discounts', v_disc,
        'netPremium', v_net, 'gstPercent', v_gst, 'gstAmount', v_gst_amt, 'totalPremium', v_net + v_gst_amt,
        'extras', jsonb_build_object('planType', v_plan, 'members', v_count, 'termYears', v_term, 'perMember', v_lines));
END
$$;
