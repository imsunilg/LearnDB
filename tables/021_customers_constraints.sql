-- Day 14: check constraints aligned with FluentValidation (API) and Zod (React). Idempotent.
SET search_path = learninsurancedb, public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_customers_mobile') THEN
        ALTER TABLE customers ADD CONSTRAINT ck_customers_mobile CHECK (mobile ~ '^[6-9][0-9]{9}$');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_customers_pan') THEN
        ALTER TABLE customers ADD CONSTRAINT ck_customers_pan CHECK (pan_number IS NULL OR pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_customers_pincode') THEN
        ALTER TABLE customers ADD CONSTRAINT ck_customers_pincode CHECK (pincode IS NULL OR pincode ~ '^[0-9]{6}$');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_customers_dob') THEN
        ALTER TABLE customers ADD CONSTRAINT ck_customers_dob CHECK (date_of_birth < CURRENT_DATE);
    END IF;
END $$;
