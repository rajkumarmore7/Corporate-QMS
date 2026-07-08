CREATE DATABASE IF NOT EXISTS misp_audit_warehouse;
USE misp_audit_warehouse;

CREATE TABLE app_activity_master_log (
    log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    
    -- Who performed the action?
    user_id BIGINT UNSIGNED NOT NULL,
    -- user_name VARCHAR(150) NOT NULL,
    -- user_role_name VARCHAR(100) NOT NULL,
    
    -- Where did it happen?
    module_code varchar(30) not null, -- ENUM('AUTH', 'USER_MANAGEMENT', 'CLIENT', 'OPPORTUNITY', 'WORKFLOW_ENGINE', 'ADMIN_PORTAL') NOT NULL,
    action_type varchar(30) not null, --  ENUM('LOGIN', 'LOGOUT', 'VIEW', 'CREATE', 'UPDATE', 'DELETE', 'ASSIGN', 'STAGE_REVERSION', 'CONFIG_CHANGE') NOT NULL,
    
    -- Target Traceability Identifiers
    reference_id_num BIGINT UNSIGNED DEFAULT NULL,    -- Maps numeric primary keys (e.g. client_id)
    reference_uuid VARCHAR(50) DEFAULT NULL,          -- Maps string UUID wrappers
    
    -- Dynamic State Engine Capture Storage
    changed_payload JSON NOT NULL,                    -- Holds metadata dumps or data deltas
	remarks Varchar(8000) NULL,                    -- User Display Comments
    
    -- Environmental Context Fields
    ip_address VARCHAR(45)  NULL,                 -- Handles both IPv4 and IPv6 layouts
    user_agent VARCHAR(512)  NULL,                 -- Capture browser info/API gateways
    created_on DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Performance Tracking Indices
    KEY idx_user_module_search (user_id, module_code),
    -- KEY idx_timeline_lookup (created_on DESC),
    KEY idx_ref_uuid (reference_uuid)
) ENGINE=InnoDB;


USE misp_audit_warehouse;

CREATE TABLE error_master_ledger (
    error_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    
    -- Source Identification
    layer_source varchar(30)NOT NULL, -- ENUM('JAVA_APPLICATION', 'DATABASE_SP') NOT NULL,
    component_name VARCHAR(255) NOT NULL, -- Name of the Stored Procedure or Java Class/Method
    
    -- Diagnostic Blueprint Parameters
    exception_type VARCHAR(150) DEFAULT NULL, -- SQLState code or Java Exception class name
    error_message  LONGTEXT DEFAULT NULL,              -- Raw error string description
    stack_trace LONGTEXT DEFAULT NULL,        -- Complete Java stack trace or DB diagnostic context
    
    -- Request Tracking & Environment Context
    userid BIGINT UNSIGNED DEFAULT NULL,
    request_payload LONGTEXT DEFAULT NULL,    -- Incoming JSON payload string that triggered the crash
    
    -- ip_address VARCHAR(45) DEFAULT '127.0.0.1',
    created_on DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    KEY idx_source_component (layer_source, component_name)
    -- ,KEY idx_timeline (created_on DESC)
) ENGINE=InnoDB;

USE misp_audit_warehouse;

DROP PROCEDURE IF EXISTS sp_write_activity_log;

DELIMITER $$

CREATE PROCEDURE sp_write_activity_log(
    IN p_user_id BIGINT UNSIGNED,
    -- IN p_user_name VARCHAR(150),
    -- IN p_user_role VARCHAR(100),
    IN p_module_code VARCHAR(30),
    IN p_action_type VARCHAR(30),
    IN p_ref_id BIGINT UNSIGNED,
    IN p_ref_uuid VARCHAR(50),
    IN p_payload JSON,
    IN p_ip VARCHAR(45)
    -- ,IN p_user_agent VARCHAR(512)
)
BEGIN
	Declare p_user_agent VARCHAR(512) default null;

    INSERT INTO app_activity_master_log (
        user_id,   module_code, action_type, 
        reference_id_num, reference_uuid, changed_payload, ip_address, user_agent, created_on
    ) VALUES (
        p_user_id,   p_module_code, p_action_type, 
        p_ref_id, p_ref_uuid, p_payload, p_ip, p_user_agent, NOW()
    );
END$$

DELIMITER ;

USE misp_audit_warehouse;

DROP PROCEDURE IF EXISTS sp_log_database_exception;

DELIMITER $$

CREATE PROCEDURE sp_log_database_exception(
    IN p_component_name VARCHAR(255),
    IN p_sql_state VARCHAR(50),
    IN p_error_message TEXT,
    IN p_userid BIGINT UNSIGNED,
    IN p_payload LONGTEXT
)
BEGIN
    -- Separate block to ensure error tracking updates never interrupt transaction flows
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;

    INSERT INTO misp_audit_warehouse.error_master_ledger (
        layer_source, component_name, exception_type, error_message, 
        stack_trace, userid, request_payload
    ) VALUES (
        'DATABASE_SP', p_component_name, p_sql_state, p_error_message,
        CONCAT('Execution triggered MySQL State exception fallback condition vector: ', p_sql_state),
        p_userid, p_payload
    );
END$$

DELIMITER ;


DROP PROCEDURE IF EXISTS sp_log_app_exception;

DELIMITER $$

CREATE PROCEDURE sp_log_app_exception(
    IN p_component_name VARCHAR(255),
    IN p_app_state VARCHAR(50),
    IN p_error_message TEXT,
    IN p_userid BIGINT UNSIGNED,
    IN p_payload LONGTEXT
)
BEGIN
    -- Separate block to ensure error tracking updates never interrupt transaction flows
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;

    INSERT INTO misp_audit_warehouse.error_master_ledger (
        layer_source, component_name, exception_type, error_message, 
        stack_trace, userid, request_payload
    ) VALUES (
        'Application', p_component_name, p_sql_state, p_error_message,
        p_app_state,
        p_userid, p_payload
    );
END$$

DELIMITER ;