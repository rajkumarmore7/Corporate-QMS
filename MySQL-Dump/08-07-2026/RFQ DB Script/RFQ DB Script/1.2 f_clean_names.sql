USE misp_crm_corpo;

DROP FUNCTION IF EXISTS rfq_f_clean_names;

DELIMITER $$

CREATE FUNCTION rfq_f_clean_names(p_name VARCHAR(255)) 
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    DECLARE v_clean VARCHAR(255);
    
    IF p_name IS NULL OR p_name = '' THEN
        RETURN '';
    END IF;

    -- Step 1: Force Lowercase to normalize casing issues
    SET v_clean = LOWER(TRIM(p_name));

    -- Step 2: Strip common legal entity suffixes/keywords
    SET v_clean = REPLACE(v_clean, 'pvt.ltd.', '');
    SET v_clean = REPLACE(v_clean, 'pvt ltd', '');
    SET v_clean = REPLACE(v_clean, 'pvt.', '');
    SET v_clean = REPLACE(v_clean, 'pvt', '');
    SET v_clean = REPLACE(v_clean, 'ltd.', '');
    SET v_clean = REPLACE(v_clean, 'ltd', '');
    SET v_clean = REPLACE(v_clean, 'limited', '');
    SET v_clean = REPLACE(v_clean, 'llp', '');
    SET v_clean = REPLACE(v_clean, 'inc.', '');
    SET v_clean = REPLACE(v_clean, 'inc', '');
    SET v_clean = REPLACE(v_clean, 'brokers', ''); -- Handles 'broker' variation variations
    SET v_clean = REPLACE(v_clean, 'broker', '');

    -- Step 3: Strip Punctuation, Dots, Hyphens, and Spaces
    SET v_clean = REPLACE(v_clean, '.', '');
    SET v_clean = REPLACE(v_clean, ',', '');
    SET v_clean = REPLACE(v_clean, '-', '');
    SET v_clean = REPLACE(v_clean, '/', '');
    SET v_clean = REPLACE(v_clean, ' ', ''); -- Removes all blank spaces

    RETURN TRIM(v_clean);
END$$

DELIMITER ;


-- ALTER TABLE client 
-- ADD COLUMN cleaned_client_name VARCHAR(255) 
-- GENERATED ALWAYS AS (rfq_f_clean_names(client_name)) STORED;
-- CREATE INDEX idx_cleaned_client_name ON client(cleaned_client_name);