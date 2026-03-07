-- ========================================
-- SQLファイル: framework_skill_search.sql
-- 目的:
--   指定フレームワーク条件（スキルID + 最低レベル）を満たす現役社員IDを抽出する。
-- 出力:
--   employee_id（候補社員ID）
-- 補足:
--   現状SQLは framework_skill_id=4,3 固定のサンプル実装。
--   実運用ではパラメータ化（可変条件）して利用すること。
-- ========================================

  SELECT
     emp.employee_id
  FROM
    employee_framework_skill as emp_framework
  INNER JOIN 
    employee as emp on
    emp.employee_id = emp_framework.employee_id
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

