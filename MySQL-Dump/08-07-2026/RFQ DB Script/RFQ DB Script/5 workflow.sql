use misp_crm_corpo;

CREATE TABLE workflow_stages (
    stage_id INT PRIMARY KEY AUTO_INCREMENT,
    stage_name VARCHAR(100) NOT NULL,            -- e.g., 'RFQ In Progress', 'QCR Floated'
    actor_type VARCHAR(50) NOT NULL,             -- e.g., 'Sales RM', 'Placement RM', 'System'
    default_tat_days INT DEFAULT 0,              -- Default TAT for this specific stage
    is_terminal_stage BOOLEAN DEFAULT FALSE      -- True for 'Won', 'Lost', 'Opportunity Closed'
);

CREATE TABLE workflow_matrix (
    transition_id INT PRIMARY KEY AUTO_INCREMENT,
    current_stage_id INT,
    next_stage_id INT,
    FOREIGN KEY (current_stage_id) REFERENCES workflow_stages(stage_id),
    FOREIGN KEY (next_stage_id) REFERENCES workflow_stages(stage_id)
);


CREATE TABLE opportunities (
    opportunity_id INT PRIMARY KEY AUTO_INCREMENT,
    client_name VARCHAR(255) NOT NULL,
    current_stage_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (current_stage_id) REFERENCES workflow_stages(stage_id)
);


CREATE TABLE opportunity_workflow_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    opportunity_id INT,
    stage_id INT,
    actor_user_id INT,                           -- The actual employee who processed it
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,                 -- Filled when stage changes
    tat_days_allocated INT,                      -- Snapshotted from workflow_stages at start time
    stage_status VARCHAR(50),                    -- 'Completed', 'Delayed', 'Pending'
    delay_reason TEXT NULL,                      -- Capture 'Delay Reason' from image.png
    remarks TEXT NULL,                           -- Capture general remarks
    FOREIGN KEY (opportunity_id) REFERENCES opportunities(opportunity_id),
    FOREIGN KEY (stage_id) REFERENCES workflow_stages(stage_id)
);


INSERT INTO workflow_stages (stage_id, stage_name, actor_type, default_tat_days, is_terminal_stage) VALUES
(1, 'Client/Portfolio Created', 'Sales RM', 1, FALSE),
(2, 'Opportunity Assignment to Placement RM', 'System', 0, FALSE),
(3, 'RFQ In Progress', 'System', 0, FALSE),
(4, 'RFQ Floated', 'Placement RM', 3, FALSE),
(5, 'Won', 'Placement RM', 2, TRUE),
(6, 'Lost', 'Placement RM', 0, TRUE);


INSERT INTO workflow_matrix (current_stage_id, next_stage_id) VALUES
(1, 2), -- Created -> Assigned
(2, 3), -- Assigned -> RFQ In Progress
(3, 4), -- RFQ In Progress -> RFQ Floated
(4, 5), -- RFQ Floated -> Won
(4, 6); -- RFQ Floated -> Lost (Alternative branch)


INSERT INTO opportunities (opportunity_id, client_name, current_stage_id) VALUES
(101, 'Alpha Corp', 4),       -- Currently stuck on "RFQ Floated"
(102, 'Beta Industries', 5);  -- Successfully made it to "Won"


INSERT INTO opportunity_workflow_logs 
(opportunity_id, stage_id, actor_user_id, started_at, completed_at, tat_days_allocated, stage_status, delay_reason, remarks) 
VALUES
-- --- LEAD 101: ALPHA CORP (IN-PROGRESS & BREACHED) ---
-- Step 1: Created on June 10, completed same day (Within TAT)
(101, 1, 901, '2026-06-10 10:00:00', '2026-06-10 14:00:00', 1, 'Completed', NULL, 'Initial client setup done'),

-- Step 2: Auto Assigned by system instantly
(101, 2, 0, '2026-06-10 14:00:00', '2026-06-10 14:00:05', 0, 'Completed', NULL, 'System Route'),

-- Step 3: RFQ In Progress started instantly, passed to Placement RM same day
(101, 3, 0, '2026-06-10 14:00:05', '2026-06-10 17:30:00', 0, 'Completed', NULL, 'System triggered processing'),

-- Step 4: RFQ Floated started June 10. It has a 3-day TAT. 
-- It is now June 18 and it is STILL NULL (incomplete). This will trigger a breach alert!
(101, 4, 902, '2026-06-10 17:30:00', NULL, 3, 'Pending', NULL, 'Waiting for underwriter quotes'),


-- --- LEAD 102: BETA INDUSTRIES (COMPLETED SUCCESSFULLY) ---
-- Step 1: Created on June 15, completed next day (Within TAT)
(102, 1, 901, '2026-06-15 09:00:00', '2026-06-16 09:00:00', 1, 'Completed', NULL, 'High priority client account'),

-- Step 2 & 3: Fast-tracked system milestones
(102, 2, 0, '2026-06-16 09:00:00', '2026-06-16 09:01:00', 0, 'Completed', NULL, 'Auto assigned'),
(102, 3, 0, '2026-06-16 09:01:00', '2026-06-16 11:00:00', 0, 'Completed', NULL, 'Market clear'),

-- Step 4: RFQ Floated on June 16, Closed on June 17 (Took 1 day out of 3 allocated. Safe!)
(102, 4, 902, '2026-06-16 11:00:00', '2026-06-17 11:00:00', 3, 'Completed', NULL, 'Quotes received quickly'),

-- Step 5: Marked Won on June 17
(102, 5, 902, '2026-06-17 11:00:00', '2026-06-17 15:00:00', 2, 'Completed', NULL, 'Closed won by Placement team');





SELECT 
    o.opportunity_id,
    o.client_name,
    s.stage_name,
    s.actor_type,
    log.started_at,
    log.tat_days_allocated,
    DATEDIFF(NOW(), log.started_at) AS days_elapsed,
    CASE 
        WHEN DATEDIFF(NOW(), log.started_at) > log.tat_days_allocated THEN 'BREACHED'
        ELSE 'WITHIN TAT'
    END AS tat_status
FROM opportunity_workflow_logs log
JOIN opportunities o ON log.opportunity_id = o.opportunity_id
JOIN workflow_stages s ON log.stage_id = s.stage_id
WHERE log.completed_at IS NULL; -- Only look at active, uncompleted stages