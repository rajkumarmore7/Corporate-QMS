use misp_crm_corpo;

DROP PROCEDURE IF EXISTS rfq_sp_get_user_hierarchy;

DELIMITER $$

CREATE PROCEDURE rfq_sp_get_user_hierarchy(
    IN p_user_id BIGINT,
    OUT p_hierarchy JSON
)
BEGIN

    WITH RECURSIVE

    up_hierarchy AS (
        SELECT user_id, supervisor_id
        FROM mmi_user_reporting
        WHERE user_id = p_user_id

        UNION ALL

        SELECT m.user_id, m.supervisor_id
        FROM mmi_user_reporting m
        JOIN up_hierarchy u
            ON m.user_id = u.supervisor_id
    ),

    down_hierarchy AS (
        SELECT user_id, supervisor_id
        FROM mmi_user_reporting
        WHERE user_id = p_user_id

        UNION ALL

        SELECT m.user_id, m.supervisor_id
        FROM mmi_user_reporting m
        JOIN down_hierarchy d
            ON m.supervisor_id = d.user_id
    )

    SELECT JSON_ARRAYAGG(user_id)
    INTO p_hierarchy
    FROM (
        SELECT DISTINCT user_id
        FROM (
            SELECT user_id FROM up_hierarchy
            UNION
            SELECT user_id FROM down_hierarchy
        ) x
    ) y;

END$$

DELIMITER ;


CALL rfq_sp_get_user_hierarchy(91, @hierarchy);

SELECT @hierarchy, JSON_CONTAINS( @hierarchy, CAST(91 AS JSON),'$')
