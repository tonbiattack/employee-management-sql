/*
  目的:
    組織解体時に影響を受ける社員・案件・ハイスキル要員数を要約する。

  想定ユースケース:
    - 組織解体前の影響確認
    - 所属解除バッチ実行前のレビュー

  SQLでやりすぎない判断:
    - 「誰をどの順序で移管するか」「どの案件を先に閉じるか」といった
      実行計画そのものは手続き型ロジックで扱うほうがよい。
    - このSQLはあくまで影響の見積もりまでに留める。
*/
WITH employee_high_skill AS (
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
),
team_impact AS (
  SELECT
    'TEAM' AS organization_type,
    t.team_id AS organization_id,
    t.team_name AS organization_name,
    COUNT(DISTINCT bt.employee_id) AS affected_employee_count,
    COUNT(DISTINCT bp.employee_id) AS active_project_member_count,
    COUNT(DISTINCT CASE WHEN ehs.is_high_skill = 1 THEN bt.employee_id END) AS high_skill_employee_count
  FROM employee.team AS t
  LEFT JOIN employee.belonging_team AS bt
    ON bt.team_id = t.team_id
  LEFT JOIN employee.belonging_project AS bp
    ON bp.employee_id = bt.employee_id
  LEFT JOIN employee_high_skill AS ehs
    ON ehs.employee_id = bt.employee_id
  GROUP BY t.team_id, t.team_name
)
SELECT
  organization_type,
  organization_id,
  organization_name,
  affected_employee_count,
  active_project_member_count,
  high_skill_employee_count,
  CASE
    WHEN affected_employee_count >= 2
      AND (active_project_member_count >= 1 OR high_skill_employee_count >= 1) THEN 'HIGH'
    WHEN affected_employee_count >= 1 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS impact_risk_level
FROM team_impact
ORDER BY
  CASE
    WHEN affected_employee_count >= 2
      AND (active_project_member_count >= 1 OR high_skill_employee_count >= 1) THEN 1
    WHEN affected_employee_count >= 1 THEN 2
    ELSE 3
  END,
  organization_id;
