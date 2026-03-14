/*
  コピー元:
    - sql/search/org_dismantle_impact_summary.sql

  元SQLの問題点:
    - ハイスキル判定と影響集計が同居しており、組織種別を増やすと見通しが悪くなる。
    - 影響見積もりの途中結果をレビューしづらい。

  この手続き版の方針:
    - ハイスキル社員判定、チーム所属、案件所属を別段階で保持する。
    - 最後のリスク評価だけを要約段階に残す。
*/
DROP TEMPORARY TABLE IF EXISTS tmp_org_impact_high_skill_employee;
CREATE TEMPORARY TABLE tmp_org_impact_high_skill_employee AS
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
GROUP BY s.employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_org_impact_team_member;
CREATE TEMPORARY TABLE tmp_org_impact_team_member AS
SELECT
  t.team_id,
  t.team_name,
  bt.employee_id
FROM employee.team AS t
LEFT JOIN employee.belonging_team AS bt
  ON bt.team_id = t.team_id;

DROP TEMPORARY TABLE IF EXISTS tmp_org_impact_team_summary;
CREATE TEMPORARY TABLE tmp_org_impact_team_summary AS
SELECT
  'TEAM' AS organization_type,
  tm.team_id AS organization_id,
  tm.team_name AS organization_name,
  COUNT(DISTINCT tm.employee_id) AS affected_employee_count,
  COUNT(DISTINCT bp.employee_id) AS active_project_member_count,
  COUNT(DISTINCT CASE WHEN hs.is_high_skill = 1 THEN tm.employee_id END) AS high_skill_employee_count
FROM tmp_org_impact_team_member AS tm
LEFT JOIN employee.belonging_project AS bp
  ON bp.employee_id = tm.employee_id
LEFT JOIN tmp_org_impact_high_skill_employee AS hs
  ON hs.employee_id = tm.employee_id
GROUP BY tm.team_id, tm.team_name;

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
FROM tmp_org_impact_team_summary
ORDER BY
  CASE
    WHEN affected_employee_count >= 2
      AND (active_project_member_count >= 1 OR high_skill_employee_count >= 1) THEN 1
    WHEN affected_employee_count >= 1 THEN 2
    ELSE 3
  END,
  organization_id;
