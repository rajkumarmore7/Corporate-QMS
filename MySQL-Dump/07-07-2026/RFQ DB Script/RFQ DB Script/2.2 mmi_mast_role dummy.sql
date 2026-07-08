USE misp_crm_corpo;

-- Select * from mmi_mast_role;

-- 1. Establish a temporary memory block for incoming role configurations
CREATE TEMPORARY TABLE IF NOT EXISTS temp_roles_to_insert (
    role_name VARCHAR(100),
    role_level VARCHAR(50),
    status CHAR(1)
);

-- 2. Clear out old execution buffers from the temporary session workspace
TRUNCATE TABLE temp_roles_to_insert;

-- 3. Populate targeted Organizational Matrices
INSERT INTO temp_roles_to_insert (role_name, role_level, status) VALUES
-- 🏢 SALES TEAM HIERARCHY
('Sales Regional Manager', '1', '1'),
('Sales Manager',          '2',               '1'),
('Sales Vertical Head',   '3',               '1'),
('Sales Zonal Head',      '4',               '1'),
('Sales Business Head',   '5',         '1'),

-- ⚙️ PRACTICE & PLACEMENT TEAM HIERARCHY
('Placement Head',         '1','1'),
('Placement Manager',     '2',               '1'),
('Placement Regional Manager',     '3',   '1');

-- 4. Execute Protected Upsert Check Stream
INSERT INTO mmi_mast_role (role, role_level, status, created_by, created_date)
SELECT 
    t.role_name, 
    t.role_level, 
    t.status, 
    1,          -- created_by: User ID 1 (System Admin)
    NOW()       -- created_on
FROM temp_roles_to_insert t
WHERE NOT EXISTS (
    SELECT 1 
    FROM mmi_mast_role r 
    -- Normalize and check if role name exists under the target collation baseline
    WHERE LOWER(TRIM(r.role)) = LOWER(TRIM(t.role_name)) -- COLLATE utf8mb4_unicode_ci
);

-- 5. Drop the temporary mapping resource out of active database session memory
DROP TEMPORARY TABLE temp_roles_to_insert;