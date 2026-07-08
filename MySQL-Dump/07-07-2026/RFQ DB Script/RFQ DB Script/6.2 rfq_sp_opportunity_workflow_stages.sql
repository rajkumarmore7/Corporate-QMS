USE corporateqms;

DROP PROCEDURE IF EXISTS rfq_sp_opportunity_workflow_stages;

DELIMITER $$

CREATE PROCEDURE rfq_sp_opportunity_workflow_stages(
    IN p_input_json LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
proc_main: BEGIN
    -- JSON Parameter Extractions
    DECLARE v_userid BIGINT UNSIGNED;
    DECLARE v_opportunity_UUID VARCHAR(50);
    DECLARE v_target_stage_code VARCHAR(50);
    DECLARE v_direction VARCHAR(20); -- 'FORWARD' or 'BACKWARD'
    DECLARE v_delay_reason VARCHAR(500);
    DECLARE v_reversion_reason VARCHAR(500);
    
    -- Internal State Validation Variables
    DECLARE v_opportunity_id BIGINT UNSIGNED;
    DECLARE v_current_stage_code VARCHAR(50);
    DECLARE v_workflow_code VARCHAR(30);
    DECLARE v_current_history_id BIGINT UNSIGNED;
    DECLARE v_activated_at DATETIME;
    DECLARE v_allowed_sla INT;
    DECLARE v_computed_tat INT;
    
    -- System Exception State Catch Containers
    DECLARE v_sql_state VARCHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- Global Transaction Exception Trap Handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1 v_sql_state = RETURNED_SQLSTATE, v_error_msg = MESSAGE_TEXT;
        SET p_response = JSON_OBJECT('status', 500, 'message', CONCAT('Workflow Engine Exception: ', v_error_msg), 'payload', NULL);
    END;

    -- 1. EXTRACT DATA PATHWAYS FROM API PAYLOAD DOCUMENT
    SET v_userid = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.userId')) AS UNSIGNED);
    SET v_opportunity_UUID = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.opportunity_UUID'));
    SET v_target_stage_code = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.target_stage_code'));
    SET v_direction = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.direction')); -- FORWARD / BACKWARD
    SET v_delay_reason = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.delay_reason'));
    SET v_reversion_reason = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.reversion_reason'));

    -- 2. LOAD OPPORTUNITY CURRENT CORE PARAMETERS
    SELECT opportunity_id, current_stage_code, current_workflow_code
    INTO v_opportunity_id, v_current_stage_code, v_workflow_code
    FROM rfq_opportunity_master
    WHERE opportunity_UUID = v_opportunity_UUID COLLATE utf8mb4_unicode_ci;

    -- Guard Clause: Verify item exists
    IF v_opportunity_id IS NULL THEN
        SET p_response = JSON_OBJECT('status', 404, 'message', 'Target opportunity reference not found.', 'payload', NULL);
        LEAVE proc_main;
    END IF;

    -- 3. RESOLVE RULES TARGET CONFIGURATION SPECIFICATIONS
    SELECT sla_days INTO v_allowed_sla
    FROM rfq_workflow_stages_config
    WHERE workflow_code = v_workflow_code AND stage_code = v_target_stage_code COLLATE utf8mb4_unicode_ci;

    -- Start Atomic Workflow Commits
    START TRANSACTION;

    -- 4. PROCESS CURRENT RUNNING STAGE LOG CLOSURE
    SELECT history_id, stage_activated_at INTO v_current_history_id, v_activated_at
    FROM rfq_opportunity_stage_history
    WHERE opportunity_id = v_opportunity_id AND active_iteration_flag = TRUE;

    IF v_current_history_id IS NOT NULL THEN
        SET v_computed_tat = DATEDIFF(NOW(), v_activated_at);
        
        -- Guard Block: Enforce mandatory Delay Reason if Forward path breaches SLA limits
        IF v_direction = 'FORWARD' AND v_computed_tat > v_allowed_sla AND (v_delay_reason IS NULL OR TRIM(v_delay_reason) = '') THEN
            ROLLBACK;
            SET p_response = JSON_OBJECT('status', 422, 'message', CONCAT('SLA Breach Alert: This step exceeded its limit by ', v_computed_tat, ' days. A delay_reason is required to proceed.'), 'payload', NULL);
            LEAVE proc_main;
        END IF;

        -- Close out current history row entry
        UPDATE rfq_opportunity_stage_history
        SET stage_processed_at = NOW(),
            actual_tat_days = v_computed_tat,
            sla_compliance = CASE WHEN v_computed_tat <= allowed_sla_days THEN 'WITHIN_TAT' ELSE 'BREACHED' END,
            delay_reason = v_delay_reason,
            active_iteration_flag = FALSE -- Archived out of live focus loop
        WHERE history_id = v_current_history_id;
    END IF;

    -- 5. APPLY ROUTING DIRECTIVES (FORWARD VS BACKWARD)
    IF v_direction = 'BACKWARD' THEN
        -- Guard Block: Enforce explanation description for regression steps
        IF v_reversion_reason IS NULL OR TRIM(v_reversion_reason) = "" THEN
            ROLLBACK;
            SET p_response = JSON_OBJECT('status', 422, 'message', 'Validation Error: Moving an opportunity backward requires a reversion_reason.', 'payload', NULL);
            LEAVE proc_main;
        END IF;
    END IF;

    -- 6. RECORD NEW SYSTEM STEP ROW ENTRY
    INSERT INTO rfq_opportunity_stage_history (
        opportunity_id, stage_code, direction_moved, stage_activated_at, 
        allowed_sla_days, reversion_reason, processed_by, active_iteration_flag
    ) VALUES (
        v_opportunity_id, v_target_stage_code, v_direction, NOW(), 
        v_allowed_sla, v_reversion_reason, v_userid, TRUE
    );

    -- 7. UPDATE PRIMARY HEAD DATA MATRIX STATE
    UPDATE rfq_opportunity_master
    SET current_stage_code = v_target_stage_code,
        opportunity_status = CASE 
            WHEN v_target_stage_code = 'POLICY_WON' THEN 'WON' 
            WHEN v_target_stage_code = 'COMPLETED' THEN 'COMPLETED' 
            ELSE 'OPEN' 
        END
    WHERE opportunity_id = v_opportunity_id;

    COMMIT;

    -- Return success confirmation
    SET p_response = JSON_OBJECT(
        'status', 200,
        'message', CONCAT('Opportunity transitioned to ', v_target_stage_code, ' successfully.'),
        'payload', JSON_OBJECT('opportunity_id', v_opportunity_id, 'direction_applied', v_direction)
    );

END$$

DELIMITER ;


-- CREATE OR REPLACE VIEW v_rfq_opportunity_performance_report AS
SELECT 
    m.opportunity_UUID,
    m.product_name,
    m.expected_premium,
    m.opportunity_status AS final_outcome,
    
    -- RFQ STAGE LOGS METRICS
    rfq.stage_activated_at AS rfq_date,
    rfq.stage_processed_at AS rfq_floated_date,
    rfq.actual_tat_days AS rfq_tat_in_days,
    rfq.sla_compliance AS rfq_ageing,
    rfq.delay_reason AS rfq_delay_remark,
    
    -- QCR STAGE LOGS METRICS
    qcr.stage_activated_at AS qcr_date,
    qcr.stage_processed_at AS qcr_floated_date,
    qcr.actual_tat_days AS qcr_tat_in_days,
    qcr.sla_compliance AS qcr_ageing,
    qcr.delay_reason AS qcr_delay_remark,
    
    -- POLICY TRACKING METRICS
    pol.stage_activated_at AS policy_won_date,
    pol.stage_processed_at AS policy_issued_date,
    pol.actual_tat_days AS policy_tat_in_days,
    pol.sla_compliance AS policy_ageing,
    
    m.final_policy_no,
    m.final_premium
FROM rfq_opportunity_master m
-- Pull the latest forward execution loop metrics for the RFQ stage
LEFT JOIN rfq_opportunity_stage_history rfq 
    ON rfq.opportunity_id = m.opportunity_id AND rfq.stage_code = 'RFQ_FLOATED' AND rfq.direction_moved = 'FORWARD'
-- Pull the latest forward execution loop metrics for the QCR stage
LEFT JOIN rfq_opportunity_stage_history qcr 
    ON qcr.opportunity_id = m.opportunity_id AND qcr.stage_code = 'QCR_FLOATED' AND qcr.direction_moved = 'FORWARD'
-- Pull the latest forward execution loop metrics for the Policy Issuance stage
LEFT JOIN rfq_opportunity_stage_history pol 
    ON pol.opportunity_id = m.opportunity_id AND pol.stage_code = 'POLICY_WON';