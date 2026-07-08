USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS tmp_execute_user_seeding;

Delete from mmi_user_role_mapping where user_id in (Select id from mmi_mast_user_registration_detail where sap_code	 like '9888%' );
Delete from mmi_user_reporting where user_id in (Select id from mmi_mast_user_registration_detail where sap_code	 like '9888%' );
Delete from rfq_mast_user_department where user_id in (Select id from mmi_mast_user_registration_detail where sap_code	 like '9888%' );
Delete from mmi_mast_user where user_id in (Select id from mmi_mast_user_registration_detail where sap_code	 like '9888%' );
Delete  from mmi_mast_user_registration_detail where sap_code	 like '9888%' order by id desc;

DELIMITER $$

CREATE PROCEDURE tmp_execute_user_seeding()
BEGIN
    -- 1. Declare Stored Role ID Mapping Variables
    DECLARE r_sales_bh, r_sales_zh, r_sales_vh, r_sales_sm, r_sales_rm INT;
    DECLARE r_prac_hd, r_place_mn, r_place_rm, r_mngID , r_preID INT;
    
    -- API Response JSON buffer
    DECLARE v_res LONGTEXT;
    set r_preID = '988800000';
    
    -- Select * from mmi_mast_role;

    -- 2. Lookup Role IDs dynamically from master definition directory
    SELECT role_id INTO r_sales_rm FROM mmi_mast_role WHERE role = 'Sales Regional Manager' LIMIT 1;
    SELECT role_id INTO r_sales_sm FROM mmi_mast_role WHERE role = 'Sales Manager' LIMIT 1;
    SELECT role_id INTO r_sales_vh FROM mmi_mast_role WHERE role = 'Sales Vertical Head' LIMIT 1;
    SELECT role_id INTO r_sales_zh FROM mmi_mast_role WHERE role = 'Sales Zonal Head' LIMIT 1;
    SELECT role_id INTO r_sales_bh FROM mmi_mast_role WHERE role = 'Sales Business Head' LIMIT 1;
    SELECT role_id INTO r_prac_hd FROM mmi_mast_role WHERE role = 'Placement Head' LIMIT 1;
    SELECT role_id INTO r_place_mn FROM mmi_mast_role WHERE role= 'Placement Manager' LIMIT 1;
    SELECT role_id INTO r_place_rm FROM mmi_mast_role WHERE role = 'Placement Regional Manager' LIMIT 1;

    -- =========================================================================
    -- PHASE A: SALES MANAGEMENT HIERARCHY (TOP -> DOWN STRUCTURE)
    -- =========================================================================


     SET r_mngID = (Select id from mmi_mast_user_registration_detail where sap_code = '99990002'); Select r_mngID;

     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 98880003, 'firstname', 'Satish', 'lastname', 'VH', 'contactinfo', '9900000003',
         'emailid', 'Satish.vh@test.com', 'status', '1', 'location', 'Delhi Regional Branch',
         'roleID', r_sales_vh, 'roleName', 'Sales Vertical Head', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '98880003', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
     ), v_res);
     
      SET r_mngID = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_res, '$.payload.user_id')) AS UNSIGNED); Select r_mngID;

     -- [4] L2: Pankaj Mng (Sales Manager) -> Reports to Satish VH (98880003)
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 98880004, 'firstname', 'Anand', 'lastname', 'Mng', 'contactinfo', '9900000004',
         'emailid', 'Anand.mng@test.com', 'status', '1', 'location', 'Pune Corporate office',
         'roleID', r_sales_sm, 'roleName', 'Sales Manager', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '98880004', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
     ), v_res);

 	SET r_mngID = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_res, '$.payload.user_id')) AS UNSIGNED); Select r_mngID;
     
     -- [5, 6, 7] L1: Frontline Front Front (Pan RM, Ran RM, Zan RM) -> Report to Anand Mng (98880004)
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 98880005, 'firstname', 'Harash', 'lastname', 'RM', 'contactinfo', '7020351228',
         'emailid', 'Harash.rm@test.com', 'status', '1', 'location', 'Mumbai HQ',
         'roleID', r_sales_rm, 'roleName', 'Sales Regional Manager', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '98880005', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
     ), v_res);

     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 98880006, 'firstname', 'Sahil', 'lastname', 'RM', 'contactinfo', '9900000006',
         'emailid', 'Sahil.rm@test.com', 'status', '1', 'location', 'Pune Corporate office',
         'roleID', r_sales_rm, 'roleName', 'Sales Regional Manager', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '98880006', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
     ), v_res);

     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 98880007, 'firstname', 'Pradeep', 'lastname', 'RM', 'contactinfo', '9900000007',
         'emailid', 'Pradeep.rm@test.com', 'status', '1', 'location', 'Delhi Regional Branch',
         'roleID', r_sales_rm, 'roleName', 'Sales Regional Manager', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '98880007', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
     ), v_res);


    -- =========================================================================
    -- PHASE B: OPERATIONS & PLACEMENT MANAGEMENT STRUCTURE
    -- =========================================================================

     -- [8, 9, 10] Practice Heads (Amit PH, Raj PH, Prashant PH) -> Report to System Admin (1)
    -- Assigned to the multi-department Operations channel ('uddi')

		SET r_mngID = (Select id from mmi_mast_user_registration_detail where sap_code = '99990008'); Select r_mngID;
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 98880009, 'firstname', 'Saachin', 'lastname', 'PM', 'contactinfo', '9900000009',
         'emailid', 'Saachin.pm@test.com', 'status', '1', 'location', 'Bangalore Hub',
         'roleID', r_place_mn, 'roleName', 'Practice Head', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '98880009', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('uddi')
     ), v_res);
 	SET r_mngID = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_res, '$.payload.user_id')) AS UNSIGNED); Select r_mngID;
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 98880010, 'firstname', 'Zeenet', 'lastname', 'PRM', 'contactinfo', '9900000010',
         'emailid', 'Zeenet.rm@test.com', 'status', '1', 'location', 'Chennai Office',
         'roleID', r_place_rm, 'roleName', 'Practice Head', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '98880010', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('uddi')
     ), v_res);
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 98880011, 'firstname', 'Alim', 'lastname', 'PRM', 'contactinfo', '9900000010',
         'emailid', 'Alim.rm@test.com', 'status', '1', 'location', 'Chennai Office',
         'roleID', r_place_rm, 'roleName', 'Practice Head', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '98880011', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('uddi')
     ), v_res);

END$$

DELIMITER ;

-- 3. Execute the batch mapping process
CALL tmp_execute_user_seeding();

-- 4. Clean up temporary procedure resources
DROP PROCEDURE tmp_execute_user_seeding;


Select a.id , a.sap_code, a.first_name, a.last_name
, ro.role as User_Role
, r.supervisor_id as Reporting_userId
,m.first_name as Reporting_first_name, m.last_name as Reporting_last_name,m.sap_code  as Reporting_sap_code
from mmi_mast_user_registration_detail a
Left Join mmi_user_reporting r on r.user_id = a.id
Left Join mmi_mast_user_registration_detail m on m.id = r.supervisor_id 
Left Join mmi_user_role_mapping rm on rm.user_id =  a.id
left Join mmi_mast_role ro on ro.role_id = rm.role_id
where a.sap_code like '9888%' order by a.id;



-- Delete from mmi_maintain_overwrite_logs							;
-- Delete from mmi_crm_ebm_transaction_details;
-- Delete from mmi_mast_dealer_role_mapping;
-- Delete from mmi_user_dealer_mapping;
-- Delete from mmi_lead_details                                    ;
-- Delete from mmi_ebm_policy_data                                 ;
-- Delete from mmi_mast_customer_details                           ;
-- Delete from mmi_ebm_service_data                                ;
-- Delete from mmi_customer_claim_history                          ;
-- Delete from mmi_dealer_location_mapping                         ;
-- Delete from mmi_call_disposition_history                        ;
-- Delete from mmi_customer_renewalreminder_history                ;
-- Delete from mmi_lead_archive_details                            ;
-- Delete from mmi_customer_service_history                        ;
-- Delete from mmi_login_history                                   ;
-- Delete from mmi_dealer_details                                  ;
-- Delete from mmi_crm_ebm_transaction_details                     ;