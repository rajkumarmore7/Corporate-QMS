USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS ZPopulateDummyClients;

DELIMITER $$

CREATE PROCEDURE ZPopulateDummyClients()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE current_user_id INT;
    DECLARE random_uuid VARCHAR(36);
    DECLARE random_pan VARCHAR(10);
    DECLARE random_gstin VARCHAR(15);
    DECLARE client_type VARCHAR(4);
    DECLARE vertical VARCHAR(4);
	DECLARE status VARCHAR(4);
	DECLARE created_id VARCHAR(4);
    DECLARE biz_type VARCHAR(30);

    WHILE i <= 500 DO
        SET current_user_id = IF(i % 2 = 0, 2, 1);
        SET random_uuid = REPLACE(REPLACE(UUID(),'-', 'Q') , 'f','1'); -- REPLACE(text, '-', 'Q'):
        SET random_pan = CONCAT('ABCDE', FLOOR(1000 + (RAND() * 8999)), 'F');
        SET random_gstin = CONCAT('27', random_pan, '1Z', FLOOR(RAND() * 9));
        
        SET client_type = ELT((i % 2) + 1, 'cttc', 'cttd');
        SET vertical = ELT((i % 3) + 1, 'cvva', 'coos', 'cooi');
		SET status = ELT((i % 3) + 1, 'casa', 'casp', 'casr');
        SET biz_type = ELT((i % 4) + 1, 'Manufacturing', 'Retail Logistics', 'Pharmaceuticals', 'IT Services');
		SET created_id = ELT((i % 4) + 1, '1', '2', '3', '4');
        INSERT INTO `rfq_clients` 
        (`client_UUID`, `client_name`, `client_type_code`, `client_vertical_code`, `created_id`, `client_status_code`)
        VALUES 
        (
            rfq_f_generate_sequential_uuid(),
			(SELECT CONCAT(title) FROM sakila.film where film_id = i LIMIT 1), 
            client_type, 
            vertical, 
            created_id,
			status
        );

        INSERT INTO `rfq_clients_data` 
        (`client_id`, `client_payload`, `version`, `updated_id`)
        VALUES
        (
            LAST_INSERT_ID(),
            CONCAT('{
                "client": {
                    "pancard": "', random_pan, '",
                    "cin_number": "L', FLOOR(10000 + (RAND() * 89999)), 'MH2026PLC', FLOOR(100000 + (RAND() * 899999)), '",
                    "tin_number": "9876543', FLOOR(1000 + (RAND() * 8999)), '",
                    "gstin": "', random_gstin, '",
                    "biz_type": "', biz_type, '"
                },
                "address": {
                    "address_line1": "Building ', FLOOR(1 + (RAND() * 500)), ', Industrial Zone",
                    "address_line2": "Phase ', ELT((i % 3) + 1, 'I', 'II', 'III'), '",
                    "cityid": ', FLOOR(400000 + (RAND() * 99999)), ',
                    "stateid": ', FLOOR(1 + (RAND() * 36)), ',
                    "pincode": "4000', FLOOR(10 + (RAND() * 89)), '"
                },
                "portfolio": {
                    "biz_type": "', ELT((i % 3) + 1, 'CGS', 'SME', 'EM'), '",
                    "lob": "', ELT((i % 3) + 1, 'BGR', 'Burglary', 'CPM'), '",
                    "product": "', ELT((i % 3) + 1, 'Property', 'Liberty', 'Marine'), '",
                    "sub_product": "Standard Subcategory Plan",
                    "sum_insured": ', ROUND(5000000 + (RAND() * 45000000), 0), ',
                    "expected_premium": ', ROUND(20000 + (RAND() * 180000), 0), ',
                    "brokerage": ', ROUND(5.0 + (RAND() * 10.0), 2), ',
                    "renewal_date": "', DATE_ADD(CURRENT_DATE, INTERVAL FLOOR(RAND() * 365) DAY), '"
                }
            }'),
            1,
            current_user_id
        );

        SET i = i + 1;
    END WHILE;
END $$

DELIMITER ;

-- Execute the procedure
CALL ZPopulateDummyClients();

-- Drop it clean
-- DROP PROCEDURE IF EXISTS ZPopulateDummyClients;alter

SELECT 
    created_id AS user_id, 
    COUNT(*) AS total_clients_created
FROM rfq_clients 
GROUP BY created_id;