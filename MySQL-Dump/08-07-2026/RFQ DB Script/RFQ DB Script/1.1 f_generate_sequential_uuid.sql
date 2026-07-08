USE misp_crm_corpo;

DROP FUNCTION IF EXISTS rfq_f_generate_sequential_uuid;

DELIMITER $$

CREATE FUNCTION rfq_f_generate_sequential_uuid() 
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    -- CONCAT implicitly converts the random number to a string, saving CPU cycles
    RETURN CONCAT(
        FLOOR(100000 + (RAND() * 899999)), 
        REPLACE(UUID(), '-', 'Q')
    );
END$$

DELIMITER ;

-- New high-performance text way:
select rfq_f_generate_sequential_uuid() ;