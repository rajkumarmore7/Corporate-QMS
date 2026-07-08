use misp_crm_corpo;

INSERT INTO rfq_mst_employee_master (
    user_id, employee_name, gender, start_date, event_date, confirmation_date, date_of_leaving, 
    department_code, department_name, designation, is_operation_user, is_sales_user, designation_name, 
    location, location_name, branch_code, branch_name, employee_status, email, mobile, 
    reporting_manager, business_unit_code, business_unit_name, created_on, modified_on, verticle_code, verticle, remarks
) VALUES
('27046671', 'Pankaj Sahu', 'Male', '2023-01-15', '2023-01-15', '2023-07-15', NULL, 'udds', 'Sales Department', 'DES01', 'N', 'Y', 'Sales RM', 'LOC01', 'Mumbai HQ', 'BR01', 'Mumbai Main', 'Active', 'pankaj.sahu@innhbgfoaxon.com', '7020351228', '27042221', 'BU01', 'MIBL', NOW(), NOW(), 'V01', 'Retail Business', 'Initial Migration'),
('27042221', 'Amit Sharma', 'Male', '2020-05-10', '2020-05-10', '2020-11-10', NULL, 'uddi', 'Operations Department', 'DES02', 'Y', 'N', 'Operations Manager', 'LOC01', 'Mumbai HQ', 'BR01', 'Mumbai Main', 'Active', 'amit.sharma@test.com', '9820123456', '27040001', 'BU01', 'MIBL', NOW(), NOW(), 'V02', 'Corporate Business', 'Reporting Manager Tier'),
('27046672', 'Deepika Padukone', 'Female', '2024-02-01', '2024-02-01', '2024-08-01', NULL, 'udds', 'Sales Department', 'DES01', 'N', 'Y', 'Sales RM', 'LOC02', 'Pune Corporate office', 'BR02', 'Pune West', 'Active', 'deepika.p@test.com', '9811223344', '27042221', 'BU01', 'MIBL', NOW(), NOW(), 'V01', 'Retail Business', 'Territory Expansion'),
('27046673', 'Rahul Dravid', 'Male', '2022-11-20', '2022-11-20', '2023-05-20', NULL, 'uddi', 'Operations Department', 'DES03', 'Y', 'N', 'Senior Associate', 'LOC03', 'Bangalore Hub', 'BR03', 'Bangalore Central', 'Active', 'rahul.d@test.com', '9744556677', '27042221', 'BU01', 'MIBL', NOW(), NOW(), 'V03', 'Commercial Lines', 'Operations Sync'),
('27046674', 'Priyanka Chopra', 'Female', '2025-01-10', '2025-01-10', '2025-07-10', NULL, 'udds', 'Sales Department', 'DES01', 'N', 'Y', 'Sales RM', 'LOC04', 'Delhi Regional Branch', 'BR04', 'Delhi Okhla', 'Active', 'priyanka.c@test.com', '9910229933', '27042221', 'BU01', 'MIBL', NOW(), NOW(), 'V01', 'Retail Business', 'Northern Grid Assignment'),
('27046675', 'Sandeep Singh', 'Male', '2021-08-14', '2021-08-14', '2022-02-14', NULL, 'udds', 'Sales Department', 'DES04', 'N', 'Y', 'Account Executive', 'LOC01', 'Mumbai HQ', 'BR01', 'Mumbai Main', 'Active', 'sandeep.s@test.com', '8888777766', '27042221', 'BU01', 'MIBL', NOW(), NOW(), 'V01', 'Retail Business', 'Legacy Account Sync'),
('27046676', 'Ananya Panday', 'Female', '2025-06-01', '2025-06-01', NULL, NULL, 'udds', 'Sales Department', 'DES05', 'N', 'Y', 'Trainee Intern', 'LOC01', 'Mumbai HQ', 'BR01', 'Mumbai Main', 'Active', 'ananya.p@test.com', '7766554433', '27046675', 'BU01', 'MIBL', NOW(), NOW(), 'V01', 'Retail Business', 'Probation Tracker'),
('27046677', 'Vikram Rathour', 'Male', '2019-03-22', '2019-03-22', '2019-09-22', '2025-12-31', 'uddi', 'Operations Department', 'DES02', 'Y', 'N', 'Operations Manager', 'LOC04', 'Delhi Regional Branch', 'BR04', 'Delhi Okhla', 'Left', 'vikram.r@test.com', '9311224455', '27040001', 'BU01', 'MIBL', NOW(), NOW(), 'V02', 'Corporate Business', 'Resigned - Relocated'),
('27046678', 'MS Dhoni', 'Male', '2018-07-07', '2018-07-07', '2019-01-07', NULL, 'udds', 'Sales Department', 'DES06', 'N', 'Y', 'National Strategy Head', 'LOC01', 'Mumbai HQ', 'BR01', 'Mumbai Main', 'Active', 'mahi.dhoni@test.com', '9999988888', '27040001', 'BU01', 'MIBL', NOW(), NOW(), 'V04', 'Strategic Partnerships', 'Executive Alignment'),
('27046679', 'Alia Bhatt', 'Female', '2023-10-10', '2023-10-10', '2024-04-10', NULL, 'uddi', 'Operations Department', 'DES01', 'Y', 'N', 'Operations RM', 'LOC05', 'Chennai Office', 'BR05', 'Chennai Central', 'Active', 'alia.b@test.com', '9444553322', '27042221', 'BU01', 'MIBL', NOW(), NOW(), 'V02', 'Corporate Business', 'Southern Logistics Allocation');

use misp_crm_corpo;

INSERT INTO rfq_mst_pincode_master (pincode, city_code, city_name, state_code, state_name, created_on, modified_on) VALUES
-- MAHARASHTRA (Mumbai & Pune) - 20 Records
(400001, 'MUM', 'Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),
(400002, 'MUM', 'Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),
(400012, 'MUM', 'Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),
(400025, 'MUM', 'Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),
(400050, 'MUM', 'Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),
(400064, 'MUM', 'Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),
(400067, 'MUM', 'Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),
(400072, 'MUM', 'Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),
(400092, 'MUM', 'Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),
(400099, 'MUM', 'Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),
(411001, 'PUN', 'Pune', 'MH', 'Maharashtra', NOW(), NOW()),
(411002, 'PUN', 'Pune', 'MH', 'Maharashtra', NOW(), NOW()),
(411004, 'PUN', 'Pune', 'MH', 'Maharashtra', NOW(), NOW()),
(411006, 'PUN', 'Pune', 'MH', 'Maharashtra', NOW(), NOW()),
(411014, 'PUN', 'Pune', 'MH', 'Maharashtra', NOW(), NOW()),
(411021, 'PUN', 'Pune', 'MH', 'Maharashtra', NOW(), NOW()),
(411038, 'PUN', 'Pune', 'MH', 'Maharashtra', NOW(), NOW()),
(411045, 'PUN', 'Pune', 'MH', 'Maharashtra', NOW(), NOW()),
(411057, 'PUN', 'Pune', 'MH', 'Maharashtra', NOW(), NOW()),
(400703, 'NAV', 'Navi Mumbai', 'MH', 'Maharashtra', NOW(), NOW()),

-- DELHI NCR - 15 Records
(110001, 'DEL', 'Delhi', 'DL', 'Delhi', NOW(), NOW()),
(110002, 'DEL', 'Delhi', 'DL', 'Delhi', NOW(), NOW()),
(110011, 'DEL', 'Delhi', 'DL', 'Delhi', NOW(), NOW()),
(110019, 'DEL', 'Delhi', 'DL', 'Delhi', NOW(), NOW()),
(110020, 'DEL', 'Delhi', 'DL', 'Delhi', NOW(), NOW()),
(110025, 'DEL', 'Delhi', 'DL', 'Delhi', NOW(), NOW()),
(110030, 'DEL', 'Delhi', 'DL', 'Delhi', NOW(), NOW()),
(110048, 'DEL', 'Delhi', 'DL', 'Delhi', NOW(), NOW()),
(110066, 'DEL', 'Delhi', 'DL', 'Delhi', NOW(), NOW()),
(110085, 'DEL', 'Delhi', 'DL', 'Delhi', NOW(), NOW()),
(201301, 'NOI', 'Noida', 'UP', 'Uttar Pradesh', NOW(), NOW()),
(201303, 'NOI', 'Noida', 'UP', 'Uttar Pradesh', NOW(), NOW()),
(122001, 'GUR', 'Gurugram', 'HR', 'Haryana', NOW(), NOW()),
(122002, 'GUR', 'Gurugram', 'HR', 'Haryana', NOW(), NOW()),
(122018, 'GUR', 'Gurugram', 'HR', 'Haryana', NOW(), NOW()),

-- KARNATAKA (Bengaluru Hub) - 12 Records
(560001, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560002, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560004, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560011, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560025, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560034, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560037, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560066, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560076, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560095, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560100, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),
(560103, 'BLR', 'Bengaluru', 'KA', 'Karnataka', NOW(), NOW()),

-- TAMIL NADU (Chennai Hub) - 10 Records
(600001, 'CHN', 'Chennai', 'TN', 'Tamil Nadu', NOW(), NOW()),
(600002, 'CHN', 'Chennai', 'TN', 'Tamil Nadu', NOW(), NOW()),
(600004, 'CHN', 'Chennai', 'TN', 'Tamil Nadu', NOW(), NOW()),
(600017, 'CHN', 'Chennai', 'TN', 'Tamil Nadu', NOW(), NOW()),
(600020, 'CHN', 'Chennai', 'TN', 'Tamil Nadu', NOW(), NOW()),
(600028, 'CHN', 'Chennai', 'TN', 'Tamil Nadu', NOW(), NOW()),
(600032, 'CHN', 'Chennai', 'TN', 'Tamil Nadu', NOW(), NOW()),
(600040, 'CHN', 'Chennai', 'TN', 'Tamil Nadu', NOW(), NOW()),
(600096, 'CHN', 'Chennai', 'TN', 'Tamil Nadu', NOW(), NOW()),
(600119, 'CHN', 'Chennai', 'TN', 'Tamil Nadu', NOW(), NOW()),

-- TELANGANA (Hyderabad Hub) - 8 Records
(500001, 'HYD', 'Hyderabad', 'TG', 'Telangana', NOW(), NOW()),
(500003, 'HYD', 'Hyderabad', 'TG', 'Telangana', NOW(), NOW()),
(500016, 'HYD', 'Hyderabad', 'TG', 'Telangana', NOW(), NOW()),
(500032, 'HYD', 'Hyderabad', 'TG', 'Telangana', NOW(), NOW()),
(500034, 'HYD', 'Hyderabad', 'TG', 'Telangana', NOW(), NOW()),
(500081, 'HYD', 'Hyderabad', 'TG', 'Telangana', NOW(), NOW()),
(500082, 'HYD', 'Hyderabad', 'TG', 'Telangana', NOW(), NOW()),
(500090, 'HYD', 'Hyderabad', 'TG', 'Telangana', NOW(), NOW());