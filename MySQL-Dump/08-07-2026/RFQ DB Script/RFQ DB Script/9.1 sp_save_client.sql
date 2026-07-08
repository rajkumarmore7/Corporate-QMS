USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_save_client;

DELIMITER $$

CREATE PROCEDURE rfq_sp_save_client(
	IN p_userid BIGINT,
    IN p_input_json LONGTEXT, -- CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_response LONGTEXT
)
proc_main: BEGIN
    -- Declare tracking variables
    DECLARE v_userid BIGINT; 
    DECLARE v_client_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_client_UUID VARCHAR(50); 
    DECLARE v_client_name VARCHAR(255);
    DECLARE v_client_type_code VARCHAR(30);
    DECLARE v_client_vertical_code VARCHAR(30) DEFAULT 'cvva';
	DECLARE v_pincode VARCHAR(30);
    DECLARE v_client_data_payload JSON;
    
    -- Loop / Array context variables for Contacts parsing
    DECLARE v_contact_count INT DEFAULT 0;
    DECLARE v_idx INT DEFAULT 0;
    DECLARE v_contact_name VARCHAR(255);
    DECLARE v_contact_email VARCHAR(255);
    DECLARE v_contact_mobile VARCHAR(20);

    -- Variables to capture system error states
    DECLARE v_sql_state VARCHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;
    
	
    -- =========================================================================
    -- THE "CATCH" BLOCK (Global Exception Handler)
    -- =========================================================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Capture the exact error details from the MySQL diagnostics engine
        GET DIAGNOSTICS CONDITION 1 
            v_sql_state = RETURNED_SQLSTATE, 
            v_error_msg = MESSAGE_TEXT;
            
        -- Explicitly rollback any uncommitted modifications
        ROLLBACK;
        
        -- 3. STREAM CRASH RECORD TO DISK ON WAREHOUSE EXCEPTION LEDGER
        CALL misp_audit_warehouse.sp_log_database_exception(
            'rfq_sp_save_client',
            v_sql_state,
            v_error_msg,
            p_userid,
            p_input_json
        );
        
        -- Return a clean, standardized error response object to Java
        SET p_response = JSON_OBJECT(
            'status', 500,
            'message', CONCAT('Database Transaction Failed: ', v_error_msg),
            'payload', JSON_OBJECT('sql_state', v_sql_state, 'payload', p_input_json,'userid', v_userid)
        );
    END;

    -- =========================================================================
    -- THE "TRY" BLOCK (Transaction Logic Zone)
    -- =========================================================================
    START TRANSACTION;

    -- 1. Extract foundational control structures out of the JSON root
    SET v_userid = p_userid; -- CAST(JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.userid')) AS UNSIGNED);
    -- 2. Extract client payload blocks
    SET v_client_name = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client.client_name'));
    SET v_client_type_code = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client.client_type_code'));
    SET v_client_vertical_code = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client.client_vertical_code'));
    SET v_client_data_payload = JSON_EXTRACT(p_input_json, '$.payload.client_data');
    SET v_pincode = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client_data.address.pincode'));
	-- SET v_client_UUID = JSON_EXTRACT(p_input_json, '$.payload.client_UUID');
    
    -- 3. Determine Route: Is it an Update or a New Entry?
    IF JSON_CONTAINS_PATH(p_input_json, 'one', '$.payload.client.client_UUID') = 1 AND 
       JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client.client_UUID')) IS NOT NULL AND
       JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client.client_UUID')) != '' THEN
       
        SET v_client_UUID = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, '$.payload.client.client_UUID'));
    END IF;

    -- =========================================================================
    -- BRANCH A: UPDATE EXISTENT RECORD (client_id is provided)
    -- =========================================================================
    IF v_client_UUID IS NOT NULL THEN
        
        -- Fetch the existing UUID so we can return it in the payload
        SELECT client_id INTO v_client_id 
        FROM rfq_clients 
        WHERE client_UUID = v_client_UUID;

        -- Quick validation check: If client does not exist, throw custom escape notice
        IF v_client_id IS NULL THEN
            SET p_response = JSON_OBJECT(
                'status', 4001,
                'message', 'Client record matching provided client_id not found.',
                'payload', NULL
            );
            ROLLBACK;
            LEAVE proc_main;
        END IF;

        -- Update Master Record Details
        UPDATE rfq_clients 
        SET client_name = v_client_name,
            client_type_code = v_client_type_code,
            client_vertical_code = v_client_vertical_code
            ,pincode = v_pincode
        WHERE client_id = v_client_id;

        -- Deactivate older matching rows in client_data
        UPDATE rfq_clients_data 
        SET active = FALSE 
        WHERE client_id = v_client_id;

        -- Insert updated nested metadata block
        INSERT INTO rfq_clients_data (client_id, client_payload, updated_id, version)
        VALUES (v_client_id, v_client_data_payload, v_userid, 2);

        -- Clear out preceding dynamic structural associations for contacts
        -- DELETE FROM contact 
        UPDATE rfq_contact 
        SET active = FALSE 
        WHERE table_name = 'rfq_clients' AND pk_id = v_client_id;

        -- Format response with UUID payload
        SET p_response = JSON_OBJECT(
            'status', 200,
            'message', 'client record updated',
            'payload', JSON_OBJECT('client_UUID', v_client_UUID)
        );

    -- =========================================================================
    -- BRANCH B: PROVISION NEW RECORD (client_id is NULL)
    -- =========================================================================
    ELSE
        -- Generate the new UUID here first so we can reuse it
        SET v_client_UUID =  rfq_f_generate_sequential_uuid() ;

        -- Insert new client baseline registration profile
        INSERT INTO rfq_clients (client_UUID, client_name, client_type_code, client_vertical_code, created_id,pincode)
        VALUES (v_client_UUID, v_client_name, v_client_type_code, v_client_vertical_code, v_userid,v_pincode);
        
        -- Pull down auto-increment key context identifier generated
        SET v_client_id = LAST_INSERT_ID();

        -- Save metadata payload block tracking context linked directly
        INSERT INTO rfq_clients_data (client_id, client_payload, updated_id, version)
        VALUES (v_client_id, v_client_data_payload, v_userid, 1);
        
        -- Saving the Created as Owners
		INSERT INTO rfq_clients_owners
		(client_id, owner_id, owner_type_code, created_id, created_on) 
		VALUES (v_client_id, v_userid , 'cooo',v_userid,now());

        -- Format response with UUID payload
        SET p_response = JSON_OBJECT(
            'status', 200,
            'message', 'client created',
            'payload', JSON_OBJECT('client_UUID', v_client_UUID)
        );
    END IF;

    -- =========================================================================
    -- SHARED LAYER: PARSE AND POPULATE DYNAMIC MULTI-ROW CONTACT ARRAYS
    -- =========================================================================
    SET v_contact_count = JSON_LENGTH(JSON_EXTRACT(p_input_json, '$.payload.contacts'));
    
    WHILE v_idx < v_contact_count DO
        SET v_contact_name  = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, CONCAT('$.payload.contacts[', v_idx, '].name')));
        SET v_contact_email = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, CONCAT('$.payload.contacts[', v_idx, '].email')));
        SET v_contact_mobile = JSON_UNQUOTE(JSON_EXTRACT(p_input_json, CONCAT('$.payload.contacts[', v_idx, '].mobile')));

        INSERT INTO rfq_contact (table_name, pk_id, contact_title, contact_name, contact_mobile, contact_email, active)
        VALUES ('rfq_clients', v_client_id, ' ', v_contact_name, v_contact_mobile, v_contact_email, TRUE);

        SET v_idx = v_idx + 1;
    END WHILE;

    -- If all operations succeed, commit everything together safely
    COMMIT;
END$$

DELIMITER ;

-- SET @json_input_new = JSON_SET(
--     @json_input_new,
--     '$.payload.client_data.client.BranchCode', 'BR001',
--     '$.payload.client_data.client.BranchName', 'Mumbai Branch'
-- );

-- Define the incoming JSON payload (client_id is omitted/null)
SET @json_input_new = '{
    "userid": 8,
    "message": "Creating a brand new corporate client profile",
    "payload": {
        "client": {
            "client_name": "Mahindra Insurance Brokers 22",
            "client_type_code": "cttd",
            "client_vertical_code": "cvva"
        },
        "contacts": [
            {
                "name": "Executive Director Krishna",
                "email": "primary.exec1@testqmsdomain.com",
                "mobile": "987677868787"
            },
            {
                "name": "Manager Specialist Pankaj",
                "email": "ops.lead1@testqmsdomain.com",
                "mobile": "9876541230"
            }
        ],
        "client_data": {
            "client": {
                "gstin": "27ABCDE9626F1Z6",
                "pancard": "ABCDE9626F",
                "biz_type": "Manufacturing",
                "cin_number": "L87671MH2026PLC164727",
                "tin_number": "98765437933"
            },
            "address": {
                "cityid": 487256,
                "pincode": "411001",
                "stateid": 17,
                "address_line1": "Building 319, Industrial Zone",
                "address_line2": "Phase II"
            },
            "portfolio": {
                "lob": "Commercial Vehicles",
                "product": "Product Package Option A",
                "biz_type": "Motor",
                "brokerage": 8.47,
                "sub_product": "Standard Subcategory Plan",
                "sum_insured": 43886420,
                "renewal_date": "2027-01-12",
                "expected_premium": 89824
            }
        }
    }
}';

-- Execute the Stored Procedure
CALL rfq_sp_save_client(8,@json_input_new, @response_output);

-- View the output returned from the database
SELECT @response_output AS api_response;

 Select *,'' as cle from rfq_clients order by client_id desc limit 1;
-- Select * from rfq_clients_Data where client_id = (Select client_id from rfq_clients order by client_id desc limit 1);
-- Select * from rfq_contact where pk_id = (Select client_id from rfq_clients order by client_id desc limit 1);

--  -- // Update
--  -- Define the incoming JSON payload (client_id is omitted/null)
--  SET @json_input_new = '{
--      "userid": 8,
--      "message": "Creating a brand new corporate client profile",
--      "payload": {
--          "client": {
--              "client_name": "Geet",
--              "client_type_code": "cttc",
--              "client_vertical_code": "cvva",
--              "client_UUID":"8030898f2ac87dQ746bQ11f1Qb0eeQc018507ef9d5"
--          },
--          "contacts": [
--              {
--                  "name": "Executive geet 1",
--                  "email": "primary.exec1@testqmsdomain.com",
--                  "mobile": "+1-555-01001"
--              },
--              {
--                  "name": "Manager geet 1",
--                  "email": "ops.lead1@testqmsdomain.com",
--                  "mobile": "+1-555-02001"
--              }
--          ],
--          "client_data": {
--              "client": {
--                  "gstin": "Geet",
--                  "pancard": "ABCDE9626F",
--                  "biz_type": "Manufacturing",
--                  "cin_number": "L87671MH2026PLC164727",
--                  "tin_number": "98765437933"
--              },
--              "address": {
--                  "cityid": 487256,
--                  "pincode": "411001",
--                  "stateid": 17,
--                  "address_line1": "Building 319, Industrial Zone",
--                  "address_line2": "Phase II"
--              },
--              "portfolio": {
--                  "lob": "Geet Vehicles ",
--                  "product": "Product Package Option A",
--                  "biz_type": "Motor",
--                  "brokerage": 8.47,
--                  "sub_product": "Standard Subcategory Plan",
--                  "sum_insured": 43886420,
--                  "renewal_date": "2027-01-12",
--                  "expected_premium": 89824
--              }
--          }
--      }
--  }';

-- --  Execute the Stored Procedure
--  CALL rfq_sp_save_client(@json_input_new, @response_output);

-- --  View the output returned from the database
--   SELECT @response_output AS api_response;
-- -- // Update //