USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_pincode_master;
DROP PROCEDURE IF EXISTS rfq_sp_master_pincode;

DELIMITER $$

CREATE PROCEDURE rfq_sp_master_pincode(
    IN p_input_json LONGTEXT, -- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
BEGIN
    -- Control Variables
    DECLARE v_code VARCHAR(100); 
	DECLARE v_offset INT DEFAULT 0;
    DECLARE v_limit INT DEFAULT 1;
	DECLARE v_total_records INT DEFAULT 1;
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
            'message', CONCAT('Pincode Master Error: ', v_error_msg),
            'payload', NULL
        );
    END;

    -- 1. Extract the key parms from your standard API payload structure
	SET v_code = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.pincode'));
    
	-- 5. Execute Core Paginated Aggregation Query
    SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    -- 'client_id', main.client_id,
                    'pincode', main.pincode,
                    'city_code', main.city_code,
                    'city_name', main.city_name,
                    'state_code', main.state_code,
                    'state_name', main.state_name 
                )
           ) INTO v_final_array
    FROM (
		SELECT p.pincode, p.city_code, p.city_name, p.state_code, p.state_name 
		FROM misp_crm_corpo.rfq_mst_pincode_master p 
		where p.pincode = v_code
		LIMIT v_limit OFFSET v_offset
    ) main;

    -- 4. Construct response wrapper structure 
    SET p_response = JSON_OBJECT(
        'status', 200,
        'message', 'pincode Master Data',
        'payload', JSON_OBJECT(
            'total_records', v_total_records,
            'pincode', COALESCE(v_final_array, JSON_ARRAY())
        )
    );



END$$

DELIMITER ;

SET @json_input = '{
    "userid": 8,
    "search": "",
    "payload": {
        "pincode": "110006"
    }
}';
CALL rfq_sp_master_pincode(@json_input, @api_response);
SELECT @api_response;