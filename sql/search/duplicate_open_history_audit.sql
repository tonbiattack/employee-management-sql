/*
  目的:
    同一社員に対して継続中履歴が複数存在する不整合を検出する。

  想定ユースケース:
    - 履歴テーブルの定期監査
    - バッチ不具合や手修正事故の検知
*/
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  x.history_type,
  x.open_record_count,
  'DUPLICATE_OPEN_HISTORY' AS issue_code
FROM (
  SELECT employee_id, 'COMPANY' AS history_type, COUNT(*) AS open_record_count
  FROM employee.company_assignment
  WHERE company_assignment_end_date IS NULL
  GROUP BY employee_id
  HAVING COUNT(*) > 1

  UNION ALL

  SELECT employee_id, 'DEPARTMENT' AS history_type, COUNT(*) AS open_record_count
  FROM employee.assigned_department
  WHERE assigned_department_end_date IS NULL
  GROUP BY employee_id
  HAVING COUNT(*) > 1

  UNION ALL

  SELECT employee_id, 'DIVISION' AS history_type, COUNT(*) AS open_record_count
  FROM employee.assigned_division
  WHERE assigned_division_end_date IS NULL
  GROUP BY employee_id
  HAVING COUNT(*) > 1

  UNION ALL

  SELECT employee_id, 'TEAM' AS history_type, COUNT(*) AS open_record_count
  FROM employee.assigned_team
  WHERE assigned_team_end_date IS NULL
  GROUP BY employee_id
  HAVING COUNT(*) > 1

  UNION ALL

  SELECT employee_id, 'PROJECT' AS history_type, COUNT(*) AS open_record_count
  FROM employee.assignment_project
  WHERE assignment_project_end_date IS NULL
  GROUP BY employee_id
  HAVING COUNT(*) > 1

  UNION ALL

  SELECT employee_id, 'POSITION' AS history_type, COUNT(*) AS open_record_count
  FROM employee.assumption_of_position
  WHERE assumption_of_position_end_date IS NULL
  GROUP BY employee_id
  HAVING COUNT(*) > 1
) AS x
INNER JOIN employee.employee AS e
  ON e.employee_id = x.employee_id
ORDER BY e.employee_id, x.history_type;
