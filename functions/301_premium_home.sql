-- Day 33: HOME premium. details = { property:{type,constructionType,ageYears,ownership}, cover:{buildingValue,contentsCover,contentsValue,burglaryCover} }
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION fn_premium_home(p_base_rate numeric, p_min numeric, p_max numeric, p_details jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_building  numeric := NULLIF(p_details#>>'{cover,buildingValue}', '')::numeric;
    v_contents_on boolean := COALESCE((p_details#>>'{cover,contentsCover}')::boolean, FALSE);
    v_contents  numeric := CASE WHEN COALESCE((p_details#>>'{cover,contentsCover}')::boolean, FALSE)
                                THEN COALESCE(NULLIF(p_details#>>'{cover,contentsValue}', '')::numeric, 0) ELSE 0 END;
    v_burglary  boolean := COALESCE((p_details#>>'{cover,burglaryCover}')::boolean, FALSE);
    v_age       numeric := COALESCE(NULLIF(p_details#>>'{property,ageYears}', '')::numeric, 0);
    v_type      text := p_details#>>'{property,type}';
    v_constr    text := p_details#>>'{property,constructionType}';
    v_owner     text := COALESCE(p_details#>>'{property,ownership}', 'OWNER');
    v_si        numeric;
    v_age_f     numeric;
    v_type_f    numeric;
    v_constr_f  numeric;
    v_base      numeric;
    v_adds      jsonb := '[]'::jsonb;
    v_disc      jsonb := '[]'::jsonb;
    v_add_total numeric := 0;
    v_disc_total numeric := 0;
    v_amt       numeric;
    v_net       numeric;
    v_gst       numeric := COALESCE(learninsurancedb.fn_rate('GST', 'GST'), 18);
    v_gst_amt   numeric;
BEGIN
    IF v_building IS NULL OR v_building <= 0 OR v_type IS NULL OR v_constr IS NULL THEN
        RAISE EXCEPTION 'Property type, construction type and building value are required to calculate the premium' USING ERRCODE = 'P0001';
    END IF;
    IF v_contents_on AND v_contents <= 0 THEN
        RAISE EXCEPTION 'Enter the value of the household contents' USING ERRCODE = 'P0001';
    END IF;

    v_si := v_building + v_contents;
    IF v_si < p_min OR v_si > p_max THEN
        RAISE EXCEPTION 'Total sum insured must be between % and % for this plan', p_min, p_max USING ERRCODE = 'P0001';
    END IF;

    v_age_f    := COALESCE(learninsurancedb.fn_rate_band('HOME_AGE_FACTOR', v_age), 1.5);
    v_type_f   := COALESCE(learninsurancedb.fn_rate('HOME_TYPE_FACTOR', v_type), 1);
    v_constr_f := COALESCE(learninsurancedb.fn_rate('HOME_CONSTRUCTION_FACTOR', v_constr), 1);

    v_base := learninsurancedb.fn_money(v_building * p_base_rate / 100 * v_age_f * v_type_f * v_constr_f);

    IF v_contents > 0 THEN
        v_amt := learninsurancedb.fn_money(v_contents * learninsurancedb.fn_rate('HOME_ADDON', 'CONTENTS') / 100);
        v_adds := v_adds || jsonb_build_object('code', 'CONTENTS', 'name', 'Household contents cover', 'amount', v_amt);
        v_add_total := v_add_total + v_amt;
    END IF;
    IF v_burglary THEN
        v_amt := learninsurancedb.fn_money(v_si * learninsurancedb.fn_rate('HOME_ADDON', 'BURGLARY') / 100);
        v_adds := v_adds || jsonb_build_object('code', 'BURGLARY', 'name', 'Burglary & theft cover', 'amount', v_amt);
        v_add_total := v_add_total + v_amt;
    END IF;
    IF v_owner = 'TENANT' THEN
        v_amt := learninsurancedb.fn_money(v_base * learninsurancedb.fn_rate('HOME_DISCOUNT', 'TENANT') / 100);
        v_disc := v_disc || jsonb_build_object('code', 'TENANT', 'name', 'Tenant discount', 'amount', v_amt);
        v_disc_total := v_disc_total + v_amt;
    END IF;

    v_net     := learninsurancedb.fn_money(v_base + v_add_total - v_disc_total);
    v_gst_amt := learninsurancedb.fn_money(v_net * v_gst / 100);

    RETURN jsonb_build_object(
        'productType', 'HOME', 'sumInsured', v_si, 'basePremium', v_base, 'additions', v_adds, 'discounts', v_disc,
        'netPremium', v_net, 'gstPercent', v_gst, 'gstAmount', v_gst_amt, 'totalPremium', v_net + v_gst_amt,
        'extras', jsonb_build_object('ageFactor', v_age_f, 'propertyTypeFactor', v_type_f, 'constructionFactor', v_constr_f,
                                     'buildingValue', v_building, 'contentsValue', v_contents));
END
$$;
