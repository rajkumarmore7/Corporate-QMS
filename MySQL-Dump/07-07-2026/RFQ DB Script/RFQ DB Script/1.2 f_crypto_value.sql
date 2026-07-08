USE misp_crm_corpo;

DROP FUNCTION IF EXISTS rfq_f_crypto_value;

DELIMITER $$

CREATE FUNCTION rfq_f_crypto_value(
    p_input_value VARCHAR(512),
    p_action INT -- 1 = Encrypt, 2 = Decrypt
) 
RETURNS VARCHAR(512)
DETERMINISTIC
BEGIN
    DECLARE v_secret_key VARCHAR(64);
    SET v_secret_key = 'sandeep!'; 

    -- 1. Tight Guard Clause: Handle NULL, Empty Strings, or Whitespaces instantly
    IF p_input_value IS NULL OR TRIM(p_input_value) = '' THEN
        RETURN p_input_value;
    END IF;

    -- =========================================================================
    -- ROUTE 1: ENCRYPTION
    -- =========================================================================
    IF p_action = 1 THEN
        RETURN HEX(AES_ENCRYPT(p_input_value, v_secret_key));

    -- =========================================================================
    -- ROUTE 2: DECRYPTION
    -- =========================================================================
    ELSEIF p_action = 2 THEN
        -- Verify string is an even length AND contains ONLY hex characters
        IF LENGTH(TRIM(p_input_value)) % 2 = 0 AND TRIM(p_input_value) REGEXP '^[0-9a-fA-F]+$' THEN
            RETURN CAST(AES_DECRYPT(UNHEX(TRIM(p_input_value)), v_secret_key) AS CHAR);
        ELSE
            -- Plain text string fallback (keeps legacy test phone numbers safe)
            RETURN p_input_value;
        END IF;
    
    ELSE
        RETURN NULL;
    END IF;
END$$

DELIMITER ;

SELECT rfq_f_crypto_value('9967870809', 1) AS MobileNo,  rfq_f_crypto_value('sds0987@gmail.com', 1) AS Email;
SELECT rfq_f_crypto_value('2B8F83A7A5D07680D5FA839EED9835DB', 2) AS MobileNo ,  rfq_f_crypto_value('79470BD2EB04022225977DDFFDA3EB87926401C19E6794CACC4549C46BF33BE8', 2) AS Email;
