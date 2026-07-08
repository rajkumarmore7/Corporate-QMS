USE misp_crm_corpo;

-- SET NAMES 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';
-- =========================================================================
-- 1. KEY DATA STORE (rfq_kds) - Lookup / Master Dictionary Table
-- =========================================================================
CREATE TABLE `rfq_kds` (
  `kds_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `key_module` VARCHAR(30) NOT NULL,
  `key_source` VARCHAR(30) NOT NULL,
  `key_name` VARCHAR(80) NOT NULL,
  `key_code` VARCHAR(30) NOT NULL,
  `key_value` VARCHAR(225) NOT NULL,
  `key_parent_id` BIGINT UNSIGNED NULL,
  `sort_order` INT NOT NULL DEFAULT 1,
  `created_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`kds_id`),
  UNIQUE KEY `uk_key_code` (`key_code`)
) ENGINE=InnoDB; -- DEFAULT CHARSET=utf8mb4;

-- Seed KDS Master Data
INSERT INTO rfq_kds (key_module, key_source, key_code, key_name, key_value) VALUES
('client', 'approval', 'casa', 'status', 'Approved'),
('client', 'approval', 'casr', 'status', 'Rejected'),
('client', 'approval', 'cass', 'status', 'Sendback'),
('client', 'approval', 'casp', 'status', 'Pending'),
('client', 'ownertype', 'cooo', 'owner', 'Owner'),
('client', 'ownertype', 'cooc', 'owner', 'Co-owner'),
('client', 'vertical', 'cvva', 'vertical', 'CORPORATE'),
('client', 'vertical', 'coos', 'vertical', 'SME'),
('client', 'vertical', 'cooi', 'vertical', 'INDIVIDUAL'),
('client', 'type', 'cttc', 'type', 'Corporate'),
('client', 'type', 'cttd', 'type', 'Dealer');


-- =========================================================================
-- 2. CLIENT MASTER TABLE
-- =========================================================================
CREATE TABLE `rfq_clients` (
  `client_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `client_UUID` VARCHAR(90) NOT NULL,
  `client_name` VARCHAR(255) NOT NULL,
  `client_type_code` VARCHAR(30) NOT NULL,
  `client_vertical_code` VARCHAR(30) NOT NULL,
  `pincode` VARCHAR(30) NULL,
  `created_id` BIGINT NULL, -- Default Owner
  `created_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `approval_id` BIGINT NULL, -- Default Owner
  `approval_on` TIMESTAMP NULL,
  `client_status_code` VARCHAR(30) DEFAULT 'casp',
  `client_status_reason` VARCHAR(300),
  `client_remarks` VARCHAR(500) DEFAULT NULL,
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`client_id`),
  -- Indexes
  KEY `idx_client_type` (`client_type_code`),
  KEY `idx_client_vertical` (`client_vertical_code`),
  KEY `idx_client_status` (`client_status_code`),
  -- Foreign Keys mapping to KDS
  CONSTRAINT `fk_client_type_code` FOREIGN KEY (`client_type_code`) REFERENCES `rfq_kds` (`key_code`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_client_status_code` FOREIGN KEY (`client_status_code`) REFERENCES `rfq_kds` (`key_code`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_client_vertical_code` FOREIGN KEY (`client_vertical_code`) REFERENCES `rfq_kds` (`key_code`) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB; -- DEFAULT CHARSET=utf8mb4;


-- =========================================================================
-- 3. CLIENT DATA TABLE (JSON Payload)
-- =========================================================================
CREATE TABLE `rfq_clients_data` (
  `client_data_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `client_id` BIGINT UNSIGNED NOT NULL,
  `client_payload` JSON NOT NULL,
  `version` INT DEFAULT 1,
  `updated_id` BIGINT NULL,
  `updated_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`client_data_id`),
  KEY `idx_client_data_client_id` (`client_id`),
  CONSTRAINT `fk_client_data_client` FOREIGN KEY (`client_id`) REFERENCES `rfq_clients` (`client_id`) ON DELETE CASCADE,
  CONSTRAINT `chk_json_valid` CHECK (JSON_VALID(`client_payload`))
) ENGINE=InnoDB; -- DEFAULT CHARSET=utf8mb4;


-- =========================================================================
-- 5. CLIENT OWNERS TABLE (Many-to-Many Bridge)
-- =========================================================================
CREATE TABLE `rfq_clients_owners` (
  `client_owner_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `client_id` BIGINT UNSIGNED NOT NULL,
  `owner_id` BIGINT UNSIGNED NOT NULL,
  `owner_type_code` VARCHAR(30) NOT NULL, -- PRIMARY & Co Owner
  `created_id` BIGINT NULL,
  `created_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_id` BIGINT NULL,
  `updated_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`client_owner_id`),
  KEY `idx_client_owners_client_id` (`client_id`),
  KEY `idx_client_owners_user_id` (`owner_id`),
  CONSTRAINT `fk_client_owners_client` FOREIGN KEY (`client_id`) REFERENCES `rfq_clients` (`client_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_client_owners_kds` FOREIGN KEY (`owner_type_code`) REFERENCES `rfq_kds` (`key_code`)
) ENGINE=InnoDB; -- DEFAULT CHARSET=utf8mb4;


-- =========================================================================
-- 6. CONTACT TABLE (rfq_Polymorphic Contact Association)
-- =========================================================================
CREATE TABLE `rfq_contact` (
  `contact_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `table_name` VARCHAR(30) NOT NULL, -- Will store 'client' 'portolio' to relate back dynamically
  `pk_id` BIGINT UNSIGNED NOT NULL,    -- Will store the client_id, portolio_id
  `contact_title` VARCHAR(255) NULL,
  `contact_name` VARCHAR(255) NOT NULL,
  `contact_mobile` VARCHAR(20) NOT NULL,
  `contact_email` VARCHAR(255) NOT NULL,
  `created_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`contact_id`),
  KEY `idx_contact_ref` (`table_name`, `pk_id`)
) ENGINE=InnoDB; -- DEFAULT CHARSET=utf8mb4;

ALTER TABLE `rfq_clients` ADD INDEX `idx_client_uuid` (`client_UUID`);


SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE misp_crm_corpo.rfq_contact;
TRUNCATE TABLE misp_crm_corpo.rfq_clients_data;
TRUNCATE TABLE misp_crm_corpo.rfq_clients;
SET FOREIGN_KEY_CHECKS = 1;
