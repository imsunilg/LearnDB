-- Seed brokers and attach some agents to them (idempotent).
INSERT INTO learninsurancedb.brokers
    (firm_name, contact_person, email, mobile, irdai_registration_no, registration_expiry_date, gst_number, address_line, city, state, commission_percent, created_by)
SELECT v.firm, v.person, v.email, v.mobile, v.irdai, CURRENT_DATE + v.expiry_days, v.gst, v.addr, v.city, v.state, v.comm, 'seed'
FROM (VALUES
    ('SecureLife Insurance Brokers',  'Rajesh Menon',   'contact@securelife.example.com',  '9820202001', 'IRDAI/DB/100/2020', 700, '27AABCS1234A1Z5', 'Nariman Point',    'Mumbai',    'Maharashtra', 15.0),
    ('Shield Advisory Services',      'Sunita Rao',     'hello@shieldadvisory.example.com','9820202002', 'IRDAI/DB/101/2019', 120, '29AABCS2345B1Z6', 'MG Road',          'Bengaluru', 'Karnataka',   14.0),
    ('Trusted Cover Brokers',         'Anil Kapoor',    'info@trustedcover.example.com',   '9820202003', 'IRDAI/DB/102/2021', 900, '07AABCT3456C1Z7', 'Connaught Place',  'Delhi',     'Delhi',       16.0),
    ('Gujarat Risk Solutions',        'Hetal Parikh',   'team@gujaratrisk.example.com',    '9820202004', 'IRDAI/DB/103/2018',  40, '24AABCG4567D1Z8', 'Ashram Road',      'Ahmedabad', 'Gujarat',     13.5),
    ('Southern Assurance Partners',   'Lakshmi Iyer',   'desk@southernassure.example.com', '9820202005', 'IRDAI/DB/104/2022', 640, '33AABCS5678E1Z9', 'Anna Salai',       'Chennai',   'Tamil Nadu',  15.5),
    ('Eastern Policy Hub',            'Subrata Ghosh',  'support@easternhub.example.com',  '9820202006', 'IRDAI/DB/105/2017', -60, '19AABCE6789F1ZA', 'Park Street',      'Kolkata',   'West Bengal', 12.0)
) AS v(firm, person, email, mobile, irdai, expiry_days, gst, addr, city, state, comm)
WHERE NOT EXISTS (SELECT 1 FROM learninsurancedb.brokers b WHERE upper(b.irdai_registration_no) = upper(v.irdai));

-- Link agents → brokers (only agents that are not linked yet)
UPDATE learninsurancedb.agents a SET broker_id = b.id
FROM (VALUES ('IRDA-AG-100001','IRDAI/DB/100/2020'), ('IRDA-AG-100002','IRDAI/DB/103/2018'), ('IRDA-AG-100003','IRDAI/DB/101/2019'),
             ('IRDA-AG-100005','IRDAI/DB/102/2021'), ('IRDA-AG-100007','IRDAI/DB/100/2020'), ('IRDA-AG-100009','IRDAI/DB/104/2022'),
             ('IRDA-AG-100011','IRDAI/DB/105/2017')) AS m(lic, irdai)
JOIN learninsurancedb.brokers b ON upper(b.irdai_registration_no) = upper(m.irdai)
WHERE upper(a.license_number) = m.lic AND a.broker_id IS NULL;
