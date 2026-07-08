CREATE OR REPLACE VIEW v_rfq_clients
AS
Select 
c.client_id
,CONCAT('C' ,LPAD(c.client_id , 5,'10000')) as client_code
,c.client_UUID
,c.client_name
,c.client_type_code
,c.client_vertical_code
,c.client_status_code
,t.key_value as client_type
,v.key_value as client_vertical
,s.key_value as client_status
-- ,(JSON_UNQUOTE(JSON_EXTRACT(p.client_payload, '$.address.pincode'))) as pincode
,c.pincode
,pn.city_name 
,pn.state_name
,c.created_on
,CONCAT(ap.first_name,' ' , ap.last_name)  as approve_by
,c.approval_on
,o.owner_id
,CONCAT(uo.first_name,' ' , uo.last_name)  as client_owner
,c.active
from rfq_clients c
left Join rfq_kds t on t.key_code = c.client_type_code
left Join rfq_kds v on v.key_code = c.client_vertical_code
left Join rfq_kds s on s.key_code = c.client_status_code
left Join rfq_clients_owners o on o.client_id = c.client_id and o.active = 1
left join rfq_mst_pincode_master pn on pn.pincode = c.pincode
left join mmi_mast_user_registration_detail ap on ap.id = c.approval_id
left join mmi_mast_user_registration_detail uo on uo.id = o.owner_id
;

 Select * from  v_rfq_clients;