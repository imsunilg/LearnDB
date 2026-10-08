-- Day 28: premium calculation. ONE source of truth: the API and the UI only call fn_premium_calculate.
-- Every function returns the same JSON envelope:
-- { productType, sumInsured, basePremium, additions:[{code,name,amount}], discounts:[{code,name,amount}],
--   netPremium, gstPercent, gstAmount, totalPremium, extras:{...} }
SET search_path = learninsurancedb, public;

-- Value of a rate row (NULL when missing)
CREATE OR REPLACE FUNCTION fn_rate(p_group text, p_key text) RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT rate_value FROM learninsurancedb.premium_rates WHERE rate_group = p_group AND rate_key = p_key AND is_active;
$$;

-- First band whose numeric upper bound (key) is >= p_value, e.g. age 4 → band '5'. Keys are numeric strings.
CREATE OR REPLACE FUNCTION fn_rate_band(p_group text, p_value numeric) RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT x.rate_value FROM (
        SELECT rate_value, CASE WHEN rate_key ~ '^[0-9.]+$' THEN rate_key::numeric END AS k
        FROM learninsurancedb.premium_rates WHERE rate_group = p_group AND is_active
    ) x WHERE x.k >= p_value ORDER BY x.k LIMIT 1;
$$;

-- Band lookup for keys like 'CAR:1500' (type : max value)
CREATE OR REPLACE FUNCTION fn_rate_typed_band(p_group text, p_type text, p_value numeric) RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT x.rate_value FROM (
        SELECT rate_value, split_part(rate_key, ':', 1) AS t,
               CASE WHEN rate_key ~ '^[A-Z_]+:[0-9]+$' THEN split_part(rate_key, ':', 2)::numeric END AS k
        FROM learninsurancedb.premium_rates WHERE rate_group = p_group AND is_active
    ) x WHERE x.t = p_type AND x.k >= p_value ORDER BY x.k LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_money(p numeric) RETURNS numeric LANGUAGE sql IMMUTABLE AS $$ SELECT round(p, 2); $$;

-- Rates of a group for the UI (add-on catalogue, NCB slabs...)
CREATE OR REPLACE FUNCTION fn_rates_get(p_group text) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object('key', rate_key, 'value', rate_value, 'unit', unit, 'label', label) ORDER BY sort_order), '[]'::jsonb)
    FROM learninsurancedb.premium_rates WHERE rate_group = upper(p_group) AND is_active;
$$;

-- Suggested IDV (insured declared value) for a motor vehicle from the model's ex-showroom price and the vehicle age.
CREATE OR REPLACE FUNCTION fn_motor_idv_suggest(p_model text, p_manufacture_year int) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_price numeric;
    v_age numeric := GREATEST(extract(year FROM now())::int - p_manufacture_year, 0);
    v_dep numeric;
    v_idv numeric;
BEGIN
    SELECT (meta->>'exShowroomPrice')::numeric INTO v_price
    FROM learninsurancedb.master_data WHERE type = 'VEHICLE_MODEL' AND lower(name) = lower(p_model) AND is_active LIMIT 1;
    IF v_price IS NULL THEN
        RETURN NULL;
    END IF;
    v_dep := COALESCE(learninsurancedb.fn_rate_band('MOTOR_DEPRECIATION', v_age), 60);
    v_idv := round(v_price * (1 - v_dep / 100), -2);
    RETURN jsonb_build_object('exShowroomPrice', v_price, 'depreciationPercent', v_dep, 'vehicleAge', v_age,
                              'suggestedIdv', v_idv, 'minIdv', round(v_idv * 0.90, -2), 'maxIdv', round(v_idv * 1.10, -2));
END
$$;

-- ---------------------------------------------------------------------------------------------------------
-- MOTOR: details = { vehicle:{vehicleType, manufactureYear, cubicCapacity}, insurance:{idv, ncbPercent, addOns:[...], policyTermYears} }
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_premium_motor(p_base_rate numeric, p_min numeric, p_max numeric, p_details jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_type   text    := p_details#>>'{vehicle,vehicleType}';
    v_year   int     := NULLIF(p_details#>>'{vehicle,manufactureYear}', '')::int;
    v_cc     numeric := NULLIF(p_details#>>'{vehicle,cubicCapacity}', '')::numeric;
    v_idv    numeric := NULLIF(p_details#>>'{insurance,idv}', '')::numeric;
    v_ncb    numeric := COALESCE(NULLIF(p_details#>>'{insurance,ncbPercent}', '')::numeric, 0);
    v_term   int     := COALESCE(NULLIF(p_details#>>'{insurance,policyTermYears}', '')::int, 1);
    v_age    numeric;
    v_age_f  numeric;
    v_cc_f   numeric;
    v_od     numeric;
    v_tp     numeric;
    v_gst    numeric := COALESCE(learninsurancedb.fn_rate('GST', 'GST'), 18);
    v_adds   jsonb := '[]'::jsonb;
    v_disc   jsonb := '[]'::jsonb;
    v_add_total numeric := 0;
    v_ncb_amt numeric := 0;
    v_net numeric;
    v_gst_amt numeric;
    v_code text;
    v_rate record;
    v_amt numeric;
BEGIN
    IF v_type IS NULL OR v_year IS NULL OR v_cc IS NULL OR v_idv IS NULL THEN
        RAISE EXCEPTION 'Vehicle type, manufacture year, engine capacity and IDV are required to calculate the premium' USING ERRCODE = 'P0001';
    END IF;
    IF v_idv < p_min OR v_idv > p_max THEN
        RAISE EXCEPTION 'IDV must be between % and % for this plan', p_min, p_max USING ERRCODE = 'P0001';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM learninsurancedb.premium_rates WHERE rate_group = 'MOTOR_NCB' AND rate_value = v_ncb) THEN
        RAISE EXCEPTION 'Invalid No-Claim-Bonus percentage %', v_ncb USING ERRCODE = 'P0001';
    END IF;

    v_age   := GREATEST(extract(year FROM now())::int - v_year, 0);
    v_age_f := COALESCE(learninsurancedb.fn_rate_band('MOTOR_AGE_FACTOR', v_age), 1.5);
    v_cc_f  := COALESCE(learninsurancedb.fn_rate_typed_band('MOTOR_CC_FACTOR', v_type, v_cc), 1);
    v_tp    := COALESCE(learninsurancedb.fn_rate_typed_band('MOTOR_TP', v_type, v_cc), 0);

    -- Own damage premium = IDV × plan rate × age factor × engine factor
    v_od := learninsurancedb.fn_money(v_idv * p_base_rate / 100 * v_age_f * v_cc_f);

    v_adds := v_adds || jsonb_build_object('code', 'TP', 'name', 'Third-party liability (mandatory)', 'amount', v_tp);
    v_add_total := v_tp;

    FOR v_code IN SELECT jsonb_array_elements_text(COALESCE(p_details#>'{insurance,addOns}', '[]'::jsonb)) LOOP
        SELECT rate_value, unit, label INTO v_rate FROM learninsurancedb.premium_rates WHERE rate_group = 'MOTOR_ADDON' AND rate_key = v_code AND is_active;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Unknown add-on %', v_code USING ERRCODE = 'P0001';
        END IF;
        v_amt := learninsurancedb.fn_money(CASE WHEN v_rate.unit = 'percent' THEN v_od * v_rate.rate_value / 100 ELSE v_rate.rate_value END);
        v_adds := v_adds || jsonb_build_object('code', v_code, 'name', v_rate.label, 'amount', v_amt);
        v_add_total := v_add_total + v_amt;
    END LOOP;

    IF v_ncb > 0 THEN
        v_ncb_amt := learninsurancedb.fn_money(v_od * v_ncb / 100);
        v_disc := v_disc || jsonb_build_object('code', 'NCB', 'name', 'No Claim Bonus (' || v_ncb::int || '%)', 'amount', v_ncb_amt);
    END IF;

    v_net     := learninsurancedb.fn_money((v_od + v_add_total - v_ncb_amt) * v_term);
    v_gst_amt := learninsurancedb.fn_money(v_net * v_gst / 100);

    RETURN jsonb_build_object(
        'productType', 'MOTOR', 'sumInsured', v_idv, 'basePremium', v_od,
        'additions', v_adds, 'discounts', v_disc,
        'netPremium', v_net, 'gstPercent', v_gst, 'gstAmount', v_gst_amt, 'totalPremium', v_net + v_gst_amt,
        'extras', jsonb_build_object('vehicleAge', v_age, 'ageFactor', v_age_f, 'engineFactor', v_cc_f, 'termYears', v_term, 'thirdParty', v_tp));
END
$$;

-- ---------------------------------------------------------------------------------------------------------
-- Dispatcher: validates the product and routes to the product-line calculator.
-- Health / Home / Travel calculators (fn_premium_health / _home / _travel) are added on Days 33-35.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_premium_calculate(p_product_id bigint, p_details jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_prod record;
    v_result jsonb;
BEGIN
    SELECT p.base_rate, p.min_sum_insured, p.max_sum_insured, p.effective_from, p.effective_to, p.is_active, pt.code AS type_code
    INTO v_prod
    FROM learninsurancedb.insurance_products p JOIN learninsurancedb.insurance_product_types pt ON pt.id = p.product_type_id
    WHERE p.id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % not found', p_product_id USING ERRCODE = 'P0002';
    END IF;
    IF NOT v_prod.is_active OR v_prod.effective_from > CURRENT_DATE OR (v_prod.effective_to IS NOT NULL AND v_prod.effective_to < CURRENT_DATE) THEN
        RAISE EXCEPTION 'This product is not currently on sale' USING ERRCODE = 'P0001';
    END IF;

    -- Dispatch by naming convention: fn_premium_<producttype>(base_rate, min, max, details).
    -- Adding a product line = adding one function; no change here.
    BEGIN
        EXECUTE format('SELECT learninsurancedb.fn_premium_%s($1, $2, $3, $4)', lower(v_prod.type_code))
            INTO v_result USING v_prod.base_rate, v_prod.min_sum_insured, v_prod.max_sum_insured, p_details;
        RETURN v_result;
    EXCEPTION WHEN undefined_function THEN
        RAISE EXCEPTION 'Premium calculation for % is not available yet', v_prod.type_code USING ERRCODE = 'P0001';
    END;
END
$$;

-- Calculate and keep a record of the quote
CREATE OR REPLACE FUNCTION fn_premium_calculate_and_save(p_product_id bigint, p_customer_id bigint, p_details jsonb, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_breakup jsonb := learninsurancedb.fn_premium_calculate(p_product_id, p_details);
BEGIN
    INSERT INTO learninsurancedb.premium_calculations (product_id, customer_id, product_type, input, breakup, sum_insured, total_premium, created_by)
    VALUES (p_product_id, p_customer_id, v_breakup->>'productType', p_details, v_breakup, (v_breakup->>'sumInsured')::numeric, (v_breakup->>'totalPremium')::numeric, COALESCE(p_user, 'system'));
    RETURN v_breakup;
END
$$;
