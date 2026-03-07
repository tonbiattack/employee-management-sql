/*
  目的:
    現役社員の「組織所属 + 現役職 + 参画案件数」を1画面で確認する。

  想定ユースケース:
    - 組織図/稼働状況ダッシュボード
    - 1on1や評価面談前の現況確認
*/
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  c.company_name,
  d.department_name,
  dv.division_name,
  t.team_name,
  p.position_name AS current_position_name,
  COUNT(DISTINCT bp.project_id) AS active_project_count
FROM employee.employee AS e
INNER JOIN employee.employee_status AS es
  ON es.employee_status_id = e.employee_status_id
LEFT JOIN employee.belonging_company AS bc
  ON bc.employee_id = e.employee_id
LEFT JOIN employee.company AS c
  ON c.company_id = bc.company_id
LEFT JOIN employee.belonging_department AS bd
  ON bd.employee_id = e.employee_id
LEFT JOIN employee.department AS d
  ON d.department_id = bd.department_id
LEFT JOIN employee.belonging_division AS bdv
  ON bdv.employee_id = e.employee_id
LEFT JOIN employee.division AS dv
  ON dv.division_id = bdv.division_id
LEFT JOIN employee.belonging_team AS bt
  ON bt.employee_id = e.employee_id
LEFT JOIN employee.team AS t
  ON t.team_id = bt.team_id
LEFT JOIN employee.current_position AS cp
  ON cp.employee_id = e.employee_id
LEFT JOIN employee.position AS p
  ON p.position_id = cp.position_id
LEFT JOIN employee.belonging_project AS bp
  ON bp.employee_id = e.employee_id
WHERE es.employee_status_id = 1
GROUP BY
  e.employee_id,
  e.employee_code,
  employee_name,
  c.company_name,
  d.department_name,
  dv.division_name,
  t.team_name,
  current_position_name
ORDER BY e.employee_id;
