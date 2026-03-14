/*
  目的:
    案件ごとの配属開始・終了・現行所属を時系列で確認する。

  想定ユースケース:
    - PM の配属履歴確認
    - 完了案件の残留確認
*/
SELECT
  p.project_id,
  p.project_code,
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  ap.assignment_project_date AS start_date,
  ap.assignment_project_end_date AS end_date,
  CASE
    WHEN bp.employee_id IS NOT NULL
      AND ap.assignment_project_end_date IS NULL THEN 1
    ELSE 0
  END AS is_current
FROM employee.assignment_project AS ap
INNER JOIN employee.project AS p
  ON p.project_id = ap.project_id
INNER JOIN employee.employee AS e
  ON e.employee_id = ap.employee_id
LEFT JOIN employee.belonging_project AS bp
  ON bp.project_id = ap.project_id
 AND bp.employee_id = ap.employee_id
ORDER BY p.project_id, ap.assignment_project_date, e.employee_id;
