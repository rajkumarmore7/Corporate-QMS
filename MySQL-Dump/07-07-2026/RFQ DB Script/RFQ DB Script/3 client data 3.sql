USE  misp_crm_corpo;

DROP PROCEDURE IF EXISTS ZPopulateDummyContacts;

DELIMITER $$

CREATE PROCEDURE ZPopulateDummyContacts()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE current_client_id BIGINT UNSIGNED;
    DECLARE i INT DEFAULT 1;
    
    -- Cursor to iterate through all existing clients
    DECLARE client_cursor CURSOR FOR SELECT client_id FROM `rfq_clients`;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN client_cursor;

    read_loop: LOOP
        FETCH client_cursor INTO current_client_id;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- 1. Insert Primary Contact for this client
        INSERT INTO `rfq_contact` (`table_name`, `pk_id`, `contact_title`, `contact_name`, `contact_mobile`, `contact_email`, `active`)
        VALUES (
            'rfq_clients',
            current_client_id,
            'Primary Contact',
            (SELECT CONCAT(first_name, ' ', last_name) AS name FROM sakila.actor ORDER BY RAND() LIMIT 1),
            CONCAT('8787989', LPAD(i, 3, '0')),
            CONCAT((SELECT CONCAT(first_name, ' ', last_name) AS name FROM sakila.actor ORDER BY RAND() LIMIT 1), i, '@testqmsdomain.com'),
            TRUE
        );

        -- 2. Insert Secondary Contact for this client
        INSERT INTO `rfq_contact` (`table_name`, `pk_id`, `contact_title`, `contact_name`, `contact_mobile`, `contact_email`, `active`)
        VALUES (
            'rfq_clients',
            current_client_id,
            'Operations Lead',
            (SELECT CONCAT(first_name, ' ', last_name) AS name FROM sakila.actor ORDER BY RAND() LIMIT 1),
            CONCAT('9999000000'+         FLOOR(100000 + (RAND() * 899999))),
            CONCAT((SELECT CONCAT(first_name, ' ', last_name) AS name FROM sakila.actor ORDER BY RAND() LIMIT 1), i, '@testqmsdomain.com'),
            TRUE
        );

        SET i = i + 1;
    END LOOP;

    CLOSE client_cursor;
END $$

DELIMITER ;

-- Execute the contact generation routine
CALL ZPopulateDummyContacts();

-- Clean up the procedure
-- DROP PROCEDURE IF EXISTS PopulateDummyContacts;