/*
  目的:
    復職後の社員に対して、所属再設定・案件再配置・評価再開の漏れを検出する。

  想定ユースケース:
    - 復職後フォローの抜け漏れ確認
    - 人事と現場の連携確認
*/
WITH reinstated_employee AS (
  SELECT
    r.employee_id,
    MAX(r.reinstatement_date) AS reinstatement_date
  FROM employee.reinstatement AS r
  GROUP BY r.employee_id
),
current_org_count AS (
  SELECT employee_id, COUNT(*) AS current_organization_count
  FROM (
    SELECT employee_id FROM employee.belonging_company
    UNION ALL
    SELECT employee_id FROM employee.belonging_department
    UNION ALL
    SELECT employee_id FROM employee.belonging_division
    UNION ALL
    SELECT employee_id FROM employee.belonging_team
  ) AS x
  GROUP BY employee_id
),
current_project_count AS (
  SELECT employee_id, COUNT(*) AS current_project_count
  FROM employee.belonging_project
  GROUP BY employee_id
),
post_return_evaluation AS (
  SELECT
    r.employee_id,
    COUNT(*) AS post_return_evaluation_count
  FROM reinstated_employee AS r
  INNER JOIN employee.evaluation AS e
    ON e.employee_id = r.employee_id
   AND e.year >= YEAR(r.reinstatement_date)
  GROUP BY r.employee_id
)
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  re.reinstatement_date,
  COALESCE(coc.current_organization_count, 0) AS current_organization_count,
  COALESCE(cpc.current_project_count, 0) AS current_project_count,
  COALESCE(pre.post_return_evaluation_count, 0) AS post_return_evaluation_count,
  'POST_RETURN_PROJECT_MISSING' AS issue_code
FROM reinstated_employee AS re
INNER JOIN employee.employee AS e
  ON e.employee_id = re.employee_id
LEFT JOIN current_org_count AS coc
  ON coc.employee_id = re.employee_id
LEFT JOIN current_project_count AS cpc
  ON cpc.employee_id = re.employee_id
LEFT JOIN post_return_evaluation AS pre
  ON pre.employee_id = re.employee_id
WHERE COALESCE(cpc.current_project_count, 0) = 0

UNION ALL

SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  re.reinstatement_date,
  COALESCE(coc.current_organization_count, 0) AS current_organization_count,
  COALESCE(cpc.current_project_count, 0) AS current_project_count,
  COALESCE(pre.post_return_evaluation_count, 0) AS post_return_evaluation_count,
  'POST_RETURN_EVALUATION_MISSING' AS issue_code
FROM reinstated_employee AS re
INNER JOIN employee.employee AS e
  ON e.employee_id = re.employee_id
LEFT JOIN current_org_count AS coc
  ON coc.employee_id = re.employee_id
LEFT JOIN current_project_count AS cpc
  ON cpc.employee_id = re.employee_id
LEFT JOIN post_return_evaluation AS pre
  ON pre.employee_id = re.employee_id
WHERE COALESCE(pre.post_return_evaluation_count, 0) = 0

ORDER BY employee_id, issue_code;
