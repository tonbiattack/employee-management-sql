-- ========================================
-- SQLファイル: programming_skill_search.sql
-- 目的:
--   指定プログラミングスキル条件を満たす現役社員を抽出する。
-- 出力:
--   employee_id と一致件数（count）
-- 補足:
--   現状SQLは programming_skill_id=4,3 固定条件のサンプル実装。
--   実運用では条件をパラメータ化して検索画面/APIに渡すこと。
-- ========================================

  SELECT
     emp.employee_id    ,
     count(*)
  FROM
    employee_programming_skill as emp_program
  INNER JOIN 
    employee as emp on
    emp.employee_id = emp_program.employee_id
  INNER JOIN
    employee_status as es on
    es.employee_status_id = emp.employee_status_id 
    AND
    es.employee_status_id = 1
  WHERE emp_program.skill_level >= 3 AND emp_program.programming_skill_id = 4 OR  emp_program.skill_level >= 3 AND emp_program.programming_skill_id = 3
  GROUP BY 
   emp.employee_id 
  HAVING
   count(*) =2
  ORDER BY
    emp.employee_id
   
  


