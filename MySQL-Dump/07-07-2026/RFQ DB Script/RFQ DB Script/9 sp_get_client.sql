USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_get_client;

DELIMITER $$

CREATE PROCEDURE rfq_sp_get_client(
	IN p_userid BIGINT,
    IN p_input_json LONGTEXT,-- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
proc_main: BEGIN
    -- Internal Control Tracker Variables
    DECLARE v_userid BIGINT UNSIGNED;
    DECLARE v_client_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_client_UUID VARCHAR(50);
    DECLARE v_client_status_code VARCHAR(50);
    DECLARE v_owner_id BIGINT UNSIGNED;
    -- System Exception State Catch Containers
    DECLARE v_sql_state VARCHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;
    
    -- Access control
    DECLARE is_edit VARCHAR(2) DEFAULT '0';
    DECLARE is_approve VARCHAR(2) DEFAULT '0';
    DECLARE is_owner VARCHAR(2) DEFAULT '0';
    
    -- =========================================================================
    -- THE "CATCH" BLOCK (Global Exception Handler)
    -- =========================================================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 
            v_sql_state = RETURNED_SQLSTATE, 
            v_error_msg = MESSAGE_TEXT;
            
		-- STREAM CRASH RECORD TO DISK ON WAREHOUSE EXCEPTION LEDGER
        CALL misp_audit_warehouse.sp_log_database_exception(
            'rfq_sp_get_client',
            v_sql_state,
            v_error_msg,
            p_userid,
            p_input_json
        );

        SET p_response = JSON_OBJECT(
            'status', 500,
            'message', CONCAT('Database Fetch Error: ', v_error_msg),
            'payload', NULL
        );
    END;

    -- =========================================================================
    -- THE "TRY" BLOCK (Core Fetch Logic)
    -- =========================================================================

    -- 1. Safely extract target identification keys out of input document paths
    SET v_userid = p_userid; -- CAST(p_input_json->>'$.userid' AS UNSIGNED);
    SET v_client_UUID = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client_UUID'));
    -- 2. Resolve internal master sequential primary auto-increment identifier 
    SELECT client_id, client_status_code INTO v_client_id   , v_client_status_code
    FROM rfq_clients   WHERE client_UUID = v_client_UUID -- COLLATE utf8mb4_unicode_ci
	LIMIT 1;
	
	 IF v_client_id IS NULL THEN
        SET p_response = JSON_OBJECT(
            'status', 4001,
            'message', 'Client not found',
            'payload', NULL
        );
        LEAVE proc_main;
    END IF;
    
    -- 2. Client user hierarchy
    select o.owner_id INTO v_owner_id  from rfq_clients_owners o where o.client_id = v_client_id and o.active = 1 and o.owner_type_code = 'cooo' limit 1;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_rfq_getclient_hierarchy;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_rfq_getclient_hierarchy (
        user_id BIGINT
    ) ENGINE=InnoDB;

	INSERT INTO tmp_rfq_getclient_hierarchy(user_id)
    WITH RECURSIVE org_hierarchy AS (
        -- Anchor Member: Start with the active logged-in user
        SELECT user_id 
        FROM mmi_user_reporting 
        WHERE user_id = v_userid
        UNION ALL
        -- Recursive Member: Fetch everyone who reports to the users found in the previous step
        SELECT h.user_id 
        FROM mmi_user_reporting h
        INNER JOIN org_hierarchy oh ON h.supervisor_id = oh.user_id
    )
    SELECT user_id FROM org_hierarchy;
    
	 -- =========================================================================
    -- ACCESS CONTROL ENTITLEMENT FIREWALL ENGINE
    -- =========================================================================
    
    -- Entitlement Rule Set A: Direct Ownership Check
    IF (v_client_status_code = 'casp' AND v_owner_id = v_userid) THEN 
        SET is_edit = '1';
        
    -- Entitlement Rule Set B: Check if matching Supervisors belong to active management stream
    ELSEIF EXISTS (
        SELECT 1 
        FROM mmi_user_role_mapping u 
        INNER JOIN mmi_mast_role r ON r.role_id = u.role_id
        INNER JOIN tmp_rfq_getclient_hierarchy t ON t.user_id = u.user_id
        WHERE r.role IN ('Sales Manager', 'Sales Vertical Head')
          AND u.user_id = v_userid
    ) THEN 
        SET is_edit = '1';
        IF (v_client_status_code = 'casp') THEN
            SET is_approve = '1'; 
        END IF;
    END IF;
    
    -- Entitlement Rule Set C: Upper Management Re-assignment Privilege Evaluation
    IF EXISTS (
        SELECT 1 
        FROM mmi_user_role_mapping u 
        INNER JOIN mmi_mast_role r ON r.role_id = u.role_id
        INNER JOIN tmp_rfq_getclient_hierarchy t ON t.user_id = u.user_id
        WHERE r.role IN ('Sales Vertical Head', 'Sales Zonal Head', 'Sales Business Head')
          AND u.user_id = v_userid
    ) THEN
        SET is_owner = '1'; 
    END IF;
    
    -- To view the records in debuging
    -- SELECT is_edit, is_owner, is_approve,  v_owner_id, user_id as hierarchy_id, v_userid FROM tmp_rfq_getclient_hierarchy;

    -- 4. Guard Clause: Route to structured error state mapping if target asset is missing
   
	-- Select v_client_id, v_client_UUID;
    -- 4. Aggregate nested profiles into one final unified out JSON object
    SELECT JSON_OBJECT(
        'status', 200,
        'message', 'Client record found',
        'payload', JSON_OBJECT(
            'client', JSON_OBJECT(
                'client_code',          main.client_code,
                'client_UUID',          main.client_UUID,
                'client_name',          main.client_name,
                'client_type_code',     main.client_type_code,
                'client_vertical_code', main.client_vertical_code,
                'client_status_code',   main.client_status_code,
                'client_type',          main.client_type,
                'client_vertical',      main.client_vertical,
                'client_status',        main.client_status,
                'pincode',              main.pincode,
                'city_name',            main.city_name,
                'state_name',           main.state_name,
                'created_on',           DATE_FORMAT(main.created_on, '%Y-%m-%d'),
                'approve_by',           main.approve_by,
                'approval_on',          DATE_FORMAT(main.approval_on, '%Y-%m-%d'),
                'client_owner',         main.client_owner,
                'active',               main.active
            ),
            'client_data', main.client_payload,
            'is_edit', is_edit,
            'is_approve', is_approve,
            'is_owner', is_owner,
            'contacts', COALESCE(main.contacts_array, JSON_ARRAY())
        )
    ) INTO p_response
    FROM (
        SELECT 
            c.client_code, c.client_UUID, c.client_name, c.client_type_code,
            c.client_vertical_code, c.client_status_code, c.client_type,
            c.client_vertical, c.client_status, c.pincode, c.city_name,
            c.state_name, c.created_on, c.approve_by, c.approval_on,
            c.client_owner, c.active ,c.owner_id,
            -- Pull down latest configurations mapping active versions
            (SELECT cd.client_payload 
             FROM rfq_clients_data cd 
             WHERE cd.client_id = c.client_id AND cd.active = TRUE 
             ORDER BY cd.client_data_id DESC LIMIT 1) AS client_payload,
            -- Assemble nested stakeholders array while decrypting hidden text strings
            (SELECT JSON_ARRAYAGG(
                        JSON_OBJECT(
                            'name', ct.contact_name,
                            'email', ct.contact_email,
                            'mobile', ct.contact_mobile -- Decrypts inline safely
                        )
                    )
             FROM rfq_contact ct
             WHERE ct.table_name = 'rfq_clients'
               AND ct.pk_id = c.client_id
               AND ct.active = TRUE) AS contacts_array
        FROM v_rfq_clients c
        WHERE c.client_id = v_client_id
    ) main;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_rfq_getclient_hierarchy;

END$$

DELIMITER ;


-- 1. Initialize testing parameter mock
SET @json_input = '{"userid": 71,"payload":{"client_UUID": "645876468c7351Q7450Q11f1Qb0eeQc018507ef9d5"}}';

-- 2. Call procedure using the exact name and passing a variable placeholder for the out block
CALL rfq_sp_get_client(8,@json_input, @api_response_output);

-- 3. Inspect the final output mapping response returned
SELECT @api_response_output AS response_payload;


-- USE corporateqms;

-- DROP PROCEDURE IF EXISTS rfq_sp_get_client;

-- DELIMITER $$

-- CREATE PROCEDURE rfq_sp_get_client(
--     IN p_client_UUID VARCHAR(50) -- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
-- )
-- BEGIN
--     DECLARE v_client_id BIGINT UNSIGNED DEFAULT NULL;




--     -- Force the comparison to use utf8mb4_unicode_ci inline
--     SELECT client_id INTO v_client_id  
--     FROM client  
--     -- WHERE client_UUID COLLATE utf8mb4_unicode_ci = p_client_UUID 
--      WHERE client_UUID = p_client_UUID 
--     LIMIT 1;

--     -- If no ID was captured, branch straight to the Error Object
--     IF v_client_id IS NULL THEN
--         SELECT JSON_OBJECT(
--             'status', 4001,
--             'message', 'Client not found',
--             'payload', NULL
--         ) AS response;
--     ELSE
--         -- Run the payload fetcher using the Primary Key
--         SELECT JSON_OBJECT(
--             'status', 200,
--             'message', 'Client record found',
--             'payload', JSON_OBJECT(
--                 'client', JSON_OBJECT(
--                     'client_id', main.client_id,
--                     'client_name', main.client_name,
--                     'client_type_code', main.client_type_code
--                 ),
--                 'client_data', main.client_payload,
--                 'contacts', COALESCE(main.contacts_array, JSON_ARRAY())
--             )
--         ) AS response
--         FROM (
--             SELECT 
--                 c.client_id,
--                 c.client_name,
--                 c.client_type_code,
--                 (SELECT cd.client_payload 
--                  FROM client_data cd 
--                  WHERE cd.client_id = c.client_id AND cd.active = TRUE 
--                  ORDER BY cd.client_data_id DESC LIMIT 1) AS client_payload,
--                 (SELECT JSON_ARRAYAGG(
--                             JSON_OBJECT(
--                                 'name', ct.name,
--                                 'email', ct.email,
--                                 'mobile', ct.mobile
--                             )
--                         )
--                  FROM contact ct
--                  WHERE ct.table_name = 'client'
--                    AND ct.pk_id = c.client_id
--                    AND ct.active = TRUE) AS contacts_array
--             FROM client c
--             WHERE c.client_id = v_client_id
--         ) main;
--     END IF;

-- END$$

-- DELIMITER ;

-- CALL rfq_sp_get_client('645876468c7351Q7450Q11f1Qb0eeQc018507ef9d5'); 