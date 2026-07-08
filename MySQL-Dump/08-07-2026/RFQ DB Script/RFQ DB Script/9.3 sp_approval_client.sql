USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_client_owners;

DELIMITER $$

CREATE PROCEDURE rfq_sp_client_owners(
    IN p_input_json LONGTEXT, -- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
proc_main: BEGIN
    -- Extracted Parameters
    DECLARE v_userid BIGINT;
    DECLARE v_client_id BIGINT UNSIGNED;
    DECLARE v_owner_id BIGINT UNSIGNED; -- The user being assigned as owner
    DECLARE v_owner_type_code VARCHAR(30); -- 'cooo' (Owner) or 'cooc' (Co-Owner)
    DECLARE v_client_uuid VARCHAR(90); -- 'cooo' (Owner) or 'cooc' (Co-Owner)
    DECLARE v_remarks VARCHAR(500);

    -- System Error Capture Variables
    DECLARE v_sql_state VARCHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- Global Exception Trap Handler (Auto-Rollback enabled)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1 
            v_sql_state = RETURNED_SQLSTATE, 
            v_error_msg = MESSAGE_TEXT;

        SET p_response = JSON_OBJECT(
            'status', 500,
            'message', CONCAT('Ownership Transaction Failed: ', v_error_msg),
            'payload', NULL
        );
    END;

    -- 1. Extract Mapping Elements from JSON
    SET v_userid = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.userid')) AS UNSIGNED);
    -- SET v_client_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client_id')) AS UNSIGNED);
    SET v_owner_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.owner_id')) AS UNSIGNED);
    SET v_owner_type_code = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.owner_type_code'));
     
	SET v_client_uuid = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client_uuid'));
    
    SET v_remarks = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.status_remarks'));
    
     
    SELECT client_id INTO v_client_id  
    FROM rfq_clients  
    WHERE client_UUID = v_client_uuid -- COLLATE utf8mb4_unicode_ci
    LIMIT 1;

    -- Guard Clause: Validate correct ownership context rules
    IF v_owner_type_code NOT IN ('cooo', 'cooc') THEN
        SET p_response = JSON_OBJECT(
            'status', 400,
            'message', 'Validation Failed: Invalid owner_type_code supplied. Must be cooo or cooc.',
            'payload', NULL
        );
        LEAVE proc_main;
    END IF;

    -- Start Transaction Block
    START TRANSACTION;
	  
    -- 2. BUSINESS RULE ROUTING
    IF v_owner_type_code = 'cooo' THEN
        -- Rule: A client can have only ONE primary owner active at a time.
        -- Deactivate any previous primary owner entries for this client.
        UPDATE rfq_clients_owners 
        SET active = FALSE 
        WHERE client_id = v_client_id 
          AND owner_type_code = 'cooo' 
          AND active = TRUE;

    ELSEIF v_owner_type_code = 'cooc' THEN
        -- Rule: Multiples allowed, but let's avoid duplicating the exact same active co-owner.
        UPDATE rfq_clients_owners
        SET active = FALSE 
        WHERE client_id = v_client_id
          AND owner_id = v_owner_id
          AND owner_type_code = 'cooc'
          AND active = TRUE;
    END IF;
select v_client_id,v_owner_id,v_owner_type_code,v_remarks,v_userid, v_client_uuid;
    -- 3. INSERT THE NEW OWNER ASSIGNMENT
    -- Assumes table structures match your corporate baseline conventions
    INSERT INTO rfq_clients_owners (
        client_id,
        owner_id,
        owner_type_code,
		-- status_remarks,
        active,
        created_id
    ) 
    VALUES (
        v_client_id,
        v_owner_id,
        v_owner_type_code,
       -- v_remarks,
        TRUE, -- Marked as active
        v_userid
    );

    COMMIT;
select v_client_uuid, 'client_uuid';
    -- 4. Construct Success Packet
    SET p_response = JSON_OBJECT(
        'status', 200,
        'message', 'Ownership matrix updated and archived successfully.',
        'payload', JSON_OBJECT(
            'client_id', v_client_id,
            'active_owner_type', v_owner_type_code
        )
    );

END$$

DELIMITER ;


SET @json_owner1 = '{
    "userid": 8,
    "payload": {
        "client_uuid": "645876468c7351Q7450Q11f1Qb0eeQc018507ef9d5",
        "client_status_code": "",
        "client_status_remarks": "",
        "owner_id": 8,
        "owner_type_code": "cooo",
        "status_remarks": "Initial Primary Owner Assignment"
    }
}';

CALL rfq_sp_client_owners(@json_owner1, @response);
SELECT @response;