USE misp_crm_corpo;

DELIMITER $$

CREATE PROCEDURE rfq_sp_client_list(
    IN p_userid BIGINT,
    IN p_input_json LONGTEXT,
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
    DECLARE v_pincode VARCHAR(30) DEFAULT NULL;
    DECLARE v_from_date DATETIME DEFAULT NULL;
    DECLARE v_to_date DATETIME DEFAULT NULL;
    DECLARE v_primary_owner BIGINT DEFAULT NULL;

    DECLARE v_final_array JSON;
    DECLARE v_smart_search VARCHAR(255) DEFAULT NULL;
    DECLARE v_sql_state VARCHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- Global Exception Trap
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 
            v_sql_state = RETURNED_SQLSTATE, 
            v_error_msg = MESSAGE_TEXT;
            
        CALL misp_audit_warehouse.sp_log_database_exception(
            'rfq_sp_client_list', v_sql_state, v_error_msg, p_userid, p_input_json
        );

        SET p_response = JSON_OBJECT(
            'status', 500,
            'message', CONCAT('Database Fetch Error: ', v_error_msg),
            'payload', JSON_OBJECT('sql_state', v_sql_state)
        );
    END;

    -- 1. Parameter Extractions
    SET v_userid = p_userid;
    SET v_offset = CAST(COALESCE(p_input_json->>'$.offset', 0) AS UNSIGNED);
    SET v_limit  = CAST(COALESCE(p_input_json->>'$.limit', 20) AS UNSIGNED);

    -- 2. Extract Search Criteria
    SET v_filter_name     = NULLIF(TRIM(p_input_json->>'$.filters.client_name'), '');
    SET v_filter_type     = NULLIF(TRIM(p_input_json->>'$.filters.client_type_code'), '');
    SET v_filter_vertical = NULLIF(TRIM(p_input_json->>'$.filters.client_vertical_code'), '');
    SET v_filter_status   = NULLIF(TRIM(p_input_json->>'$.filters.client_status_code'), '');
    SET v_pincode         = NULLIF(TRIM(p_input_json->>'$.filters.pincode'), '');
    SET v_from_date       = NULLIF(TRIM(p_input_json->>'$.filters.from_date'), '');
    SET v_to_date         = NULLIF(TRIM(p_input_json->>'$.filters.to_date'), '');
    SET v_primary_owner   = CAST(NULLIF(TRIM(p_input_json->>'$.filters.primary_owner'), '') AS UNSIGNED);

    IF v_filter_name IS NOT NULL THEN
        SET v_filter_name = CONCAT('%', v_filter_name, '%');
    END IF;
    
    -- Smart Search Logic
    SET v_smart_search = NULLIF(TRIM(p_input_json->>'$.filters.search'), '');
    IF v_smart_search IS NOT NULL AND v_smart_search <> '' THEN
        IF v_smart_search REGEXP '^[0-9]{10}$' THEN
            SET v_filter_name = ""; 
        ELSE 
            SET v_filter_name = CONCAT('%', v_smart_search, '%');
        END IF;
    END IF;

    -- 3. OPTIMIZED COUNT: Querying base tables directly, completely bypassing the View joins.
    SELECT COUNT(1) INTO v_total_records
    FROM rfq_clients c
    LEFT JOIN rfq_clients_owners o ON o.client_id = c.client_id AND o.active = 1
    WHERE (v_filter_name     IS NULL OR c.client_name LIKE v_filter_name)
      AND (v_filter_type     IS NULL OR c.client_type_code = v_filter_type)
      AND (v_filter_vertical IS NULL OR c.client_vertical_code = v_filter_vertical)
      AND (v_filter_status   IS NULL OR c.client_status_code = v_filter_status)
      AND (v_pincode         IS NULL OR c.pincode = v_pincode)
      AND (v_primary_owner   IS NULL OR o.owner_id = v_primary_owner)
      AND (v_from_date       IS NULL OR c.created_on >= v_from_date)
      AND (v_to_date         IS NULL OR c.created_on <= v_to_date);

    -- 4. OPTIMIZED EXTRACTION: Get IDs first using pagination, THEN join master data tables.
    SELECT 
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'client_code',          CONCAT('C', LPAD(main.client_id, 5, '10000')),
                'client_UUID',          main.client_UUID,
                'client_name',          main.client_name,
                'client_type_code',     main.client_type_code,
                'client_vertical_code', main.client_vertical_code,
                'client_status_code',   main.client_status_code,
                'client_type',          t.key_value,
                'client_vertical',      v.key_value,
                'client_status',        s.key_value,
                'pincode',              main.pincode,
                'city_name',            pn.city_name,
                'state_name',           pn.state_name,
                'created_on',           DATE_FORMAT(main.created_on, '%Y-%m-%d'),
                'approve_by',           CONCAT(ap.first_name, ' ', ap.last_name),
                'approval_on',          DATE_FORMAT(main.approval_on, '%Y-%m-%d'),
                'client_owner',         CONCAT(uo.first_name, ' ', uo.last_name),
                'active',               main.active
            )
        ) INTO v_final_array
    FROM (
        -- Subquery filters and limits raw data efficiently using only base tables
        SELECT c.client_id, c.client_UUID, c.client_name, c.client_type_code, 
               c.client_vertical_code, c.client_status_code, c.pincode, 
               c.created_on, c.approval_id, c.approval_on, c.active, o.owner_id
        FROM rfq_clients c
        LEFT JOIN rfq_clients_owners o ON o.client_id = c.client_id AND o.active = 1
        WHERE (v_filter_name     IS NULL OR c.client_name LIKE v_filter_name)
          AND (v_filter_type     IS NULL OR c.client_type_code = v_filter_type)
          AND (v_filter_vertical IS NULL OR c.client_vertical_code = v_filter_vertical)
          AND (v_filter_status   IS NULL OR c.client_status_code = v_filter_status)
          AND (v_pincode         IS NULL OR c.pincode = v_pincode)
          AND (v_primary_owner   IS NULL OR o.owner_id = v_primary_owner)
          AND (v_from_date       IS NULL OR c.created_on >= v_from_date)
          AND (v_to_date         IS NULL OR c.created_on <= v_to_date)
        ORDER BY c.client_id DESC
        LIMIT v_limit OFFSET v_offset
    ) main
    -- Master data lookups executed ONLY on the final 20 slice records
    LEFT JOIN rfq_kds t ON t.key_code = main.client_type_code
    LEFT JOIN rfq_kds v ON v.key_code = main.client_vertical_code
    LEFT JOIN rfq_kds s ON s.key_code = main.client_status_code
    LEFT JOIN rfq_mst_pincode_master pn ON pn.pincode = main.pincode
    LEFT JOIN mmi_mast_user_registration_detail ap ON ap.id = main.approval_id
    LEFT JOIN mmi_mast_user_registration_detail uo ON uo.id = main.owner_id;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_rfq_org_hierarchy;

    -- Return JSON Output Envelope
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
        "search": "",
        "client_name": "mahindra",
        "client_type_code": "cttc",
        "client_vertical_code": "",
        "client_status_code": "",
        "primary_owner": "",
        "from_daye": "",
        "to_date": "",
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
-- --             -- IMPORTANT: Encrypt it first inline so it can match against the encrypted table column
-- --             SET v_filter_mobile = f_crypto_value(v_smart_search, 1);
-- --             
-- --         -- Route C: Character Text Default -> Fallback to Client Name Wildcard Match
-- --         ELSE
-- --             SET v_filter_name = CONCAT('%', v_smart_search, '%');
-- --         END IF;
-- --         
-- --     END IF;