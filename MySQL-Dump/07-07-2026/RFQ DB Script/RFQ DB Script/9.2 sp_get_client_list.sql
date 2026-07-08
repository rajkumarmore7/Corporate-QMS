USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_client_list;

DELIMITER $$

CREATE PROCEDURE rfq_sp_client_list(
	IN p_userid BIGINT,
    IN p_input_json LONGTEXT,-- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
proc_main: BEGIN
    -- Control Pagination Variables
    DECLARE v_userid BIGINT;
    DECLARE v_offset INT DEFAULT 0;
    DECLARE v_limit INT DEFAULT 20;
    DECLARE v_total_records INT DEFAULT 0;
    
    -- Filter Mapping Strings
    DECLARE v_filter_name VARCHAR(255) DEFAULT NULL;
    DECLARE v_filter_type VARCHAR(30) DEFAULT NULL;
    DECLARE v_filter_vertical VARCHAR(30) DEFAULT NULL;
    DECLARE v_filter_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_final_array JSON;
    
    -- Smart Filter Extracted Variable
    DECLARE v_smart_search VARCHAR(255) DEFAULT NULL;

    -- System Diagnostic Capture Variables
    DECLARE v_sql_state VARCHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- =========================================================================
    -- THE "CATCH" BLOCK (Global Exception Trap)
    -- =========================================================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 
            v_sql_state = RETURNED_SQLSTATE, 
            v_error_msg = MESSAGE_TEXT;
            
		-- STREAM CRASH RECORD TO DISK ON WAREHOUSE EXCEPTION LEDGER
        CALL misp_audit_warehouse.sp_log_database_exception(
            'rfq_sp_client_list',
            v_sql_state,
            v_error_msg,
            p_userid,
            p_input_json
        );

        SET p_response = JSON_OBJECT(
            'status', 500,
            'message', CONCAT('Database Fetch Error: ', v_error_msg),
            'payload', JSON_OBJECT('sql_state', v_sql_state)
        );
    END;

    -- =========================================================================
    -- THE "TRY" BLOCK (Core Extractor Engine)
    -- =========================================================================
    
    -- 1. Streamline Parameter Extractions
    SET v_userid = p_userid;-- CAST(p_input_json->>'$.userid' AS UNSIGNED);
    SET v_offset = CAST(COALESCE(p_input_json->>'$.offset', 0) AS UNSIGNED);
    SET v_limit  = CAST(COALESCE(p_input_json->>'$.limit', 20) AS UNSIGNED);
	-- Select v_userid;
    -- 2. Extract Search Criteria Targets
    SET v_filter_name     = NULLIF(TRIM(p_input_json->>'$.filters.client_name'), '');
    SET v_filter_type     = NULLIF(TRIM(p_input_json->>'$.filters.client_type_code'), '');
    SET v_filter_vertical = NULLIF(TRIM(p_input_json->>'$.filters.client_vertical_code'), '');
    SET v_filter_status   = NULLIF(TRIM(p_input_json->>'$.filters.client_status_code'), '');

    -- Format wildcard tracking vector only if search string exists
    IF v_filter_name IS NOT NULL THEN
        SET v_filter_name = CONCAT('%', v_filter_name, '%');
    END IF;
    
    -- 3. INTERCEPT SMART SEARCH KEY AND ANALYZE INTENT TYPE
    SET v_smart_search = NULLIF(TRIM(p_input_json->>'$.filters.search'), '');
    IF v_smart_search IS NOT NULL AND v_smart_search <> '' THEN
		IF v_smart_search REGEXP '^[0-9]{10}$' THEN
			SET v_filter_name = ""; 
		ELSE 
			SET v_filter_name = CONCAT('%', v_smart_search, '%');
		END IF;
    END IF;

    -- 3. Calculate Count Using Recursive Org-Tree Boundaries
	-- Clean up temporary tables on unexpected crash exits
	-- DROP TEMPORARY TABLE IF EXISTS tmp_rfq_org_hierarchy;
    -- CREATE TEMPORARY TABLE IF NOT EXISTS tmp_rfq_org_hierarchy (
    --     user_id BIGINT
    -- ) ENGINE=InnoDB;
	-- 
	-- INSERT INTO tmp_rfq_org_hierarchy (user_id) value (v_userid);
    -- INSERT INTO tmp_rfq_org_hierarchy (user_id) 
	--  WITH RECURSIVE org_hierarchy AS (
    --     -- Anchor Member: Start with the active logged-in user
    --     SELECT user_id 
    --     FROM mmi_user_reporting 
    --     WHERE user_id = v_userid
    --     
    --     UNION ALL
    --     
    --     -- Recursive Member: Fetch everyone who reports to the users found in the previous step
    --     SELECT h.user_id 
    --     FROM mmi_user_reporting h
    --     INNER JOIN org_hierarchy oh ON h.supervisor_id = oh.user_id
    -- )
    -- SELECT user_id FROM org_hierarchy where user_id != v_userid;
    -- SELECT user_id FROM tmp_rfq_org_hierarchy;
    
     -- 4. Calculate Count Using the Indexed Temporary Hierarchy Boundary
    SELECT COUNT(1) INTO v_total_records
    FROM v_rfq_clients c
    -- Security Constraint: Match against client owners linked to the subordinate tree
    -- INNER JOIN tmp_rfq_org_hierarchy t ON c.owner_id = t.user_id
    WHERE -- c.owner_id IN (SELECT user_id FROM tmp_rfq_org_hierarchy) AND
       (v_filter_name     IS NULL OR c.client_name LIKE v_filter_name)
      AND (v_filter_type     IS NULL OR c.client_type_code = v_filter_type)
      AND (v_filter_vertical IS NULL OR c.client_vertical_code = v_filter_vertical)
      AND (v_filter_status   IS NULL OR c.client_status_code = v_filter_status);

    -- 5. Execute Single Optimized Paginated Extraction Array
    SELECT 
        JSON_ARRAYAGG(
            JSON_OBJECT(
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
            )
        ) INTO v_final_array
    FROM (
        SELECT 
            c.client_code, c.client_UUID, c.client_name, c.client_type_code,
            c.client_vertical_code, c.client_status_code, c.client_type,
            c.client_vertical, c.client_status, c.pincode, c.city_name,
            c.state_name, c.created_on, c.approve_by, c.approval_on,
            c.client_owner, c.active ,c.owner_id
        FROM v_rfq_clients c
        -- INNER JOIN tmp_rfq_org_hierarchy t ON c.owner_id = t.user_id
        WHERE -- c.owner_id IN (SELECT user_id FROM tmp_rfq_org_hierarchy) AND 
			  (v_filter_name     IS NULL OR c.client_name LIKE v_filter_name)
          AND (v_filter_type     IS NULL OR c.client_type_code = v_filter_type)
          AND (v_filter_vertical IS NULL OR c.client_vertical_code = v_filter_vertical)
          AND (v_filter_status   IS NULL OR c.client_status_code = v_filter_status)
        ORDER BY c.client_id DESC
        LIMIT v_limit OFFSET v_offset
    ) main;
    
    -- Clean up session memory cache allocation immediately
    DROP TEMPORARY TABLE IF EXISTS tmp_rfq_org_hierarchy;

    -- 5. Return Complete JSON Output Envelope
    SET p_response = JSON_OBJECT(
        'status', 200,
        'message', 'Client Record Found',
        'payload', JSON_OBJECT(
            'total_records', v_total_records,
            'clients', COALESCE(v_final_array, JSON_ARRAY())
        )
    );

END$$


DELIMITER ;
-- 91 , 74
SET @search_json_page2 = '{
    "userid": 69,
    "offset": 0, 
    "limit": 10,
    "filters": {
        "search": "mahindra",
        "client_name": "",
        "client_type_code": "",
        "client_vertical_code": "",
        "client_status_code": "",
        "pincode": ""
    }
}';

CALL rfq_sp_client_list(8,@search_json_page2, @list_output);

 SELECT @list_output AS api_response;
 
 
 
    
   --  -- 3. INTERCEPT SMART SEARCH KEY AND ANALYZE INTENT TYPE
--     SET v_smart_search = NULLIF(TRIM(p_input_json->>'$.filters.search'), '');

--     -- IF v_smart_search IS NOT NULL AND v_smart_search <> '' THEN
-- --         
-- --         -- Route A: Email Detection (Contains an @ symbol)
-- --         IF v_smart_search REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
-- --             SET v_filter_email = v_smart_search;
-- --             
-- --         -- Route B: Mobile Detection (Exactly 10 numeric digits)
-- --         ELSEIF v_smart_search REGEXP '^[0-9]{10}$' THEN
-- --             -- 🔥 IMPORTANT: Encrypt it first inline so it can match against the encrypted table column
-- --             SET v_filter_mobile = f_crypto_value(v_smart_search, 1);
-- --             
-- --         -- Route C: Character Text Default -> Fallback to Client Name Wildcard Match
-- --         ELSE
-- --             SET v_filter_name = CONCAT('%', v_smart_search, '%');
-- --         END IF;
-- --         
-- --     END IF;