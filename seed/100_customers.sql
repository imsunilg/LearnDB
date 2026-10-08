-- Seed customers (idempotent: skipped when the email already exists)
INSERT INTO learninsurancedb.customers
    (full_name, email, mobile, date_of_birth, gender, pan_number, address_line, city, state, pincode, kyc_status, created_by)
SELECT v.full_name, v.email, v.mobile, v.dob::date, v.gender, v.pan, v.addr, v.city, v.state, v.pin, v.kyc, 'seed'
FROM (VALUES
    ('Aarav Sharma',   'aarav.sharma@example.com',   '9820011001', '1988-04-12', 'Male',   'ABCPS1234A', '12 Marine Drive',      'Mumbai',     'Maharashtra',   '400020', 'Verified'),
    ('Diya Patel',     'diya.patel@example.com',     '9825022002', '1992-09-30', 'Female', 'BCDPP2345B', '45 CG Road',           'Ahmedabad',  'Gujarat',       '380009', 'Verified'),
    ('Rohan Mehta',    'rohan.mehta@example.com',    '9890033003', '1985-01-18', 'Male',   'CDEPM3456C', '7 FC Road',            'Pune',       'Maharashtra',   '411004', 'Pending'),
    ('Ananya Iyer',    'ananya.iyer@example.com',    '9840044004', '1995-06-05', 'Female', 'DEFPI4567D', '22 Anna Salai',        'Chennai',    'Tamil Nadu',    '600002', 'Verified'),
    ('Vikram Singh',   'vikram.singh@example.com',   '9414055005', '1979-11-23', 'Male',   'EFGPS5678E', '3 MI Road',            'Jaipur',     'Rajasthan',     '302001', 'Verified'),
    ('Neha Kapoor',    'neha.kapoor@example.com',    '9811066006', '1990-02-14', 'Female', 'FGHPK6789F', '19 Connaught Place',   'Delhi',      'Delhi',         '110001', 'Pending'),
    ('Karthik Nair',   'karthik.nair@example.com',   '9847077007', '1983-08-09', 'Male',   'GHIPN7890G', '8 MG Road',            'Kochi',      'Kerala',        '682016', 'Verified'),
    ('Ishita Das',     'ishita.das@example.com',     '9830088008', '1997-12-01', 'Female', 'HIJPD8901H', '56 Park Street',       'Kolkata',    'West Bengal',   '700016', 'Verified'),
    ('Arjun Reddy',    'arjun.reddy@example.com',    '9848099009', '1986-03-27', 'Male',   'IJKPR9012I', '14 Banjara Hills',     'Hyderabad',  'Telangana',     '500034', 'Verified'),
    ('Meera Joshi',    'meera.joshi@example.com',    '9822010010', '1993-07-19', 'Female', 'JKLPJ0123J', '31 Deccan Gymkhana',   'Pune',       'Maharashtra',   '411004', 'Verified'),
    ('Sanjay Gupta',   'sanjay.gupta@example.com',   '9935011011', '1975-05-02', 'Male',   'KLMPG1234K', '90 Hazratganj',        'Lucknow',    'Uttar Pradesh', '226001', 'Verified'),
    ('Pooja Verma',    'pooja.verma@example.com',    '9926022012', '1991-10-10', 'Female', 'LMNPV2345L', '5 MP Nagar',           'Bhopal',     'Madhya Pradesh','462011', 'Pending'),
    ('Rahul Khanna',   'rahul.khanna@example.com',   '9815033013', '1982-09-15', 'Male',   'MNOPK3456M', '27 Sector 17',         'Chandigarh', 'Chandigarh',    '160017', 'Verified'),
    ('Sneha Kulkarni', 'sneha.kulkarni@example.com', '9880044014', '1994-01-28', 'Female', 'NOPPK4567N', '10 Indiranagar',       'Bengaluru',  'Karnataka',     '560038', 'Verified'),
    ('Manish Tiwari',  'manish.tiwari@example.com',  '9893055015', '1980-04-04', 'Male',   'OPQPT5678O', '66 Vijay Nagar',       'Indore',     'Madhya Pradesh','452010', 'Rejected'),
    ('Kavya Menon',    'kavya.menon@example.com',    '9846066016', '1996-11-11', 'Female', 'PQRPM6789P', '4 Marine Drive',       'Kochi',      'Kerala',        '682031', 'Verified'),
    ('Aditya Bansal',  'aditya.bansal@example.com',  '9988077017', '1989-06-21', 'Male',   'QRSPB7890Q', '38 Model Town',        'Ludhiana',   'Punjab',        '141002', 'Verified'),
    ('Riya Saxena',    'riya.saxena@example.com',    '9919088018', '1998-03-03', 'Female', 'RSTPS8901R', '12 Civil Lines',       'Kanpur',     'Uttar Pradesh', '208001', 'Pending'),
    ('Nikhil Desai',   'nikhil.desai@example.com',   '9879099019', '1984-12-25', 'Male',   'STUPD9012S', '21 Ellisbridge',       'Surat',      'Gujarat',       '395007', 'Verified'),
    ('Tanvi Rao',      'tanvi.rao@example.com',      '9845010020', '1992-05-17', 'Female', 'TUVPR0123T', '9 Jayanagar',          'Bengaluru',  'Karnataka',     '560011', 'Verified')
) AS v(full_name, email, mobile, dob, gender, pan, addr, city, state, pin, kyc)
WHERE NOT EXISTS (SELECT 1 FROM learninsurancedb.customers c WHERE c.email = v.email);
