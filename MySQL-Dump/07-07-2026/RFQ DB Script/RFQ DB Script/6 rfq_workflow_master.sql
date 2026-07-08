use misp_crm_corpo;

CREATE TABLE rfq_workflow_master (
    workflow_code VARCHAR(30) NOT NULL,
    workflow_name VARCHAR(100) NOT NULL,
    client_type_code VARCHAR(30) NOT NULL, -- 'MIBL', 'NON_MIBL', etc.
    active BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (workflow_code)
) ENGINE=InnoDB;

CREATE TABLE rfq_workflow_stages_config (
    config_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    workflow_code VARCHAR(30) NOT NULL,
    stage_sequence INT NOT NULL,          -- Execution order index (1, 2, 3...)
    stage_code VARCHAR(50) NOT NULL,      -- 'RFQ_FLOATED', 'QCR_FLOATED', 'CLIENT_REVIEW'
    stage_name VARCHAR(100) NOT NULL,
    display_name VARCHAR(100) NOT NULL, -- Stage Name to be displayed
    sla_days INT NOT NULL,                -- Target allocation window
    FOREIGN KEY (workflow_code) REFERENCES rfq_workflow_master(workflow_code),
    UNIQUE KEY idx_wf_stage_seq (workflow_code, stage_sequence)
) ENGINE=InnoDB;


-- 1. Register the core workflow
INSERT INTO rfq_workflow_master (workflow_code, workflow_name, client_type_code)
VALUES ('MIBL', 'Standard MIBL Corporate Pipeline', 'MIBL'),
('NON_MIBL', 'Standard NON_MIBL Corporate Pipeline', 'NON_MIBL');

-- 2. Map out step sequences and matching SLAs
INSERT INTO rfq_workflow_stages_config (workflow_code, stage_sequence, stage_code, stage_name,display_name, sla_days) 
VALUES
('MIBL', 1, 'OPPORTUNITY',   'Opportunity assignment pending','Opportunity Assignment Pending', 1),
('MIBL', 2, 'RFQ_STAGE',   'RFQ in Progress, FLOATED & Not FLOATED','RFQ in Progress', 3),
('MIBL', 3, 'QCR_STAGE',   'QCR in Progress, FLOATED & Not FLOATED','QCR in Progress', 3),
('MIBL', 4, 'CLIENT_REVIEW', 'Client Evaluation Pending','Client Review ', 5),
('MIBL', 5, 'POLICY_WON',    'Policy Won - Policy  Processing','Opportunity Won', 15),
('MIBL', 6, 'COMPLETED',     'Opportunity Execution Completed','Opportunity Process Completed', 0);


INSERT INTO rfq_kds (key_module, key_source, key_code, key_name, key_value,key_parent_id) VALUES
('opportunity', 'status', 'OPEN', 'status', 'OPEN',null),
('opportunity', 'status', 'WON', 'status', 'WON',null),
('opportunity', 'status', 'COMPLETED', 'status', 'COMPLETED',null),
('opportunity', 'status', 'TERMINATED', 'status', 'TERMINATED',null),
('opportunity', 'status', 'LOSS', 'status', 'LOSS',null),
('opportunity', 'type', 'NEW', 'type', 'New',null),
('opportunity', 'type', 'RENEWAL', 'type', 'Renewal',null),
('opportunity', 'type', 'ROLLOVER', 'type', 'Rollover',null),
('opportunity', 'lob', 'FIRE', 'lob', 'FIRE',null),
('opportunity', 'lob', 'oppmarine', 'lob', 'MARINE',null);

INSERT INTO rfq_kds (key_module, key_source, key_code, key_name, key_value, key_parent_id)
SELECT 'opportunity', 'product', 'oppFIRE', 'product', 'FIRE', kds_id FROM rfq_kds WHERE key_code = 'FIRE' AND key_source = 'lob' LIMIT 1;
INSERT INTO rfq_kds (key_module, key_source, key_code, key_name, key_value, key_parent_id)
SELECT 'opportunity', 'product', 'opppmarine', 'product', 'MARINE', kds_id FROM rfq_kds WHERE key_code = 'oppmarine' AND key_source = 'lob' LIMIT 1;

INSERT INTO rfq_kds (key_module, key_source, key_code, key_name, key_value,key_parent_id) 
SELECT 'opportunity', 'sub_product', 'ossubfire', 'sub_product', 'FIRE', kds_id FROM rfq_kds WHERE key_code = 'oppFIRE' AND key_source = 'product' LIMIT 1;
INSERT INTO rfq_kds (key_module, key_source, key_code, key_name, key_value,key_parent_id) 
SELECT 'opportunity', 'sub_product', 'oppspmarine', 'sub_product', 'MARINE', kds_id FROM rfq_kds WHERE key_code = 'opppmarine' AND key_source = 'product' LIMIT 1;
