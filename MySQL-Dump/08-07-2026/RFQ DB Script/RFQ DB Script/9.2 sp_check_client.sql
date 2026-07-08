USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_check_client;

DELIMITER $$

CREATE PROCEDURE rfq_sp_check_client(
    IN p_input_json LONGTEXT, -- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
BEGIN
    -- Control Variables
    DECLARE v_incoming_name VARCHAR(255);
    DECLARE v_cleaned_incoming VARCHAR(255);
    DECLARE v_match_count INT DEFAULT 0;
    DECLARE v_matched_payload JSON;

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
            'message', CONCAT('Duplicate Check Engine Error: ', v_error_msg),
            'payload', NULL
        );
    END;

    -- 1. Extract the proposed client name from your standard API payload structure
    SET v_incoming_name = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client.client_name'));
    
    -- 2. Process incoming name through cleaning machine
    SET v_cleaned_incoming = rfq_f_clean_names(v_incoming_name);

	-- select v_cleaned_incoming, CONCAT('%', v_cleaned_incoming, '%');
    -- 3. Query the database checking for matching normalized baselines
		SELECT COUNT(*),
		JSON_ARRAYAGG(
		   JSON_OBJECT(
			   'client_UUID', client_UUID,
			   'client_name', client_name,
			   'client_code', client_code,
			   'owner_name', client_type_code,
                'co_owner_name', client_owner
		   )
		) 
        INTO v_match_count, v_matched_payload
		FROM (
		SELECT client_UUID, client_name, client_type_code, client_vertical_code, client_owner, client_code
		FROM v_rfq_clients
		WHERE client_name LIKE CONCAT('%', v_cleaned_incoming, '%')
		LIMIT 10
		) t; -- like v_cleaned_incoming; -- COLLATE utf8mb4_unicode_ci;

    -- 4. Construct JSON warning response block if matched
    IF v_match_count > 0 THEN
        SET p_response = JSON_OBJECT(
            'status', 200, -- 409 Conflict status code standard
            'message', 'Duplicate warning: A similar client configuration already exists.',
            'payload', v_matched_payload
        );
    ELSE
        -- No duplicate found. Safe to proceed!
        SET p_response = JSON_OBJECT(
            'status', 200,
            'message', 'Validation passed. Name is unique.',
            'payload', NULL
        );
    END IF;

END$$

DELIMITER ;

SET @json_input = '{"userid": 8,"payload": {"client": {"client_name": "mahindra"}}}';
CALL rfq_sp_check_client(@json_input, @api_response);
SELECT @api_response;