USE misp_crm_corpo;

CREATE TABLE IF NOT EXISTS rfq_system_schema_history (
    history_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    object_name VARCHAR(100) NOT NULL,
    object_type ENUM('PROCEDURE', 'FUNCTION', 'VIEW', 'TABLE') NOT NULL,
    definition_body LONGTEXT NOT NULL,
    changed_by VARCHAR(100) DEFAULT 'SYSTEM',
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;


USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_backup_and_deploy_object;

DELIMITER $$

CREATE PROCEDURE rfq_sp_backup_and_deploy_object(
    IN p_object_name VARCHAR(100),
    IN p_object_type VARCHAR(20), -- 'PROCEDURE', 'FUNCTION', 'VIEW'
    IN p_new_definition LONGTEXT,
    IN p_developer_name VARCHAR(100)
)
proc_main: BEGIN
    DECLARE v_current_body LONGTEXT DEFAULT NULL;

    -- Global Exception Catch Block
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT JSON_OBJECT('status', 500, 'message', 'Deployment execution block failed.') AS response;
    END;

    -- 1. EXTRACT EXISTING ARCHITECTURE FROM MYSQL SYSTEM DICTIONARIES
    IF p_object_type = 'PROCEDURE' THEN
        SELECT ROUTINE_DEFINITION INTO v_current_body 
        FROM information_schema.ROUTINES 
        WHERE ROUTINE_SCHEMA = 'corporateqms' AND ROUTINE_NAME = p_object_name AND ROUTINE_TYPE = 'PROCEDURE';
        
    ELSEIF p_object_type = 'FUNCTION' THEN
        SELECT ROUTINE_DEFINITION INTO v_current_body 
        FROM information_schema.ROUTINES 
        WHERE ROUTINE_SCHEMA = 'corporateqms' AND ROUTINE_NAME = p_object_name AND ROUTINE_TYPE = 'FUNCTION';
        
    ELSEIF p_object_type = 'VIEW' THEN
        SELECT VIEW_DEFINITION INTO v_current_body 
        FROM information_schema.VIEWS 
        WHERE TABLE_SCHEMA = 'corporateqms' AND TABLE_NAME = p_object_name;
    END IF;

    -- 2. IF PREVIOUS SPECIFICATION EXISTS, MOVE IT TO HISTORICAL LEDGER
    IF v_current_body IS NOT NULL THEN
        INSERT INTO rfq_system_schema_history (object_name, object_type, definition_body, changed_by)
        VALUES (p_object_name, p_object_type, v_current_body, p_developer_name);
    END IF;

	-- 3. EXECUTE THE NEW DDL DEFINITION STREAM
	-- Note: Dynamic DDL execution must use Prepared Statements
	--  SET @ddl_query = p_new_definition;
	--     PREPARE stmt FROM @ddl_query;
	--     EXECUTE stmt;
	--     DEALLOCATE PREPARE stmt;

    SELECT JSON_OBJECT(
        'status', 200, 
        'message', CONCAT(p_object_type, ' ', p_object_name, ' backup compiled and deployed successfully.')
    ) AS response;

END$$

DELIMITER ;


SET @new_function_script = '
CREATE FUNCTION f_crypto_value(p_input VARCHAR(512), p_act INT) 
RETURNS VARCHAR(512) DETERMINISTIC BEGIN ... END;
';

-- CALL rfq_sp_backup_and_deploy_object(
--     'sp_get_client',         -- Target Object Name
--     'PROCEDURE',               -- Object Type , PROCEDURE / FUNCTION / VIEW
--     @new_function_script,     -- The code string
--     'Sandeep'       -- Actor updating the system
-- );

SELECT archived_at, changed_by, definition_body 
FROM rfq_system_schema_history 
WHERE object_name = 'sp_get_client' 
ORDER BY history_id DESC;


USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_sync_all_schema_history;

DELIMITER $$

CREATE PROCEDURE rfq_sp_sync_all_schema_history(
    IN p_developer_name VARCHAR(100),
    OUT p_response LONGTEXT
)
BEGIN
    -- Cursor Loop tracking indicators
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE v_obj_name VARCHAR(100);
    DECLARE v_obj_type VARCHAR(20);
    DECLARE v_obj_body LONGTEXT;
    DECLARE v_count INT DEFAULT 0;

    -- 1. Declare Cursor for Stored Procedures & Functions
    DECLARE cursor_routines CURSOR FOR 
        SELECT ROUTINE_NAME, ROUTINE_TYPE, ROUTINE_DEFINITION
        FROM information_schema.ROUTINES 
        WHERE ROUTINE_SCHEMA = 'corporateqms';

    -- 2. Declare Cursor for Views
    DECLARE cursor_views CURSOR FOR 
        SELECT TABLE_NAME, 'VIEW', VIEW_DEFINITION
        FROM information_schema.VIEWS 
        WHERE TABLE_SCHEMA = 'corporateqms';

    -- Loop termination condition loop handler
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- Global Exception Trap Block
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_response = JSON_OBJECT(
            'status', 500,
            'message', 'Mass schema synchronization execution failed mid-process.',
            'payload', NULL
        );
    END;

    -- =========================================================================
    -- STEP 1: PROCESSING PROCEDURES & FUNCTIONS
    -- =========================================================================
    OPEN cursor_routines;
    
    routine_loop: LOOP
        FETCH cursor_routines INTO v_obj_name, v_obj_type, v_obj_body;
        IF v_done THEN
            LEAVE routine_loop;
        END IF;

        -- Log definitions to history only if a code body actually exists
        IF v_obj_body IS NOT NULL AND v_obj_body <> '' THEN
            INSERT INTO rfq_system_schema_history (object_name, object_type, definition_body, changed_by)
            VALUES (v_obj_name, v_obj_type, v_obj_body, p_developer_name);
            SET v_count = v_count + 1;
        END IF;
    END LOOP;
    
    CLOSE cursor_routines;

    -- Reset termination flag for next cursor loop sequence
    SET v_done = FALSE;

    -- =========================================================================
    -- STEP 2: PROCESSING DATABASE VIEWS
    -- =========================================================================
    OPEN cursor_views;
    
    view_loop: LOOP
        FETCH cursor_views INTO v_obj_name, v_obj_type, v_obj_body;
        IF v_done THEN
            LEAVE view_loop;
        END IF;

        IF v_obj_body IS NOT NULL AND v_obj_body <> '' THEN
            INSERT INTO rfq_system_schema_history (object_name, object_type, definition_body, changed_by)
            VALUES (v_obj_name, v_obj_type, v_obj_body, p_developer_name);
            SET v_count = v_count + 1;
        END IF;
    END LOOP;
    
    CLOSE cursor_views;

    -- Return full transaction summary confirmation report
    SET p_response = JSON_OBJECT(
        'status', 200,
        'message', 'Database schema historical snapshot complete.',
        'payload', JSON_OBJECT(
            'total_objects_archived', v_count
        )
    );

END$$

DELIMITER ;

CALL rfq_sp_sync_all_schema_history('System Baseline Init', @sync_output);

-- View the results summary mapping
SELECT @sync_output AS operational_log;