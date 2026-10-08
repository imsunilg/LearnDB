-- Seed roles and demo users (idempotent).
-- Passwords are hashed with bcrypt through pgcrypto (crypt + gen_salt('bf')) - $2a$ hashes verify with BCrypt.Net.
-- admin / Admin@123     underwriter, agent, claims, viewer / Pass@123
SET search_path = learninsurancedb, public;

INSERT INTO roles (name, description, is_system, created_by)
SELECT v.name, v.description, TRUE, 'seed'
FROM (VALUES
    ('Admin',         'Full access to every module'),
    ('Underwriter',   'Reviews proposals and issues policies'),
    ('Agent',         'Sells policies, manages own customers and proposals'),
    ('ClaimsOfficer', 'Registers and settles claims'),
    ('Viewer',        'Read-only access')
) AS v(name, description)
WHERE NOT EXISTS (SELECT 1 FROM roles r WHERE r.name = v.name);

INSERT INTO users (username, email, full_name, mobile, password_hash, created_by)
SELECT v.username, v.email, v.full_name, v.mobile, crypt(v.password, gen_salt('bf', 10)), 'seed'
FROM (VALUES
    ('admin',       'admin@learninsurance.local',       'System Administrator', '9000000001', 'Admin@123'),
    ('underwriter', 'underwriter@learninsurance.local', 'Uma Underwriter',      '9000000002', 'Pass@123'),
    ('agent',       'agent@learninsurance.local',       'Arun Agent',           '9000000003', 'Pass@123'),
    ('claims',      'claims@learninsurance.local',      'Chitra Claims',        '9000000004', 'Pass@123'),
    ('viewer',      'viewer@learninsurance.local',      'Vikas Viewer',         '9000000005', 'Pass@123')
) AS v(username, email, full_name, mobile, password)
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.username = v.username);

INSERT INTO user_roles (user_id, role_id, created_by)
SELECT u.id, r.id, 'seed'
FROM (VALUES ('admin','Admin'), ('underwriter','Underwriter'), ('agent','Agent'), ('claims','ClaimsOfficer'), ('viewer','Viewer')) AS m(username, role_name)
JOIN users u ON u.username = m.username
JOIN roles r ON r.name = m.role_name
WHERE NOT EXISTS (SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id AND ur.role_id = r.id);
