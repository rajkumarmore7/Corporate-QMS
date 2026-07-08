USE misp_crm_corpo;

DROP PROCEDURE IF EXISTS tmp_execute_user_seeding;

Delete from mmi_user_role_mapping where user_id in (Select id from mmi_mast_user_registration_detail where sap_code	 like '9999%' );
Delete from mmi_user_reporting where user_id in (Select id from mmi_mast_user_registration_detail where sap_code	 like '9999%' );
Delete from rfq_mast_user_department where user_id in (Select id from mmi_mast_user_registration_detail where sap_code	 like '9999%' );
Delete from mmi_mast_user where user_id in (Select id from mmi_mast_user_registration_detail where sap_code	 like '9999%' );
Delete  from mmi_mast_user_registration_detail where sap_code	 like '9999%' order by id desc;

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

    -- [1] Top Level: Swati BH (Sales Business Head) -> Reports to System Admin (1)
    CALL rfq_sp_add_user(JSON_OBJECT(
        'userId', 99990001, 'firstname', 'Swati', 'lastname', 'BH', 'contactinfo', '9900000001',
        'emailid', 'swati.bh@test.com', 'status', '1', 'location', 'Mumbai HQ',
        'roleID', r_sales_bh, 'roleName', 'Sales Business Head', 'adFlag', 'N', 'teamEmail', 'N',
        'sapCode', '99990001', 'isGroup', 'N', 'reportingManagerId', '1','designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
    ), v_res);
    
     SET r_mngID = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_res, '$.payload.user_id')) AS UNSIGNED); Select r_mngID;
     
    -- [2] L4: Deepak ZH (Sales Zonal Head) -> Reports to Swati BH (99990001)
    CALL rfq_sp_add_user(JSON_OBJECT(
        'userId', 99990002, 'firstname', 'Deepak', 'lastname', 'ZH', 'contactinfo', '9900000002',
        'emailid', 'deepak.zh@test.com', 'status', '1', 'location', 'Mumbai HQ',
        'roleID', r_sales_zh, 'roleName', 'Sales Zonal Head', 'adFlag', 'N', 'teamEmail', 'N',
        'sapCode', '99990002', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
    ), v_res);
    
     SET r_mngID = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_res, '$.payload.user_id')) AS UNSIGNED); Select r_mngID;

     -- [3] L3: Sandeep VH (Sales Vertical Head) -> Reports to Deepak ZH (99990002)
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 99990003, 'firstname', 'Sandeep', 'lastname', 'VH', 'contactinfo', '9900000003',
         'emailid', 'sandeep.vh@test.com', 'status', '1', 'location', 'Delhi Regional Branch',
         'roleID', r_sales_vh, 'roleName', 'Sales Vertical Head', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '99990003', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
     ), v_res);
     
      SET r_mngID = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_res, '$.payload.user_id')) AS UNSIGNED); Select r_mngID;

     -- [4] L2: Pankaj Mng (Sales Manager) -> Reports to Sandeep VH (99990003)
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 99990004, 'firstname', 'Pankaj', 'lastname', 'Mng', 'contactinfo', '9900000004',
         'emailid', 'pankaj.mng@test.com', 'status', '1', 'location', 'Pune Corporate office',
         'roleID', r_sales_sm, 'roleName', 'Sales Manager', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '99990004', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
     ), v_res);

 	SET r_mngID = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_res, '$.payload.user_id')) AS UNSIGNED); Select r_mngID;
     
     -- [5, 6, 7] L1: Frontline Front Front (Pan RM, Ran RM, Zan RM) -> Report to Pankaj Mng (99990004)
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 99990005, 'firstname', 'Pan', 'lastname', 'RM', 'contactinfo', '7020351228',
         'emailid', 'pan.rm@test.com', 'status', '1', 'location', 'Mumbai HQ',
         'roleID', r_sales_rm, 'roleName', 'Sales Regional Manager', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '99990005', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
     ), v_res);

     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 99990006, 'firstname', 'Ran', 'lastname', 'RM', 'contactinfo', '9900000006',
         'emailid', 'ran.rm@test.com', 'status', '1', 'location', 'Pune Corporate office',
         'roleID', r_sales_rm, 'roleName', 'Sales Regional Manager', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '99990006', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
     ), v_res);

     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 99990007, 'firstname', 'Zan', 'lastname', 'RM', 'contactinfo', '9900000007',
         'emailid', 'zan.rm@test.com', 'status', '1', 'location', 'Delhi Regional Branch',
         'roleID', r_sales_rm, 'roleName', 'Sales Regional Manager', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '99990007', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('udds')
     ), v_res);


    -- =========================================================================
    -- PHASE B: OPERATIONS & PLACEMENT MANAGEMENT STRUCTURE
    -- =========================================================================

     -- [8, 9, 10] Practice Heads (Amit PH, Raj PH, Prashant PH) -> Report to System Admin (1)
    -- Assigned to the multi-department Operations channel ('uddi')
      -- [11] L2: Nafiz PM (Placement Manager) -> Reports to Amit PH (99990008)
     CALL rfq_sp_add_user(JSON_OBJECT(
        'userId', 99990008, 'firstname', 'Prashant', 'lastname', 'PH', 'contactinfo', '9900000008',
        'emailid', 'Prashant.ph@test.com', 'status', '1', 'location', 'Mumbai HQ',
        'roleID', r_prac_hd, 'roleName', 'Practice Head', 'adFlag', 'N', 'teamEmail', 'N',
        'sapCode', '99990008', 'isGroup', 'N', 'reportingManagerId', '1','designation_code', 'uddsrm', 'departments', JSON_ARRAY('uddi')
     ), v_res);
 	SET r_mngID = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_res, '$.payload.user_id')) AS UNSIGNED); Select r_mngID;
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 99990009, 'firstname', 'Amit', 'lastname', 'PM', 'contactinfo', '9900000009',
         'emailid', 'Prashant.pm@test.com', 'status', '1', 'location', 'Bangalore Hub',
         'roleID', r_place_mn, 'roleName', 'Practice Head', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '99990009', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('uddi')
     ), v_res);
 	SET r_mngID = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_res, '$.payload.user_id')) AS UNSIGNED); Select r_mngID;
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 99990010, 'firstname', 'Raj', 'lastname', 'PRM', 'contactinfo', '9900000010',
         'emailid', 'Raj.rm@test.com', 'status', '1', 'location', 'Chennai Office',
         'roleID', r_place_rm, 'roleName', 'Practice Head', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '99990010', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('uddi')
     ), v_res);
     CALL rfq_sp_add_user(JSON_OBJECT(
         'userId', 99990011, 'firstname', 'Krishna', 'lastname', 'PRM', 'contactinfo', '9900000010',
         'emailid', 'Krishna.rm@test.com', 'status', '1', 'location', 'Chennai Office',
         'roleID', r_place_rm, 'roleName', 'Practice Head', 'adFlag', 'N', 'teamEmail', 'N',
         'sapCode', '99990011', 'isGroup', 'N', 'reportingManagerId', r_mngID,'designation_code', 'uddsrm', 'departments', JSON_ARRAY('uddi')
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
where a.sap_code like '9999%' order by a.id desc;



