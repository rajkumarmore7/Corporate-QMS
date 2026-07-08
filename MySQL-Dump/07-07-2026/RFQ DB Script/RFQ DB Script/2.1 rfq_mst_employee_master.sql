use misp_crm_corpo;

DROP TABLE IF EXISTS rfq_mst_employee_master;

CREATE TABLE rfq_mst_employee_master (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id VARCHAR(20),
    employee_name VARCHAR(200),
    gender VARCHAR(50),
    start_date VARCHAR(200),
    event_date VARCHAR(200),
    confirmation_date VARCHAR(200),
    date_of_leaving VARCHAR(200),
    department_code VARCHAR(200),
    department_name VARCHAR(200),
    designation VARCHAR(200),
    is_operation_user VARCHAR(200),
    is_sales_user VARCHAR(200),
    designation_name VARCHAR(200),
    location VARCHAR(200),
    location_name VARCHAR(200),
    branch_code VARCHAR(50),
    branch_name VARCHAR(200),
    employee_status VARCHAR(50),
    email VARCHAR(255),
    mobile VARCHAR(20),
    reporting_manager VARCHAR(200),
    business_unit_code VARCHAR(200),
    business_unit_name VARCHAR(100),
    created_on DATETIME NULL,
    modified_on DATETIME NULL,
    verticle_code VARCHAR(200),
    verticle VARCHAR(200),
    remarks  VARCHAR(200),
    PRIMARY KEY (id),
    KEY idx_user_id (user_id)
);

DROP TABLE IF EXISTS rfq_mst_barnch_master;

CREATE TABLE rfq_mst_barnch_master (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    branch_code VARCHAR(50),
    branch_name VARCHAR(200),
    created_on DATETIME NULL,
    modified_on DATETIME NULL,
    PRIMARY KEY (`id`),
    KEY `idx_rfq_mst_barnch_master_branch_code` (`branch_code`)
    
);

DROP TABLE IF EXISTS rfq_mst_pincode_master;

CREATE TABLE rfq_mst_pincode_master (
	id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    pincode INT NOT NULL,
    city_code VARCHAR(100) NOT NULL,
    city_name VARCHAR(100) NOT NULL,
    state_code VARCHAR(10) NOT NULL,
    state_name VARCHAR(100) NOT NULL,
    created_on DATETIME NULL,
    modified_on DATETIME NULL,
    PRIMARY KEY (`id`),
    KEY `idx_rfq_mst_pincode_master_Pincode` (`pincode`)
);

use misp_crm_corpo;

INSERT INTO rfq_kds (key_module, key_source, key_code, key_name, key_value) VALUES
('usermngt', 'department', 'udds', 'department', 'Sales'),
('usermngt', 'department', 'uddi', 'department', 'IT'),
('usermngt', 'department', 'uddp', 'department', 'Placement');

CREATE TABLE rfq_mast_user_department (
	id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
	department_code VARCHAR(30) NOT NULL, -- Sales, Placement, Admin
	`created_id` BIGINT NULL,
	`created_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`updated_id` BIGINT NULL,
	`updated_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	`active` BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (`id`),
    KEY `idx_rfq_mast_user_department_user_id` (`user_id`),
    CONSTRAINT `idx_rfq_mast_user_department_kds` FOREIGN KEY (`department_code`) REFERENCES `rfq_kds` (`key_code`)
);

ALTER TABLE mmi_mast_user_registration_detail ADD COLUMN designation_code VARCHAR(50) NULL,
ADD CONSTRAINT fk_mmi_user_designation FOREIGN KEY (designation_code) REFERENCES rfq_kds (key_code);

INSERT INTO rfq_kds (key_module, key_source, key_code, key_name, key_value) VALUES
('usermngt', 'designation', 'uddsrm', 'designation', 'Sales RM – Level 1'),
('usermngt', 'designation', 'uddsprm', 'designation', 'Sales and Placement RM – Level 1'),
('usermngt', 'designation', 'uddmng', 'designation', 'Sales Manager – Level 2'),
('usermngt', 'designation', 'uddvh', 'designation', 'Sales Vertical Head – Level 3'),
('usermngt', 'designation', 'uddbh', 'designation', 'Sales Business Head – Level 4'),
('usermngt', 'designation', 'uddprm', 'designation', 'Placement RM – Level 1'),
('usermngt', 'designation', 'uddpm', 'designation', 'Placement Manager – Level 2'),
('usermngt', 'designation', 'uddph', 'designation', 'Placement Head – Level 3');