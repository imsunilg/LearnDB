-- Rating tables for premium calculation (idempotent). Illustrative figures for a learning project, NOT real tariffs.
INSERT INTO learninsurancedb.premium_rates (rate_group, rate_key, rate_value, unit, label, sort_order, created_by)
SELECT v.grp, v.key, v.val, v.unit, v.label, v.ord, 'seed'
FROM (VALUES
    ('GST', 'GST', 18, 'percent', 'GST', 1),

    -- Motor: vehicle age bands (key = max age in years) → loading factor on own-damage premium
    ('MOTOR_AGE_FACTOR', '3',  1.00, 'factor', 'Up to 3 years', 1),
    ('MOTOR_AGE_FACTOR', '5',  1.10, 'factor', '4-5 years', 2),
    ('MOTOR_AGE_FACTOR', '7',  1.20, 'factor', '6-7 years', 3),
    ('MOTOR_AGE_FACTOR', '10', 1.35, 'factor', '8-10 years', 4),
    ('MOTOR_AGE_FACTOR', '99', 1.50, 'factor', 'Over 10 years', 5),

    -- Motor: engine capacity bands per vehicle type (key = TYPE:max cc)
    ('MOTOR_CC_FACTOR', 'CAR:1000', 0.95, 'factor', 'Car up to 1000cc', 1),
    ('MOTOR_CC_FACTOR', 'CAR:1500', 1.00, 'factor', 'Car 1001-1500cc', 2),
    ('MOTOR_CC_FACTOR', 'CAR:99999', 1.12, 'factor', 'Car above 1500cc', 3),
    ('MOTOR_CC_FACTOR', 'TWO_WHEELER:150', 0.95, 'factor', 'Two wheeler up to 150cc', 4),
    ('MOTOR_CC_FACTOR', 'TWO_WHEELER:350', 1.05, 'factor', 'Two wheeler 151-350cc', 5),
    ('MOTOR_CC_FACTOR', 'TWO_WHEELER:99999', 1.25, 'factor', 'Two wheeler above 350cc', 6),
    ('MOTOR_CC_FACTOR', 'COMMERCIAL:99999', 1.00, 'factor', 'Commercial', 7),

    -- Motor: mandatory third-party liability premium per year (key = TYPE:max cc)
    ('MOTOR_TP', 'CAR:1000', 2094, 'flat', 'Car up to 1000cc', 1),
    ('MOTOR_TP', 'CAR:1500', 3416, 'flat', 'Car 1001-1500cc', 2),
    ('MOTOR_TP', 'CAR:99999', 7897, 'flat', 'Car above 1500cc', 3),
    ('MOTOR_TP', 'TWO_WHEELER:75', 538, 'flat', 'Two wheeler up to 75cc', 4),
    ('MOTOR_TP', 'TWO_WHEELER:150', 714, 'flat', 'Two wheeler 76-150cc', 5),
    ('MOTOR_TP', 'TWO_WHEELER:350', 1366, 'flat', 'Two wheeler 151-350cc', 6),
    ('MOTOR_TP', 'TWO_WHEELER:99999', 2804, 'flat', 'Two wheeler above 350cc', 7),
    ('MOTOR_TP', 'COMMERCIAL:99999', 16049, 'flat', 'Goods carrying vehicle', 8),

    -- Motor: allowed No-Claim-Bonus slabs (value = discount %)
    ('MOTOR_NCB', '0', 0, 'percent', 'No NCB', 1), ('MOTOR_NCB', '20', 20, 'percent', '1 claim-free year', 2),
    ('MOTOR_NCB', '25', 25, 'percent', '2 claim-free years', 3), ('MOTOR_NCB', '35', 35, 'percent', '3 claim-free years', 4),
    ('MOTOR_NCB', '45', 45, 'percent', '4 claim-free years', 5), ('MOTOR_NCB', '50', 50, 'percent', '5+ claim-free years', 6),

    -- Motor add-ons (percent of own-damage premium, or flat rupees)
    ('MOTOR_ADDON', 'ZERO_DEP',       12,   'percent', 'Zero depreciation cover', 1),
    ('MOTOR_ADDON', 'ENGINE_PROTECT',  4,   'percent', 'Engine protection', 2),
    ('MOTOR_ADDON', 'CONSUMABLES',     1.5, 'percent', 'Consumables cover', 3),
    ('MOTOR_ADDON', 'RTI',             5,   'percent', 'Return to invoice', 4),
    ('MOTOR_ADDON', 'TYRE_PROTECT',    2,   'percent', 'Tyre protection', 5),
    ('MOTOR_ADDON', 'RSA',           399,   'flat',    '24x7 roadside assistance', 6),
    ('MOTOR_ADDON', 'PASSENGER_COVER', 330, 'flat',    'Passenger personal accident', 7),

    -- Motor: IDV depreciation by vehicle age (key = max age in years, value = % depreciation on ex-showroom price)
    ('MOTOR_DEPRECIATION', '0',  5, 'percent', 'Under 6 months', 1), ('MOTOR_DEPRECIATION', '1', 15, 'percent', '6 months - 1 year', 2),
    ('MOTOR_DEPRECIATION', '2', 20, 'percent', '1-2 years', 3),      ('MOTOR_DEPRECIATION', '3', 30, 'percent', '2-3 years', 4),
    ('MOTOR_DEPRECIATION', '4', 40, 'percent', '3-4 years', 5),      ('MOTOR_DEPRECIATION', '5', 50, 'percent', '4-5 years', 6),
    ('MOTOR_DEPRECIATION', '99', 60, 'percent', 'Over 5 years', 7)
) AS v(grp, key, val, unit, label, ord)
ON CONFLICT (rate_group, rate_key) DO NOTHING;
