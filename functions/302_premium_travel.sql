-- Day 34: TRAVEL premium.
-- details = { trip:{destinationZone,startDate,endDate}, travellers:[{dateOfBirth,...}], cover:{sumInsured,adventureSports} }
SET search_path = learninsurancedb, public;

CREATE OR REPLACE FUNCTION fn_premium_travel(p_base_rate numeric, p_min numeric, p_max numeric, p_details jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_zone     text := p_details#>>'{trip,destinationZone}';
    v_start    date := NULLIF(p_details#>>'{trip,startDate}', '')::date;
    v_end      date := NULLIF(p_details#>>'{trip,endDate}', '')::date;
    v_si       numeric := NULLIF(p_details#>>'{cover,sumInsured}', '')::numeric;
    v_adventure boolean := COALESCE((p_details#>>'{cover,adventureSports}')::boolean, FALSE);
    v_days     int;
    v_zone_f   numeric;
    v_dur_f    numeric;
    v_count    int := 0;
    v_base     numeric := 0;
    v_trav     record;
    v_age_f    numeric;
    v_age      int;
    v_one      numeric;
    v_adds     jsonb := '[]'::jsonb;
    v_disc     jsonb := '[]'::jsonb;
    v_add_total numeric := 0;
    v_disc_total numeric := 0;
    v_amt      numeric;
    v_net      numeric;
    v_gst      numeric := COALESCE(learninsurancedb.fn_rate('GST', 'GST'), 18);
    v_gst_amt  numeric;
    v_ages     jsonb := '[]'::jsonb;
BEGIN
    IF v_zone IS NULL OR v_start IS NULL OR v_end IS NULL OR v_si IS NULL THEN
        RAISE EXCEPTION 'Destination, travel dates and cover amount are required to calculate the premium' USING ERRCODE = 'P0001';
    END IF;
    IF v_end < v_start THEN
        RAISE EXCEPTION 'The return date cannot be before the departure date' USING ERRCODE = 'P0001';
    END IF;
    v_days := (v_end - v_start) + 1;
    IF v_days > 180 THEN
        RAISE EXCEPTION 'A trip can be covered for at most 180 days' USING ERRCODE = 'P0001';
    END IF;
    IF v_si < p_min OR v_si > p_max THEN
        RAISE EXCEPTION 'Cover per traveller must be between % and % for this plan', p_min, p_max USING ERRCODE = 'P0001';
    END IF;

    v_zone_f := learninsurancedb.fn_rate('TRAVEL_ZONE_FACTOR', v_zone);
    IF v_zone_f IS NULL THEN
        RAISE EXCEPTION 'Unknown destination %', v_zone USING ERRCODE = 'P0001';
    END IF;
    v_dur_f := COALESCE(learninsurancedb.fn_rate_band('TRAVEL_DURATION_FACTOR', v_days), 0.6);

    FOR v_trav IN SELECT value FROM jsonb_array_elements(COALESCE(p_details->'travellers', '[]'::jsonb)) LOOP
        v_count := v_count + 1;
        v_age := extract(year FROM age(v_start, (v_trav.value->>'dateOfBirth')::date))::int;
        v_age_f := COALESCE(learninsurancedb.fn_rate_band('TRAVEL_AGE_FACTOR', v_age), 3.5);
        -- cover x annual rate x share of the year for this trip length x destination x age loading
        v_one := learninsurancedb.fn_money(v_si * p_base_rate / 100 * v_dur_f * v_zone_f * v_age_f);
        v_base := v_base + v_one;
        v_ages := v_ages || jsonb_build_object('age', v_age, 'ageFactor', v_age_f, 'premium', v_one);
    END LOOP;

    IF v_count = 0 THEN
        RAISE EXCEPTION 'Add at least one traveller' USING ERRCODE = 'P0001';
    END IF;

    IF v_adventure THEN
        v_amt := learninsurancedb.fn_money(v_base * learninsurancedb.fn_rate('TRAVEL_ADDON', 'ADVENTURE') / 100);
        v_adds := v_adds || jsonb_build_object('code', 'ADVENTURE', 'name', 'Adventure sports cover', 'amount', v_amt);
        v_add_total := v_amt;
    END IF;
    IF v_count >= 3 THEN
        v_amt := learninsurancedb.fn_money(v_base * learninsurancedb.fn_rate('TRAVEL_DISCOUNT', 'GROUP') / 100);
        v_disc := v_disc || jsonb_build_object('code', 'GROUP', 'name', 'Group discount (' || v_count || ' travellers)', 'amount', v_amt);
        v_disc_total := v_amt;
    END IF;

    v_net     := learninsurancedb.fn_money(v_base + v_add_total - v_disc_total);
    v_gst_amt := learninsurancedb.fn_money(v_net * v_gst / 100);

    RETURN jsonb_build_object(
        'productType', 'TRAVEL', 'sumInsured', v_si * v_count, 'basePremium', v_base, 'additions', v_adds, 'discounts', v_disc,
        'netPremium', v_net, 'gstPercent', v_gst, 'gstAmount', v_gst_amt, 'totalPremium', v_net + v_gst_amt,
        'extras', jsonb_build_object('tripDays', v_days, 'zoneFactor', v_zone_f, 'durationFactor', v_dur_f, 'travellers', v_count,
                                     'coverPerTraveller', v_si, 'perTraveller', v_ages));
END
$$;
