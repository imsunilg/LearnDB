-- Master data seed (idempotent on type+code)
SET search_path = learninsurancedb, public;

-- Flat lists ---------------------------------------------------------------------------------------------------
INSERT INTO master_data (type, code, name, sort_order, created_by)
SELECT v.type, v.code, v.name, v.ord, 'seed'
FROM (VALUES
    ('RELATIONSHIP','SELF','Self',1), ('RELATIONSHIP','SPOUSE','Spouse',2), ('RELATIONSHIP','SON','Son',3), ('RELATIONSHIP','DAUGHTER','Daughter',4),
    ('RELATIONSHIP','FATHER','Father',5), ('RELATIONSHIP','MOTHER','Mother',6), ('RELATIONSHIP','BROTHER','Brother',7), ('RELATIONSHIP','SISTER','Sister',8),
    ('OCCUPATION','SALARIED','Salaried',1), ('OCCUPATION','SELF_EMPLOYED','Self-employed',2), ('OCCUPATION','BUSINESS','Business owner',3),
    ('OCCUPATION','PROFESSIONAL','Professional',4), ('OCCUPATION','STUDENT','Student',5), ('OCCUPATION','RETIRED','Retired',6), ('OCCUPATION','HOMEMAKER','Homemaker',7),
    ('FUEL_TYPE','PETROL','Petrol',1), ('FUEL_TYPE','DIESEL','Diesel',2), ('FUEL_TYPE','CNG','CNG',3), ('FUEL_TYPE','ELECTRIC','Electric',4),
    ('VEHICLE_TYPE','CAR','Private Car',1), ('VEHICLE_TYPE','TWO_WHEELER','Two Wheeler',2), ('VEHICLE_TYPE','COMMERCIAL','Commercial Vehicle',3),
    ('PAYMENT_MODE','UPI','UPI',1), ('PAYMENT_MODE','CARD','Credit/Debit Card',2), ('PAYMENT_MODE','NETBANKING','Net Banking',3), ('PAYMENT_MODE','CASH','Cash',4), ('PAYMENT_MODE','CHEQUE','Cheque',5),
    ('CLAIM_TYPE','ACCIDENT','Accident',1), ('CLAIM_TYPE','THEFT','Theft',2), ('CLAIM_TYPE','FIRE','Fire',3), ('CLAIM_TYPE','NATURAL_CALAMITY','Natural calamity',4),
    ('CLAIM_TYPE','HOSPITALISATION','Hospitalisation',5), ('CLAIM_TYPE','TRIP_CANCELLATION','Trip cancellation',6), ('CLAIM_TYPE','BAGGAGE_LOSS','Baggage loss',7),
    ('DOCUMENT_TYPE','KYC_ID','ID proof',1), ('DOCUMENT_TYPE','KYC_ADDRESS','Address proof',2), ('DOCUMENT_TYPE','RC_BOOK','RC book',3), ('DOCUMENT_TYPE','POLICY_COPY','Policy copy',4),
    ('DOCUMENT_TYPE','CLAIM_FORM','Claim form',5), ('DOCUMENT_TYPE','MEDICAL_REPORT','Medical report',6), ('DOCUMENT_TYPE','PHOTO','Photograph',7), ('DOCUMENT_TYPE','OTHER','Other',9),
    ('VEHICLE_USAGE','PRIVATE','Private use',1), ('VEHICLE_USAGE','COMMERCIAL','Commercial use',2),
    ('PROPERTY_TYPE','APARTMENT','Apartment / Flat',1), ('PROPERTY_TYPE','INDEPENDENT_HOUSE','Independent house',2), ('PROPERTY_TYPE','VILLA','Villa',3),
    ('CONSTRUCTION_TYPE','RCC','RCC (concrete)',1), ('CONSTRUCTION_TYPE','BRICK','Brick & mortar',2), ('CONSTRUCTION_TYPE','OTHER','Other',3)
) AS v(type, code, name, ord)
ON CONFLICT (type, code) DO NOTHING;

-- States -------------------------------------------------------------------------------------------------------
INSERT INTO master_data (type, code, name, sort_order, created_by)
SELECT 'STATE', v.code, v.name, v.ord, 'seed'
FROM (VALUES
    ('MH','Maharashtra',1), ('GJ','Gujarat',2), ('KA','Karnataka',3), ('TN','Tamil Nadu',4), ('DL','Delhi',5), ('RJ','Rajasthan',6),
    ('KL','Kerala',7), ('WB','West Bengal',8), ('TG','Telangana',9), ('UP','Uttar Pradesh',10), ('MP','Madhya Pradesh',11),
    ('PB','Punjab',12), ('CH','Chandigarh',13)
) AS v(code, name, ord)
ON CONFLICT (type, code) DO NOTHING;

-- Cities (children of states) ---------------------------------------------------------------------------------
INSERT INTO master_data (type, code, name, parent_id, sort_order, created_by)
SELECT 'CITY', v.code, v.name, s.id, v.ord, 'seed'
FROM (VALUES
    ('MH','MUMBAI','Mumbai',1), ('MH','PUNE','Pune',2), ('MH','NAGPUR','Nagpur',3), ('MH','NASHIK','Nashik',4),
    ('GJ','AHMEDABAD','Ahmedabad',1), ('GJ','SURAT','Surat',2), ('GJ','VADODARA','Vadodara',3), ('GJ','RAJKOT','Rajkot',4),
    ('KA','BENGALURU','Bengaluru',1), ('KA','MYSURU','Mysuru',2), ('KA','HUBBALLI','Hubballi',3),
    ('TN','CHENNAI','Chennai',1), ('TN','COIMBATORE','Coimbatore',2), ('TN','MADURAI','Madurai',3),
    ('DL','NEW_DELHI','New Delhi',1), ('DL','DELHI','Delhi',2),
    ('RJ','JAIPUR','Jaipur',1), ('RJ','JODHPUR','Jodhpur',2), ('RJ','UDAIPUR','Udaipur',3),
    ('KL','KOCHI','Kochi',1), ('KL','THIRUVANANTHAPURAM','Thiruvananthapuram',2), ('KL','KOZHIKODE','Kozhikode',3),
    ('WB','KOLKATA','Kolkata',1), ('WB','HOWRAH','Howrah',2), ('WB','SILIGURI','Siliguri',3),
    ('TG','HYDERABAD','Hyderabad',1), ('TG','WARANGAL','Warangal',2),
    ('UP','LUCKNOW','Lucknow',1), ('UP','KANPUR','Kanpur',2), ('UP','NOIDA','Noida',3), ('UP','VARANASI','Varanasi',4),
    ('MP','BHOPAL','Bhopal',1), ('MP','INDORE','Indore',2),
    ('PB','LUDHIANA','Ludhiana',1), ('PB','AMRITSAR','Amritsar',2),
    ('CH','CHANDIGARH','Chandigarh',1)
) AS v(state_code, code, name, ord)
JOIN master_data s ON s.type = 'STATE' AND s.code = v.state_code
ON CONFLICT (type, code) DO NOTHING;

-- Vehicle makes and models (meta carries the vehicle type and a typical ex-showroom price used for IDV) -------
INSERT INTO master_data (type, code, name, sort_order, created_by)
SELECT 'VEHICLE_MAKE', v.code, v.name, v.ord, 'seed'
FROM (VALUES ('MARUTI','Maruti Suzuki',1), ('HYUNDAI','Hyundai',2), ('TATA','Tata Motors',3), ('MAHINDRA','Mahindra',4), ('HONDA','Honda',5),
             ('TOYOTA','Toyota',6), ('HERO','Hero MotoCorp',7), ('BAJAJ','Bajaj',8), ('TVS','TVS',9), ('ROYALENFIELD','Royal Enfield',10)) AS v(code, name, ord)
ON CONFLICT (type, code) DO NOTHING;

INSERT INTO master_data (type, code, name, parent_id, sort_order, meta, created_by)
SELECT 'VEHICLE_MODEL', v.code, v.name, mk.id, v.ord, jsonb_build_object('vehicleType', v.vtype, 'exShowroomPrice', v.price), 'seed'
FROM (VALUES
    ('MARUTI','SWIFT','Swift','Car',650000,1), ('MARUTI','BALENO','Baleno','Car',700000,2), ('MARUTI','BREZZA','Brezza','Car',950000,3),
    ('HYUNDAI','I20','i20','Car',780000,1), ('HYUNDAI','CRETA','Creta','Car',1150000,2), ('HYUNDAI','VENUE','Venue','Car',900000,3),
    ('TATA','NEXON','Nexon','Car',900000,1), ('TATA','PUNCH','Punch','Car',650000,2), ('TATA','ACE','Ace (goods carrier)','Commercial',520000,3),
    ('MAHINDRA','XUV700','XUV700','Car',1500000,1), ('MAHINDRA','THAR','Thar','Car',1300000,2), ('MAHINDRA','BOLERO','Bolero Pickup','Commercial',800000,3),
    ('HONDA','CITY','City','Car',1200000,1), ('HONDA','ACTIVA','Activa','Two Wheeler',85000,2), ('HONDA','SHINE','Shine','Two Wheeler',90000,3),
    ('TOYOTA','INNOVA','Innova Crysta','Car',2000000,1), ('TOYOTA','FORTUNER','Fortuner','Car',3500000,2),
    ('HERO','SPLENDOR','Splendor','Two Wheeler',75000,1), ('HERO','PASSION','Passion','Two Wheeler',78000,2),
    ('BAJAJ','PULSAR','Pulsar 150','Two Wheeler',115000,1), ('BAJAJ','CHETAK','Chetak (EV)','Two Wheeler',130000,2),
    ('TVS','JUPITER','Jupiter','Two Wheeler',82000,1), ('TVS','APACHE','Apache RTR','Two Wheeler',125000,2),
    ('ROYALENFIELD','CLASSIC350','Classic 350','Two Wheeler',200000,1), ('ROYALENFIELD','HIMALAYAN','Himalayan','Two Wheeler',290000,2)
) AS v(make_code, code, name, vtype, price, ord)
JOIN master_data mk ON mk.type = 'VEHICLE_MAKE' AND mk.code = v.make_code
ON CONFLICT (type, code) DO NOTHING;
