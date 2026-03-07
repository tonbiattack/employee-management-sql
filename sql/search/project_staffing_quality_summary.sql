/*
  目的:
    案件単位で「アサイン人数」「ハイスキル人数」「最新評価平均」を確認する。

  想定ユースケース:
    - PM向けの案件健全性モニタリング
    - 人員計画（案件の人材強度確認）
*/
WITH latest_evaluation AS (
  SELECT
    e.employee_id,
    e.evaluation,
    ROW_NUMBER() OVER (
      PARTITION BY e.employee_id
      ORDER BY e.year DESC, e.quarter DESC
    ) AS rn
  FROM employee.evaluation AS e
),
employee_is_high_skill AS (
  SELECT
    s.employee_id,
    MAX(CASE WHEN s.skill_level >= 8 THEN 1 ELSE 0 END) AS is_high_skill
  FROM (
    SELECT employee_id, skill_level FROM employee.employee_database_skill
    UNION ALL
    SELECT employee_id, skill_level FROM employee.employee_framework_skill
    UNION ALL
    SELECT employee_id, skill_level FROM employee.employee_infrastructure_skill
    UNION ALL
    SELECT employee_id, skill_level FROM employee.employee_programming_skill
  ) AS s
  GROUP BY s.employee_id
)
SELECT
  p.project_id,
  p.project_code,
  p.project_content,
  bp.business_partner_name,
  COUNT(DISTINCT ap.employee_id) AS assigned_member_count,
  COUNT(DISTINCT CASE WHEN hs.is_high_skill = 1 THEN ap.employee_id END) AS high_skill_member_count,
  ROUND(AVG(le.evaluation), 2) AS avg_latest_evaluation
FROM employee.project AS p
INNER JOIN employee.business_partner AS bp
  ON bp.business_partner_id = p.business_partner_id
LEFT JOIN employee.assignment_project AS ap
  ON ap.project_id = p.project_id
LEFT JOIN employee_is_high_skill AS hs
  ON hs.employee_id = ap.employee_id
LEFT JOIN latest_evaluation AS le
  ON le.employee_id = ap.employee_id
 AND le.rn = 1
GROUP BY
  p.project_id,
  p.project_code,
  p.project_content,
  bp.business_partner_name
ORDER BY p.project_id;
