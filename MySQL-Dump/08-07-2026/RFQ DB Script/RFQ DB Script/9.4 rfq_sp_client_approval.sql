USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_client_approval;

DELIMITER $$

CREATE PROCEDURE rfq_sp_client_approval(
    IN p_userid BIGINT,
    IN p_input_json LONGTEXT,
    OUT p_response LONGTEXT
)
proc_main: BEGIN
    -- Extracted Parameters
    DECLARE v_userid BIGINT;
    DECLARE v_client_id BIGINT UNSIGNED;
    DECLARE v_client_uuid VARCHAR(90);
    DECLARE v_client_status_code VARCHAR(90);
    DECLARE v_new_status_code VARCHAR(90);
    DECLARE v_client_reason_code VARCHAR(90);
    DECLARE v_client_remarks VARCHAR(90);
    DECLARE v_owner_id BIGINT;
    DECLARE v_hierarchy JSON;
    
    -- System Error Capture Variables
    DECLARE v_sql_state VARCHAR(50) DEFAULT '00000';
    DECLARE v_error_msg TEXT;
    DECLARE v_in_transaction BOOLEAN DEFAULT FALSE;

    -- Global Exception Trap Handler (Auto-Rollback enabled)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_in_transaction THEN
            ROLLBACK;
        END IF;
        GET DIAGNOSTICS CONDITION 1 
            v_sql_state = RETURNED_SQLSTATE, 
            v_error_msg = MESSAGE_TEXT;

        SET p_response = JSON_OBJECT(
            'status', 500,
            'message', CONCAT('Error: ', v_error_msg),
            'payload', NULL
        );
    END;

    -- 1. Extract Mapping Elements from JSON
    SET v_userid = p_userid;
    SET v_client_uuid = NULLIF(TRIM(p_input_json->>'$.payload.client_uuid'), '');
    SET v_client_reason_code = NULLIF(TRIM(p_input_json->>'$.payload.client_reason_code'), '');
    SET v_client_remarks = NULLIF(TRIM(p_input_json->>'$.payload.client_remarks'), '');
    SET v_new_status_code = NULLIF(TRIM(p_input_json->>'$.payload.client_status_code'), '');

    -- Initial Validation Gate: Target incoming status validation
    IF v_new_status_code NOT IN ('casa', 'casr') THEN
        SET p_response = JSON_OBJECT(
            'status', 400,
            'message', 'Error: Invalid Status Code Passed',
            'payload', NULL
        );
        LEAVE proc_main;
    END IF;

    -- Fetch current profile data using indexed UUID lookup
    SELECT client_id, client_status_code 
    INTO v_client_id, v_client_status_code 
    FROM rfq_clients 
    WHERE client_UUID = v_client_uuid 
    LIMIT 1;
    
    -- Guard Clause: Profile Existence Check
    IF v_client_id IS NULL THEN
        SET p_response = JSON_OBJECT(
            'status', 400,
            'message', 'Error: Client not found',
            'payload', NULL
        );
        LEAVE proc_main;
    END IF;
    
    -- Guard Clause: Concurrency check ensuring baseline is still pending ('casp')
    IF (v_client_status_code != 'casp') THEN
        SET p_response = JSON_OBJECT(
            'status', 400,
            'message', 'Error: Client status has already changed',
            'payload', NULL
        );
        LEAVE proc_main;
    END IF;

    -- 2. Validate User Hierarchy Permissions
    SELECT o.owner_id INTO v_owner_id  
    FROM rfq_clients_owners o 
    WHERE o.client_id = v_client_id 
      AND o.active = 1 
      AND o.owner_type_code = 'cooo' 
    LIMIT 1;
    
    CALL rfq_sp_get_user_hierarchy(v_owner_id, v_hierarchy);
	Select v_userid, v_owner_id, JSON_CONTAINS( v_hierarchy,CAST(v_owner_id AS JSON),'$'),v_hierarchy;
    IF (v_hierarchy IS NULL OR JSON_CONTAINS(v_hierarchy, CAST(v_userid AS JSON), '$') = 0) THEN
        SET p_response = JSON_OBJECT(
            'status', 403,
            'error_code', 3001,
            'message', 'Client owner does not belong to your hierarchy',
            'payload', NULL
        );
        LEAVE proc_main;
    END IF;

    -- 3. Execute Write Transaction (Optimized using Primary Key lookup)
    SET v_in_transaction = TRUE;
    START TRANSACTION;
        
        UPDATE rfq_clients 
        SET approval_id = v_userid, 
            approval_on = NOW(),
            client_status_code = v_new_status_code,
            client_status_reason = v_client_reason_code,
            client_remarks = v_client_remarks
        WHERE client_id = v_client_id; -- Much faster and safer index lock than string UUID lookup
        
    COMMIT;
    SET v_in_transaction = FALSE;
    
    -- 4. Construct Success Packet
    SET p_response = JSON_OBJECT(
        'status', 200,
        'message', 'Client status updated successfully.',
        'payload', JSON_OBJECT(
            'client_uuid', v_client_uuid
        )
    );
    
END$$

DELIMITER ;

update rfq_clients set client_status_code = 'casp' where client_id = 2;
SET @json_owner1 = '{
    "userid": 171,
    "payload": {
        "client_uuid": "140676468d57b9Q7450Q11f1Qb0eeQc018507ef9d5",
        "client_status_code": "casa",
        "client_reason_code": "",
        "client_remarks": ""
    }
}';

CALL rfq_sp_client_approval(71,@json_owner1, @response); -- 88
SELECT @response;