USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_kds;
DROP PROCEDURE IF EXISTS rfq_sp_master_kds;

DELIMITER $$

CREATE PROCEDURE rfq_sp_master_kds(
    IN p_input_json LONGTEXT, -- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
BEGIN
    -- Control Variables
    DECLARE v_key_module VARCHAR(100); 
    DECLARE v_key_source VARCHAR(100); 
    DECLARE v_key_name VARCHAR(100); 
    DECLARE v_parent_code VARCHAR(100); 
    DECLARE v_parent_id INT DEFAULT NULL;
	DECLARE v_offset INT DEFAULT 0;
    DECLARE v_limit INT DEFAULT 100;
	DECLARE v_total_records INT DEFAULT 0;
     -- Filter Strings
    DECLARE v_filter_name VARCHAR(255) DEFAULT NULL;
    DECLARE v_filter_type VARCHAR(30) DEFAULT NULL;
    DECLARE v_final_array JSON;
    -- System Error Capture Variables
    DECLARE v_sql_state VARCHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- Global Exception Handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 
            v_sql_state = RETURNED_SQLSTATE, 
            v_error_msg = MESSAGE_TEXT;

        SET p_response = JSON_OBJECT(
            'status', 500,
            'message', CONCAT('KDS Payload Error: ', v_error_msg),
            'payload', NULL
        );
    END;

    -- 1. Extract the key parms from your standard API payload structure
	SET v_key_module = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.key_module'));
	SET v_key_source = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.key_source'));
    SET v_key_name = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.key_name'));
    SET v_parent_code = NULLIF(TRIM(p_input_json->>'$.payload.parent_code'), '');
    
    -- 2 Appling the parnet filters
    IF v_parent_code IS NOT NULL THEN
        SET v_parent_id = (SELECT kds_id FROM rfq_kds WHERE key_code = v_parent_code AND key_module = 'opportunity' LIMIT 1);
    END IF;
    
	-- 3. Execute Core Paginated Aggregation Query
    IF v_parent_id IS NULL THEN
		SELECT count(1),
		JSON_ARRAYAGG(
					JSON_OBJECT(
						-- 'client_id', main.client_id,
						'code', main.key_code,
						'value', main.key_value,
						'parent_code', main.parent_code
					)
			   ) INTO v_total_records, v_final_array
		FROM (
			SELECT 
				k.key_code, k.key_value , '' parent_code
			from rfq_kds k
			where k.key_module = v_key_module and k.key_source = v_key_source and k.key_name = v_key_name
			-- and (v_parent_id IS NULL OR key_parent_id = v_parent_id)
			ORDER BY k.sort_order
			LIMIT v_limit OFFSET v_offset
		) main;
    ELSE
		-- Select v_parent_id;
		SELECT count(1),
		JSON_ARRAYAGG(
				JSON_OBJECT(
					-- 'client_id', main.client_id,
					'code', main.key_code,
					'value', main.key_value,
					'parent_code', main.parent_code
				)
		   ) INTO v_total_records, v_final_array
		FROM (
		SELECT 
			k.key_code, k.key_value , p.key_code parent_code
		from rfq_kds k
		left join rfq_kds p on p.kds_id = k.key_parent_id 
		where k.key_module = v_key_module and k.key_source = v_key_source and k.key_name = v_key_name
		and (v_parent_id IS NULL OR k.key_parent_id = v_parent_id)
		ORDER BY k.sort_order
		LIMIT v_limit OFFSET v_offset
		) main;
    END IF;

    -- 4. Construct response wrapper structure 
    SET p_response = JSON_OBJECT(
        'status', 200,
        'message', 'KDS Master Data',
        'payload', JSON_OBJECT(
            'total_records', v_total_records,
            'key_name', v_key_name,
            'master', COALESCE(v_final_array, JSON_ARRAY())
        )
    );



END$$

DELIMITER ;

SET @json_input = '{
    "userid": 8,
    "offset": 0, 
    "limit": 100,
    "search": "",
    "payload": {
        "key_module": "opportunity",
        "key_source": "product",
        "parent_code": "fire",
        "key_name": "product" 
    }
}';
SET @json_input = '{
    "userid": 8,
    "offset": 0, 
    "limit": 100,
    "search": "",
    "payload": {
        "key_module": "opportunity",
        "key_source": "product",
        "parent_code": "",
        "key_name": "product" 
    }
}';
CALL rfq_sp_master_kds(@json_input, @api_response);
SELECT @api_response;