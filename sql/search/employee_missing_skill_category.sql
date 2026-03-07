/*
  目的:
    現役社員ごとに「未登録のスキルカテゴリ」を検出する。
    （DATABASE / FRAMEWORK / INFRASTRUCTURE / PROGRAMMING の4カテゴリ）

  主な用途:
    - スキル情報の入力漏れ検出
    - 育成計画上の空白領域の可視化

  出力:
    employee_id / employee_code / employee_name / missing_skill_category
*/
WITH categories AS (
  SELECT 'DATABASE' AS skill_type
  UNION ALL SELECT 'FRAMEWORK'
  UNION ALL SELECT 'INFRASTRUCTURE'
  UNION ALL SELECT 'PROGRAMMING'
),
employee_skill_categories AS (
  SELECT DISTINCT employee_id, 'DATABASE' AS skill_type FROM employee.employee_database_skill
  UNION ALL
  SELECT DISTINCT employee_id, 'FRAMEWORK' AS skill_type FROM employee.employee_framework_skill
  UNION ALL
  SELECT DISTINCT employee_id, 'INFRASTRUCTURE' AS skill_type FROM employee.employee_infrastructure_skill
  UNION ALL
  SELECT DISTINCT employee_id, 'PROGRAMMING' AS skill_type FROM employee.employee_programming_skill
)
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  c.skill_type AS missing_skill_category
FROM employee.employee AS e
INNER JOIN employee.employee_status AS es
  ON es.employee_status_id = e.employee_status_id
CROSS JOIN categories AS c
LEFT JOIN employee_skill_categories AS esc
  ON esc.employee_id = e.employee_id
 AND esc.skill_type = c.skill_type
WHERE es.employee_status_id = 1
  AND esc.employee_id IS NULL
ORDER BY e.employee_id, c.skill_type;
