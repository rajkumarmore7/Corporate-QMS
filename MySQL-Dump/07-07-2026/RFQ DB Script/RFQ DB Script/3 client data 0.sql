USE misp_crm_corpo;

-- =========================================================================
-- 1. INSERT RECORDS INTO THE MAIN 'client' TABLE
-- =========================================================================
INSERT INTO `rfq_clients` 
(`client_id`, `client_UUID`, `client_name`, `client_type_code`, `client_vertical_code`, `created_id`, `pincode`) 
VALUES
(1, '645876468c7351Q7450Q11f1Qb0eeQc018507ef9d5', 'Global Industries Ltd', 'cttc', 'cvva', (Select id from mmi_mast_user_registration_detail where sap_code = '98880007' limit 1),'400067'), -- Corporate, Vertical: Corporate, Created by User 1
(2, '140676468d57b9Q7450Q11f1Qb0eeQc018507ef9d5', 'Apex Auto Dealership', 'cttd', 'coos', (Select id from mmi_mast_user_registration_detail where sap_code = '99990007' limit 1),'400067'); -- Dealer, Vertical: SME, Created by User 2


-- =========================================================================
-- 2. INSERT CORRESPONDING RECORDS INTO 'client_data' (WITH JSON PAYLOADS)
-- =========================================================================
INSERT INTO `rfq_clients_data` 
(`client_id`, `client_payload`, `version`, `updated_id`) 
VALUES
(
  1, 
  '{
    "client": {
      "pancard": "ABCDE1234F",
      "cin_number": "L01234MH2020PLC123456",
      "tin_number": "98765432101",
      "gstin": "27ABCDE1234F1Z5",
      "biz_type": "Manufacturing"
    },
    "address": {
      "address_line1": "101, Alpha Tech Park",
      "address_line2": "Bandrea Kurla Complex",
      "cityid": 400067,
      "stateid": 27,
      "pincode": "400067"
    },
    "portfolio": {
      "biz_type": "Property",
      "lob": "Fire & Engineering",
      "product": "Standard Fire Policy",
      "sub_product": "SFSP Industrial",
      "sum_insured": 50000000,
      "expected_premium": 150000,
      "brokerage": 12.5,
      "renewal_date": "2027-04-01"
    }
  }', 
  1, 
  1
),
(
  2, 
  '{
    "client": {
      "pancard": "VWXYZ5678G",
      "cin_number": "U56789DL2018PTC987654",
      "tin_number": "11223344556",
      "gstin": "07VWXYZ5678G1Z0",
      "biz_type": "Retail Logistics"
    },
    "address": {
      "address_line1": "Plot 42, Sector 18",
      "address_line2": "Maruti Industrial Area",
      "cityid": 400067,
      "stateid": 6, 
      "pincode": "400067"
    },
    "portfolio": {
      "biz_type": "Motor",
      "lob": "Commercial Vehicles",
      "product": "Digit Commercial Package",
      "sub_product": "Dealer Open Cover",
      "sum_insured": 12000000,
      "expected_premium": 45000,
      "brokerage": 15.0,
      "renewal_date": "2027-01-15"
    }
  }', 
  1, 
  2
);

update rfq_clients set client_status_code = 'casa' 
, approval_id = (Select id from mmi_mast_user_registration_detail where sap_code = '98880004' limit 1)
,approval_on = now()
where client_id = 1;
update rfq_clients set client_status_code = 'casa' 
, approval_id = (Select id from mmi_mast_user_registration_detail where sap_code = '99990004' limit 1)
,approval_on = now()
where client_id = 2;
-- cooo
INSERT INTO `rfq_clients_owners` 
(`client_id`, `owner_id`, `owner_type_code`, `created_id`, `created_on`) 
VALUES
(1, (Select id from mmi_mast_user_registration_detail where sap_code = '98880007' limit 1), 'cooo',1,now()), 
(2, (Select id from mmi_mast_user_registration_detail where sap_code = '99990007' limit 1), 'cooo',1,now());
update rfq_clients_owners set active = 0;
INSERT INTO `rfq_clients_owners` 
(`client_id`, `owner_id`, `owner_type_code`, `created_id`, `created_on`) 
VALUES
(1, (Select id from mmi_mast_user_registration_detail where sap_code = '98880007' limit 1), 'cooo',1,now()), 
(2, (Select id from mmi_mast_user_registration_detail where sap_code = '99990007' limit 1), 'cooo',1,now());