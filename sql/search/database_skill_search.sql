-- ========================================
-- SQLファイル: database_skill_search.sql
-- 目的:
--   指定データベーススキル条件（スキルID + 最低レベル）を満たす現役社員IDを抽出する。
-- 出力:
--   employee_id（候補社員ID）
-- 注意:
--   現在の WHERE 句は emp_framework.* を参照しており、
--   エイリアス不一致（emp_databaase との不整合）があるため修正前提。
-- ========================================

  SELECT
     emp.employee_id
  FROM
    employee_database_skill as emp_databaase
  INNER JOIN 
    employee as emp on
    emp.employee_id = emp_databaase.employee_id
  INNER JOIN
    employee_status as es on
    es.employee_status_id = emp.employee_status_id 
    AND
    es.employee_status_id = 1
  WHERE
 emp_framework.skill_level >= 3 AND emp_framework.framework_skill_id = 4 OR  emp_framework.skill_level >= 3 AND emp_framework.framework_skill_id = 3
  GROUP BY 
   emp.employee_id 
  HAVING
   COUNT(*) = 2
  ORDER BY
    emp.employee_id

