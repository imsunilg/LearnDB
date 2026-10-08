-- Day 27: vehicle upsert used by motor proposals (list/get/delete are generated: functions/generated/vehicle.sql)
SET search_path = learninsurancedb, public;

-- Insert or update a vehicle by registration number. A vehicle already registered to ANOTHER customer is rejected.
CREATE OR REPLACE FUNCTION fn_vehicle_upsert(p_data jsonb, p_user text DEFAULT 'system') RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
    v_reg text := upper(regexp_replace(COALESCE(p_data->>'registrationNo', ''), '[\s-]', '', 'g'));
    v_customer bigint := (p_data->>'customerId')::bigint;
    v_existing record;
    v_id bigint;
BEGIN
    IF v_reg = '' THEN
        RAISE EXCEPTION 'Registration number is required' USING ERRCODE = 'P0001';
    END IF;

    SELECT id, customer_id INTO v_existing FROM learninsurancedb.vehicles WHERE registration_no = v_reg;

    IF FOUND AND v_existing.customer_id <> v_customer THEN
        RAISE EXCEPTION 'Vehicle % is already registered to another customer', v_reg USING ERRCODE = 'P0001';
    END IF;

    IF FOUND THEN
        UPDATE learninsurancedb.vehicles SET
            vehicle_type = p_data->>'vehicleType', make = p_data->>'make', model = p_data->>'model',
            variant = NULLIF(p_data->>'variant', ''), fuel_type = p_data->>'fuelType',
            manufacture_year = (p_data->>'manufactureYear')::int,
            registration_date = NULLIF(p_data->>'registrationDate', '')::date,
            engine_no = NULLIF(p_data->>'engineNo', ''), chassis_no = NULLIF(p_data->>'chassisNo', ''),
            cubic_capacity = (p_data->>'cubicCapacity')::int,
            seating_capacity = COALESCE(NULLIF(p_data->>'seatingCapacity', '')::int, 5),
            is_active = TRUE, modified_date = now(), modified_by = COALESCE(p_user, 'system')
        WHERE id = v_existing.id
        RETURNING id INTO v_id;
    ELSE
        INSERT INTO learninsurancedb.vehicles
            (registration_no, customer_id, vehicle_type, make, model, variant, fuel_type, manufacture_year, registration_date,
             engine_no, chassis_no, cubic_capacity, seating_capacity, created_by)
        VALUES (v_reg, v_customer, p_data->>'vehicleType', p_data->>'make', p_data->>'model', NULLIF(p_data->>'variant', ''),
                p_data->>'fuelType', (p_data->>'manufactureYear')::int, NULLIF(p_data->>'registrationDate', '')::date,
                NULLIF(p_data->>'engineNo', ''), NULLIF(p_data->>'chassisNo', ''), (p_data->>'cubicCapacity')::int,
                COALESCE(NULLIF(p_data->>'seatingCapacity', '')::int, 5), COALESCE(p_user, 'system'))
        RETURNING id INTO v_id;
    END IF;

    RETURN learninsurancedb.fn_vehicle_get_by_id(v_id);
END
$$;
