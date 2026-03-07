-- ========================================
-- SQLファイル: database_skill_search_by_employee_ids.sql
-- 目的:
--   社員IDリストに紐づくデータベーススキル詳細を取得する。
-- 出力:
--   database_skill_id / database_skill_name / skill_level
-- 補足:
--   <foreach> を利用する MyBatis 想定SQL。
--   employeeIdList をバインドして動的に IN 句を展開する。
-- ========================================

  SELECT
     database_skill.database_skill_id
    ,database_skill.database_skill_name
    ,emp_databaase.skill_level
  FROM
    employee_database_skill as emp_databaase
  INNER JOIN
    database_skill as database_skill on 
    database_skill.database_skill_id = emp_databaase.database_skill_id
  INNER JOIN 
    employee as emp on
    emp.employee_id = emp_databaase.employee_id
  INNER JOIN
    employee_status as es on
    es.employee_status_id = emp.employee_status_id 
  AND
    es.employee_status_id = 1
  WHERE 
    emp.employee_id in
    <foreach item="item" open="(" close=")" collection="employeeIdList" separator=",">
      #{item}
    </foreach>
  ORDER BY
    emp.employee_id

