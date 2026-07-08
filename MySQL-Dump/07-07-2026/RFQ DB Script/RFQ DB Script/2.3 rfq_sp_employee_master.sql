USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_employee_master;
DROP PROCEDURE IF EXISTS rfq_sp_master_employee;

DELIMITER $$

CREATE PROCEDURE rfq_sp_master_employee(
    IN p_input_json LONGTEXT, -- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
BEGIN
    -- Control Variables
    DECLARE v_employee_code VARCHAR(100); 
	DECLARE v_offset INT DEFAULT 0;
    DECLARE v_limit INT DEFAULT 100;
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
            'message', CONCAT('Employee Master Error: ', v_error_msg),
            'payload', NULL
        );
    END;

    -- 1. Extract the key parms from your standard API payload structure
	SET v_employee_code = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.employee_code'));
    
	-- 5. Execute Core Paginated Aggregation Query
    SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    -- 'client_id', main.client_id,
                    'employee_code', main.employee_code,
                    'employee_name', main.employee_name,
                    'branch_code', main.branch_code,
                    'branch_name', main.branch_name,
                    'employee_mobile', main.mobile,
                    'employee_email', main.email,
                    'manager_employee_code', main.manager_employee_code,
                    'manager_employee_name', main.manager_employee_name,
                    'manager_mobile', main.manager_mobile,
                    'manager_email', main.manager_email
                )
           ) INTO v_final_array
    FROM (
		SELECT e.user_id as employee_code, e.employee_name, e.branch_code, e.branch_name, e.mobile, e.email 
		,r.user_id as manager_employee_code
		,r.employee_name as manager_employee_name
		,r.mobile as manager_mobile
		,r.email as manager_email
		FROM misp_crm_corpo.rfq_mst_employee_master e 
		left join misp_crm_corpo.rfq_mst_employee_master r on e.reporting_manager = r.user_id
		where e.user_id	 = v_employee_code
        -- LIMIT v_limit OFFSET v_offset
    ) main;

    -- 4. Construct response wrapper structure 
    SET p_response = JSON_OBJECT(
        'status', 200,
        'message', 'Employee Master Data',
        'payload', JSON_OBJECT(
            'total_records', v_total_records,
            'employee', COALESCE(v_final_array, JSON_ARRAY())
        )
    );



END$$

DELIMITER ;

SET @json_input = '{
    "userid": 8,
    "search": "",
    "payload": {
        "employee_code": "27050967"
    }
}';
CALL rfq_sp_master_employee(@json_input, @api_response);
SELECT @api_response;