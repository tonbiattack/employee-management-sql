-- ========================================
-- SQLファイル: framework_skill_search_by_employee_ids.sql
-- 目的:
--   社員IDリストを入力として、対象社員のフレームワークスキル詳細を取得する。
-- 出力:
--   framework_skill_id / framework_skill_name / skill_level
-- 補足:
--   現状は (61,91) 固定値。実運用では IN 句をバインド変数化すること。
-- ========================================

  SELECT
     framework_skill.framework_skill_id
    ,framework_skill.framework_skill_name
    ,emp_framework.skill_level
  FROM
    employee_framework_skill as emp_framework
  INNER JOIN
    framework_skill as framework_skill on 
    framework_skill.framework_skill_id = emp_framework.framework_skill_id
  INNER JOIN 
    employee as emp on
    emp.employee_id = emp_framework.employee_id
  INNER JOIN
    employee_status as es on
    es.employee_status_id = emp.employee_status_id 
  AND
    es.employee_status_id = 1
  WHERE 
    emp.employee_id in
    (61,91)
  ORDER BY
    emp.employee_id

