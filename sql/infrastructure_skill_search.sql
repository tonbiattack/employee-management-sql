-- ========================================
-- SQLファイル: infrastructure_skill_search.sql
-- 目的:
--   指定インフラスキル条件を満たす現役社員を抽出する。
-- 出力:
--   employee_id と一致件数（count）
-- 補足:
--   現状SQLは infrastructure_skill_id=4,3 固定のサンプル条件。
--   実運用では閾値・対象IDをパラメータ化して再利用すること。
-- ========================================

  SELECT
     emp.employee_id    ,
     count(*)
  FROM
    employee_infrastructure_skill as emp_infra
  INNER JOIN 
    employee as emp on
    emp.employee_id = emp_infra.employee_id
  INNER JOIN
    employee_status as es on
    es.employee_status_id = emp.employee_status_id 
    AND
    es.employee_status_id = 1
  WHERE emp_infra.skill_level >= 3 AND emp_infra.infrastructure_skill_id = 4 OR  emp_infra.skill_level >= 3 AND emp_infra.infrastructure_skill_id = 3
  GROUP BY 
   emp.employee_id 
  HAVING
   count(*) =2
  ORDER BY
    emp.employee_id
   
  

