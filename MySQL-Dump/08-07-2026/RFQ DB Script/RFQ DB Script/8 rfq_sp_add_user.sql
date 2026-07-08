USE misp_crm_corpo;
-- mmi_proc_insert_new_user_details
DROP PROCEDURE IF EXISTS rfq_sp_add_user;

DELIMITER $$

CREATE PROCEDURE rfq_sp_add_user(
    IN p_input_json LONGTEXT,-- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
proc_main: BEGIN
    -- Parameter Extraction Variables
    DECLARE v_created_user_id BIGINT UNSIGNED;
    DECLARE v_userID INT;
    DECLARE v_firstname VARCHAR(100);
    DECLARE v_sap_code VARCHAR(100);
    DECLARE v_lastname VARCHAR(100);
    DECLARE v_contactinfo VARCHAR(30);
    DECLARE v_emailid VARCHAR(255);
    DECLARE v_status CHAR(1);
    DECLARE v_location VARCHAR(255);
    DECLARE v_role_id INT;
    DECLARE v_role_name VARCHAR(100);
    DECLARE v_ad_flag CHAR(1);
    DECLARE v_team_email_flag CHAR(1);
    DECLARE v_is_group CHAR(1);
    DECLARE v_reportingManager_Id VARCHAR(50);
    
    -- Inferred/Default Script Fillers
    DECLARE v_password VARCHAR(255) DEFAULT 'TemporaryPassword123!';
    DECLARE v_role_type_id INT DEFAULT 1; -- Mapped placeholder baseline
    DECLARE v_designation_code VARCHAR(30) DEFAULT 'uddsrm';

    -- Loop Tracking Variables for Department Processing
    DECLARE v_dept_index INT DEFAULT 0;
    DECLARE v_dept_count INT DEFAULT 0;
    DECLARE v_current_dept_code VARCHAR(50);

    -- Diagnostic Tracking Flags
    DECLARE v_check_exists INT DEFAULT 0;
    DECLARE v_sql_state VARCHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- =========================================================================
    -- THE "CATCH" BLOCK (Global Exception Handler & Safe Rollback)
    -- =========================================================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1 
            v_sql_state = RETURNED_SQLSTATE, 
            v_error_msg = MESSAGE_TEXT;

        SET p_response = JSON_OBJECT(
            'status', 500,
            'message', CONCAT('User Registration Workflow Aborted: ', v_error_msg),
            'payload', NULL
        );
    END;

    -- =========================================================================
    -- THE "TRY" BLOCK (Data Validation Pipelines)
    -- =========================================================================
    
    -- 1. Extract base mapping routes from control payload object
    SET v_created_user_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.userId')) AS UNSIGNED);
    SET v_userID = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.userId')) AS SIGNED);
    SET v_firstname = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.firstname'));
    SET v_lastname = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.lastname'));
    SET v_contactinfo = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.contactinfo'));
    -- SET v_contactinfo = f_crypto_value(JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.contactinfo')), 1); -- Encrypts mobile data securely inline
    SET v_emailid = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.emailid'));
    SET v_status = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.status'));
    -- SET v_sap_code = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.sap_code'));
    SET v_location = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.location'));
    SET v_role_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.roleID')) AS SIGNED);
    SET v_role_name = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.roleName'));
    SET v_ad_flag = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.adFlag'));
    SET v_team_email_flag = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.teamEmail'));
    SET v_sap_code = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.sapCode'));
    SET v_is_group = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.isGroup'));
    SET v_designation_code = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.designation_code'));
    SET v_reportingManager_Id = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.reportingManagerId'));



    -- 2. Validation Check: Verify if Email ID already exists
    SELECT COUNT(1) INTO v_check_exists FROM mmi_mast_user WHERE email_id = v_emailid;
    IF v_check_exists > 0 THEN
        SET p_response = JSON_OBJECT('status', 400, 'message', 'Validation Failed: User ID already existing with this register email address.', 'payload', NULL);
        LEAVE proc_main;
    END IF;

    -- 3. Validation Check: Verify if User/sap ID already exists
    SELECT COUNT(1) INTO v_check_exists FROM mmi_mast_user_registration_detail WHERE sap_code = v_sap_code; -- COLLATE utf8mb4_unicode_ci;
    IF v_check_exists > 0 THEN
        SET p_response = JSON_OBJECT('status', 400, 'message', 'Validation Failed: User already already mapped to an existing record.', 'payload', NULL);
        LEAVE proc_main;
    END IF;

--     -- 4. Validation Check: Confirm Role verification baseline matching v_role_name
--     -- SELECT COUNT(1) INTO v_check_exists FROM mmi_mast_role WHERE role_name = v_role_name;-- COLLATE utf8mb4_unicode_ci;
-- --     IF v_check_exists = 0 THEN
-- --         SET p_response = JSON_OBJECT('status', 404, 'message', 'Validation Failed: Specified system Role Name does not exist in definitions.', 'payload', NULL);
-- --         LEAVE proc_main;
-- --     END IF;

	
    -- Start Atomic Processing Sequence
    START TRANSACTION;
    
    -- 6. Commit Step B: Detailed Profile Registration Ledger
    -- Select 23,v_firstname, v_lastname, v_contactinfo, v_emailid, v_location, v_status, v_team_email_flag, v_role_type_id, v_sap_code, v_is_group, v_created_user_id, v_designation_code;
    INSERT INTO mmi_mast_user_registration_detail (first_name, last_name, mobile_no, email_id, address, status, team_email_flag, role_type_id, sap_code, is_group, created_by, designation_code)
    VALUES (v_firstname, v_lastname, v_contactinfo, v_emailid, v_location, v_status, v_team_email_flag, v_role_type_id, v_sap_code, v_is_group, v_created_user_id, v_designation_code);
    
    SET v_userID = LAST_INSERT_ID();
    
    -- 5. Commit Step A: Master Security User Directory
    INSERT INTO mmi_mast_user (user_id, email_id, status, calling_flag, ad_flag,  is_lock, created_by,password) -- password,
    VALUES (v_userID, v_emailid, v_status, 'N', v_ad_flag,  'U', v_created_user_id,v_password); -- v_password,
	Select 2;
    
    -- 7. Commit Step C: Map User to Single Core Role
    INSERT INTO mmi_user_role_mapping (user_id, role_id, status, created_by)
    VALUES (v_userID, v_role_id, '1', v_created_user_id);

    -- 8. Commit Step D: Map 1-1 Reporting Structure Matrix
    INSERT INTO mmi_user_reporting (user_id, supervisor_id, created_by)
    VALUES (v_userID, v_reportingManager_Id, v_created_user_id);

    -- 9. Commit Step E: Iteratively loop and extract multiple Department assignments
    SET v_dept_count = JSON_LENGTH(JSON_EXTRACT(p_input_json, '$.departments'));
    WHILE v_dept_index < v_dept_count DO
        SET v_current_dept_code = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, CONCAT('$.departments[', v_dept_index, ']')));
        
        -- Insert unique association allocations sequentially
        IF v_current_dept_code IS NOT NULL AND TRIM(v_current_dept_code) <> '' THEN
            INSERT INTO rfq_mast_user_department (user_id, department_code)
            VALUES (v_userID, v_current_dept_code);
        END IF;
        
        SET v_dept_index = v_dept_index + 1;
    END WHILE;

    COMMIT;

    -- 10. Construct Final Unified Output Response Wrapper
    SET p_response = JSON_OBJECT(
        'status', 200,
        'message', 'User account pipeline and multi-department matrices successfully established.',
        'payload', JSON_OBJECT('user_id', v_userID, 'assigned_departments_processed', v_dept_count)
    );

END$$

DELIMITER ;

SET @incoming_payload = '{
    "userId": 2714467121,
    "firstname": "Pankaj",
    "lastname": "Sahu",
    "contactinfo": "7020351228",
    "emailid": "pankaj21.sahu@text.com",
    "status": "1",
    "location": "Mumbai",
    "roleID": 7,
    "roleName": "Sales Regional Manager",
    "manager": "Admin Admin",
    "roleType": "MIBL",
    "dealerCode": "",
    "adFlag": "N",
    "callingFlag": "",
    "leadPool": "",
    "leadsFlag": "",
    "teamEmail": "N",
    "sapCode": "2714467121",
    "isGroup": "N",
    "reportingManagerId": "27042221",
    "designation_code":"uddsrm",
    "departments": ["udds", "uddi"]
}';

CALL rfq_sp_add_user(@incoming_payload, @workflow_response);
SELECT @workflow_response AS operation_result;


-- Select * from  mmi_mast_user;
-- -- INSERT INTO mmi_mast_user (user_id, email_id, status,calling_flag,ad_flag, password, is_lock,created_by)
-- -- VALUES (v_userID, v_emailid, v_status,'N', v_ad_flag, v_password,'U',v_created_user_id);
-- Select * from   mmi_mast_user_registration_detail;
-- -- INSERT INTO mmi_mast_user_registration_detail (first_name, last_name, mobile_no, email_id, address, status, team_email_flag,role_type_id,sap_code,is_group,created_by)
-- -- VALUES (v_firstname, v_lastname, v_contactinfo, v_emailid, v_location, v_status, v_team_email_flag,v_role_type_id,v_sap_code,v_is_group,v_created_user_id);
-- -- Check if the role exising in the mmi_mast_role where v_role_name
-- Select * from   mmi_user_role_mapping;
-- -- INSERT INTO mmi_user_role_mapping (user_id, role_id, status, created_by)
-- -- VALUES (v_userID, v_role_id, '1',v_created_user_id);
-- Select * from   mmi_user_reporting;
-- -- INSERT INTO mmi_user_reporting (user_id, supervisor_id, created_by)
-- -- VALUES (v_userID, v_reportingManager_Id,v_created_user_id);

-- Select * from   rfq_mast_user_department;
-- -- INSERT INTO rfq_mast_user_department (user_id, department_code)
-- -- VALUES (v_userID, v_department_code);
