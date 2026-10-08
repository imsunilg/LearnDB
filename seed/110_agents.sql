-- Seed agents (idempotent on license number). Some licences are expired / expiring soon on purpose to exercise the UI.
INSERT INTO learninsurancedb.agents
    (full_name, email, mobile, license_number, license_expiry_date, commission_percent, city, state, status, joined_date, created_by)
SELECT v.full_name, v.email, v.mobile, v.lic, (CURRENT_DATE + v.expiry_days), v.comm, v.city, v.state, v.status, (CURRENT_DATE - v.joined_days), 'seed'
FROM (VALUES
    ('Arun Kumar',       'arun.kumar@agents.example.com',    '9810101001', 'IRDA-AG-100001',  400, 12.5, 'Mumbai',     'Maharashtra', 'Active',     1500),
    ('Bhavna Shah',      'bhavna.shah@agents.example.com',   '9810101002', 'IRDA-AG-100002',  220, 10.0, 'Ahmedabad',  'Gujarat',     'Active',     1100),
    ('Chetan Rao',       'chetan.rao@agents.example.com',    '9810101003', 'IRDA-AG-100003',   18, 11.0, 'Bengaluru',  'Karnataka',   'Active',      900),
    ('Deepa Nair',       'deepa.nair@agents.example.com',    '9810101004', 'IRDA-AG-100004',  -25,  9.5, 'Kochi',       'Kerala',      'Suspended',   800),
    ('Esha Malhotra',    'esha.malhotra@agents.example.com', '9810101005', 'IRDA-AG-100005',  700, 13.0, 'Delhi',       'Delhi',       'Active',      700),
    ('Farhan Qureshi',   'farhan.q@agents.example.com',      '9810101006', 'IRDA-AG-100006',   45, 10.0, 'Hyderabad',   'Telangana',   'Active',      650),
    ('Gauri Kulkarni',   'gauri.k@agents.example.com',       '9810101007', 'IRDA-AG-100007',  310, 12.0, 'Pune',        'Maharashtra', 'Active',      600),
    ('Harsh Vora',       'harsh.vora@agents.example.com',    '9810101008', 'IRDA-AG-100008',    5,  8.5, 'Surat',       'Gujarat',     'Active',      500),
    ('Indu Pillai',      'indu.pillai@agents.example.com',   '9810101009', 'IRDA-AG-100009',  520, 11.5, 'Chennai',     'Tamil Nadu',  'Active',      450),
    ('Jatin Chopra',     'jatin.chopra@agents.example.com',  '9810101010', 'IRDA-AG-100010', -120, 10.0, 'Chandigarh',  'Chandigarh',  'Terminated',  400),
    ('Kiran Bose',       'kiran.bose@agents.example.com',    '9810101011', 'IRDA-AG-100011',  260, 12.5, 'Kolkata',     'West Bengal', 'Active',      300),
    ('Lata Mishra',      'lata.mishra@agents.example.com',   '9810101012', 'IRDA-AG-100012',  150,  9.0, 'Lucknow',     'Uttar Pradesh','Active',     200)
) AS v(full_name, email, mobile, lic, expiry_days, comm, city, state, status, joined_days)
WHERE NOT EXISTS (SELECT 1 FROM learninsurancedb.agents a WHERE upper(a.license_number) = upper(v.lic));
