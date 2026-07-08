use misp_crm_corpo;

DROP TABLE IF EXISTS rfq_portfolio_data;
DROP TABLE IF EXISTS rfq_portfolio_owners;
DROP TABLE IF EXISTS rfq_opportunity_data;
DROP TABLE IF EXISTS rfq_opportunity_owners;
DROP TABLE IF EXISTS rfq_opportunity_workflow_stages;
DROP TABLE IF EXISTS rfq_opportunity;
DROP TABLE IF EXISTS rfq_portfolio;

CREATE TABLE rfq_portfolio (
    portfolio_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    portfolio_UUID VARCHAR(90) NOT NULL,
    client_id BIGINT UNSIGNED NOT NULL,
    portfolio_type_code VARCHAR(30) NOT NULL,     -- KDS opportunity type ( New, Renewal)

    -- Creation Phase Specifications
    portfolio_lob_code VARCHAR(100)  NULL,  -- KDS opportunity lob
    portfolio_product_code VARCHAR(100)  NULL,  -- KDS opportunity product
    portfolio_sub_product_code VARCHAR(100)  NULL,  -- KDS opportunity sub_product
    expected_premium DECIMAL(15,2) NOT NULL,
    brokerage_fee DECIMAL(15,2) NOT NULL,
    reward_fee DECIMAL(15,2) NOT NULL,
    renewal_date DATE DEFAULT NULL,

    -- assigned_placement_rm BIGINT UNSIGNED DEFAULT NULL,
    created_by BIGINT UNSIGNED NOT NULL,
    created_on DATETIME DEFAULT CURRENT_TIMESTAMP,
    modified_by BIGINT UNSIGNED NOT NULL,
    modified_on DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE KEY idx_rfq_portfolio_uuid (portfolio_UUID),
    CONSTRAINT `fk_rfq_portfolio_client_id` FOREIGN KEY (`client_id`) REFERENCES `rfq_clients` (`client_id`) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE rfq_portfolio_data (
  `rfq_portfolio_data_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `portfolio_id` BIGINT UNSIGNED NOT NULL,
  `portfolio_payload` JSON NOT NULL,
  `version` INT DEFAULT 1,
  `updated_id` BIGINT NULL,
  `updated_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`rfq_portfolio_data_id`),
  KEY `idx_rfq_portfolio_data_opportunity_id` (`portfolio_id`),
  CONSTRAINT `rfq_portfolio_data_opportunity_id` FOREIGN KEY (`portfolio_id`) REFERENCES `rfq_portfolio` (`portfolio_id`) ON DELETE CASCADE,
  CONSTRAINT `chk_rfq_portfolio_data_json_valid` CHECK (JSON_VALID(`portfolio_payload`))
) ENGINE=InnoDB; -- DEFAULT CHARSET=utf8mb4;

CREATE TABLE `rfq_portfolio_owners` (
  `rfq_portfolio_owner_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `portfolio_id` BIGINT UNSIGNED NOT NULL,
  `owner_id` BIGINT UNSIGNED NOT NULL,
  `owner_type_code` VARCHAR(30) NOT NULL, -- PRIMARY & Co Owner
  `created_id` BIGINT NULL,
  `created_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_id` BIGINT NULL,
  `updated_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`rfq_portfolio_owner_id`),
  KEY `idx_rfq_portfolio_owners_opportunity_id` (`portfolio_id`),
  KEY `idx_rfq_portfolio_owners_user_id` (`owner_id`),
  CONSTRAINT `fk_rfq_portfolio_owners_portfolio_id` FOREIGN KEY (`portfolio_id`) REFERENCES `rfq_portfolio` (`portfolio_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rfq_portfolio_owners_kds` FOREIGN KEY (`owner_type_code`) REFERENCES `rfq_kds` (`key_code`)
) ENGINE=InnoDB; -- DEFAULT CHARSET=utf8mb4;

CREATE TABLE rfq_opportunity (
    opportunity_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    opportunity_UUID VARCHAR(90) NOT NULL,
    
    client_id BIGINT UNSIGNED NOT NULL,
    portfolio_id BIGINT UNSIGNED NOT NULL,
    
    opportunity_type_code VARCHAR(30) NOT NULL,     -- KDS opportunity type ( New, Renewal)
    opportunity_status_code varchar (30) DEFAULT 'OPEN', -- KDS opportunity status
    opportunity_stage_code varchar (30) DEFAULT 'OPPORTUNITY', -- rfq_workflow_stages_config

    -- Creation Phase Specifications
    opportunity_lob_code VARCHAR(100) NOT NULL,  -- KDS opportunity lob
    opportunity_product_code VARCHAR(100) NOT NULL,  -- KDS opportunity product
    opportunity_sub_product_code VARCHAR(100) NOT NULL,  -- KDS opportunity sub_product
    expected_premium DECIMAL(15,2) NOT NULL,
    brokerage_fee DECIMAL(15,2) NOT NULL,
    reward_fee DECIMAL(15,2) NOT NULL,
    renewal_date DATE DEFAULT NULL,
    
    -- Legacy Insurance Fallbacks (Conditional Mandatory)
    -- prev_policy_no VARCHAR(100) DEFAULT NULL,
    -- prev_policy_end_date DATE DEFAULT NULL,
    -- prev_insurer_name VARCHAR(100) DEFAULT NULL,
    
    -- Resolution Specifications (Captured upon Winning State)
    -- final_policy_no VARCHAR(100) DEFAULT NULL,
    -- final_premium DECIMAL(15,2) DEFAULT NULL,
    -- final_brokerage DECIMAL(15,2) DEFAULT NULL,
    -- final_policy_end_date DATE DEFAULT NULL,

    -- assigned_placement_rm BIGINT UNSIGNED DEFAULT NULL,
    created_by BIGINT UNSIGNED NOT NULL,
    created_on DATETIME DEFAULT CURRENT_TIMESTAMP,
    modified_by BIGINT UNSIGNED NOT NULL,
    modified_on DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE KEY idx_rfq_opportunity_uuid (opportunity_UUID),
  KEY `idx_rfq_opportunity_portfolio_id` (`portfolio_id`),
  KEY `idx_rfq_opportunity_client_id` (`client_id`),
  CONSTRAINT `fk_rfq_opportunity_portfolio_id` FOREIGN KEY (`portfolio_id`) REFERENCES `rfq_portfolio` (`portfolio_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rfq_opportunity_client_id` FOREIGN KEY (`client_id`) REFERENCES `rfq_clients` (`client_id`) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE rfq_opportunity_data (
  `rfq_opportunity_data_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `opportunity_id` BIGINT UNSIGNED NOT NULL,
  `opportunity_payload` JSON NOT NULL,
  `version` INT DEFAULT 1,
  `updated_id` BIGINT NULL,
  `updated_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`rfq_opportunity_data_id`),
  KEY `idx_rfq_opportunity_data_opportunity_id` (`opportunity_id`),
  CONSTRAINT `fk_rfq_opportunity_data_opportunity_id` FOREIGN KEY (`opportunity_id`) REFERENCES `rfq_opportunity` (`opportunity_id`) ON DELETE CASCADE,
  CONSTRAINT `chk_rfq_opportunity_data_json_valid` CHECK (JSON_VALID(`opportunity_payload`))
) ENGINE=InnoDB; -- DEFAULT CHARSET=utf8mb4;

CREATE TABLE `rfq_opportunity_owners` (
  `rfq_opportunity_owner_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `opportunity_id` BIGINT UNSIGNED NOT NULL,
  `owner_id` BIGINT UNSIGNED NOT NULL,
  `owner_type_code` VARCHAR(30) NOT NULL, -- PRIMARY & Co Owner
  `created_id` BIGINT NULL,
  `created_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_id` BIGINT NULL,
  `updated_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`rfq_opportunity_owner_id`),
  KEY `idx_rfq_opportunity_owners_opportunity_id` (`opportunity_id`),
  KEY `idx_rfq_opportunity_owners_user_id` (`owner_id`),
  CONSTRAINT `fk_rfq_opportunity_owners_opportunity_id` FOREIGN KEY (`opportunity_id`) REFERENCES `rfq_opportunity` (`opportunity_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rfq_opportunity_owners_kds` FOREIGN KEY (`owner_type_code`) REFERENCES `rfq_kds` (`key_code`)
) ENGINE=InnoDB; -- DEFAULT CHARSET=utf8mb4;


CREATE TABLE rfq_opportunity_workflow_stages(
    opportunity_workflow_stages_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    opportunity_id BIGINT UNSIGNED NOT NULL,
    stage_code VARCHAR(50) NOT NULL,
    direction_moved ENUM('FORWARD', 'BACKWARD', 'INITIAL') DEFAULT 'FORWARD',
    
    stage_start_at DATETIME NOT NULL,  -- Baseline SLA starting tick
    stage_end_at DATETIME DEFAULT NULL, -- Timestamp when actor submits phase
    
    allowed_sla_days INT NOT NULL,
    actual_tat_days INT DEFAULT NULL,
    sla_compliance ENUM('WITHIN_TAT', 'BREACHED', 'PENDING') DEFAULT 'PENDING',
    
    delay_reason VARCHAR(500) DEFAULT NULL,
    reversion_reason VARCHAR(500) DEFAULT NULL, -- Populated if moved BACKWARD
    processed_by BIGINT UNSIGNED DEFAULT NULL,
    active_iteration_flag BOOLEAN DEFAULT TRUE, -- FALSE if overridden by backward loop
    
    -- assigned_placement_rm BIGINT UNSIGNED DEFAULT NULL,
    created_by BIGINT UNSIGNED NOT NULL,
    created_on DATETIME DEFAULT CURRENT_TIMESTAMP,
    modified_by BIGINT UNSIGNED NOT NULL,
    modified_on DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    
    FOREIGN KEY (opportunity_id) REFERENCES rfq_opportunity(opportunity_id)
) ENGINE=InnoDB;