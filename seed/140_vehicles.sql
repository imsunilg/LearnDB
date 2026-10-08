-- Seed vehicles for a few customers (idempotent on registration number)
INSERT INTO learninsurancedb.vehicles
    (registration_no, customer_id, vehicle_type, make, model, variant, fuel_type, manufacture_year, registration_date, engine_no, chassis_no, cubic_capacity, seating_capacity, created_by)
SELECT v.reg, c.id, v.vtype, v.make, v.model, v.variant, v.fuel, v.year, make_date(v.year, 6, 15), v.engine, v.chassis, v.cc, v.seats, 'seed'
FROM (VALUES
    ('MH12AB1234', 'aarav.sharma@example.com',   'CAR',         'Maruti Suzuki', 'Swift',         'VXi',      'Petrol',   2021, 'K12MN1234567', 'MA3FJEB1S00123456', 1197, 5),
    ('GJ01CD5678', 'diya.patel@example.com',     'CAR',         'Hyundai',       'Creta',         'SX',       'Diesel',   2022, 'D4FB7654321',  'MALC381CLMM123456', 1493, 5),
    ('MH14EF9012', 'rohan.mehta@example.com',    'TWO_WHEELER', 'Honda',         'Activa',        '6G',       'Petrol',   2020, 'JF50E1234567', 'ME4JF501LKT123456',  109, 2),
    ('TN09GH3456', 'ananya.iyer@example.com',    'CAR',         'Tata Motors',   'Nexon',         'XZ+',      'Electric', 2023, 'EV00123456',   'MAT628456PRA12345', 1000, 5),
    ('RJ14JK7890', 'vikram.singh@example.com',   'CAR',         'Mahindra',      'Thar',          'LX',       'Diesel',   2019, 'MHA2200123',   'MA1TA2XXXK2A12345', 2184, 4),
    ('DL3CAB1122', 'neha.kapoor@example.com',    'TWO_WHEELER', 'Royal Enfield', 'Classic 350',   'Chrome',   'Petrol',   2021, 'RE3501234567', 'ME3U3S5C7MA123456',  349, 2),
    ('KL07LM3344', 'karthik.nair@example.com',   'CAR',         'Toyota',        'Innova Crysta', 'GX',       'Diesel',   2018, '2GDF123456',   'MBJ11AA2301123456', 2393, 7),
    ('WB02NP5566', 'ishita.das@example.com',     'TWO_WHEELER', 'Bajaj',         'Pulsar 150',    'Neon',     'Petrol',   2022, 'DKZB123456',   'MD2A11CZ0NWA12345',  149, 2),
    ('TS09QR7788', 'arjun.reddy@example.com',    'CAR',         'Honda',         'City',          'ZX',       'Petrol',   2020, 'L15B1234567',  'MAKGM6760LN123456', 1498, 5),
    ('MH12ST9900', 'meera.joshi@example.com',    'COMMERCIAL',  'Tata Motors',   'Ace (goods carrier)', 'Gold', 'Diesel',  2019, 'TCIC123456',   'MAT445123KPA12345',  700, 2)
) AS v(reg, email, vtype, make, model, variant, fuel, year, engine, chassis, cc, seats)
JOIN learninsurancedb.customers c ON c.email = v.email
WHERE NOT EXISTS (SELECT 1 FROM learninsurancedb.vehicles x WHERE x.registration_no = v.reg);
