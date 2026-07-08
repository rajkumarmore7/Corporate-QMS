USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_client_approval;

DELIMITER $$

CREATE PROCEDURE rfq_sp_client_approval(
	IN p_userid BIGINT,
    IN p_input_json LONGTEXT, -- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
proc_main: BEGIN
    -- Extracted Parameters
    DECLARE v_userid BIGINT;
    DECLARE v_client_id BIGINT UNSIGNED;
    DECLARE v_client_uuid VARCHAR(90);
    DECLARE v_client_status_code VARCHAR(90);
    DECLARE v_client_reason_code VARCHAR(90);
    DECLARE v_client_remarks VARCHAR(90);
    DECLARE v_owner_id BIGINT;
    DECLARE v_remarks VARCHAR(500);
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
    SET v_userid = p_userid; -- CAST(p_input_json->>'$.userid' AS UNSIGNED); -- Line 42
    SET v_client_uuid = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client_uuid'));

    SET v_client_reason_code = NULLIF(TRIM(p_input_json->>'$.payload.client_reason_code'), '');
    SET v_client_remarks = NULLIF(TRIM(p_input_json->>'$.payload.client_remarks'), '');

    SELECT client_id, client_status_code INTO v_client_id   , v_client_status_code FROM rfq_clients WHERE client_UUID = v_client_uuid LIMIT 1; -- COLLATE utf8mb4_unicode_ci 
    IF(v_client_status_code != "casp") THEN
    SET p_response = JSON_OBJECT(
            'status', 400,
            'message', 'Error: Client status is already chnaged',
            'payload', NULL
        );
        LEAVE proc_main;
    END IF;
    SET v_client_status_code = NULLIF(TRIM(p_input_json->>'$.payload.client_status_code'), '');
    
    IF v_client_id IS NULL THEN
        SET p_response = JSON_OBJECT(
            'status', 400,
            'message', 'Error: Client not found',
            'payload', NULL
        );
        LEAVE proc_main;
    END IF;
   
    -- 2. Client user hierarchy
    -- Select v_userid;
    select o.owner_id INTO v_owner_id  from rfq_clients_owners o where o.client_id = v_client_id and o.active = 1 and o.owner_type_code = 'cooo' limit 1;
    CALL rfq_sp_get_user_hierarchy(v_owner_id, v_hierarchy);
    -- Select v_userid, v_owner_id, JSON_CONTAINS( v_hierarchy,CAST(v_owner_id AS JSON),'$'),v_hierarchy;
	IF ((JSON_CONTAINS( v_hierarchy,CAST(v_userid AS JSON),'$')) = 0 or v_hierarchy is null)
    THEN
        SET p_response = JSON_OBJECT(
            'status',403,
            'error_code',3001,
            'message',
            'Client owner does not belong to your hierarchy',
            'payload',NULL
        );
        LEAVE proc_main;
    END IF;

    -- Guard Clause: Validate correct ownership context rules
    -- Select v_client_status_code;
    IF v_client_status_code NOT IN ('casa', 'casr') THEN
		SET p_response = JSON_OBJECT(
            'status', 401,
            'message', 'Error: Invalid Status Code',
            'payload', NULL
        );
        LEAVE proc_main;
    END IF;

    -- Start Transaction Block
    SET v_in_transaction = TRUE;
    START TRANSACTION;
		Update rfq_clients set approval_id = v_userid, approval_on = now()
		,client_status_code = v_client_status_code
		,client_status_reason = v_client_reason_code
		,client_remarks = v_client_remarks
		where client_UUID = v_client_uuid LIMIT 1;
    COMMIT;
    SET v_in_transaction = FALSE;
	
    -- 4. Construct Success Packet
    SET p_response = JSON_OBJECT(
        'status', 200,
        'message', 'Client status update successfully.',
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