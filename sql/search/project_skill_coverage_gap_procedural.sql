/*
  コピー元:
    - sql/search/project_skill_coverage_gap.sql

  元SQLの問題点:
    - 配属、スキル充足、カテゴリ網羅、リスク判定が1本に詰まっており、要件拡張時に差分確認が難しい。
    - 案件要件マスタを将来足す場合の差し込みポイントが見えづらい。

  この手続き版の方針:
    - 配属ベース、社員別ハイスキル、案件別カテゴリ網羅を別テーブルに分離する。
    - 最終段で充足率とリスクレベルを判定する。
*/
DROP TEMPORARY TABLE IF EXISTS tmp_project_skill_assignment_base;
CREATE TEMPORARY TABLE tmp_project_skill_assignment_base AS
SELECT
  ap.project_id,
  p.project_code,
  ap.employee_id
FROM employee.assignment_project AS ap
INNER JOIN employee.project AS p
  ON p.project_id = ap.project_id;

DROP TEMPORARY TABLE IF EXISTS tmp_project_skill_employee_summary;
CREATE TEMPORARY TABLE tmp_project_skill_employee_summary AS
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

DROP TEMPORARY TABLE IF EXISTS tmp_project_skill_category_coverage;
CREATE TEMPORARY TABLE tmp_project_skill_category_coverage AS
SELECT
  ab.project_id,
  COUNT(DISTINCT cat.skill_category) AS covered_skill_category_count
FROM tmp_project_skill_assignment_base AS ab
LEFT JOIN (
  SELECT employee_id, 'DATABASE' AS skill_category FROM employee.employee_database_skill
  UNION ALL
  SELECT employee_id, 'FRAMEWORK' AS skill_category FROM employee.employee_framework_skill
  UNION ALL
  SELECT employee_id, 'INFRASTRUCTURE' AS skill_category FROM employee.employee_infrastructure_skill
  UNION ALL
  SELECT employee_id, 'PROGRAMMING' AS skill_category FROM employee.employee_programming_skill
) AS cat
  ON cat.employee_id = ab.employee_id
GROUP BY ab.project_id;

DROP TEMPORARY TABLE IF EXISTS tmp_project_skill_summary;
CREATE TEMPORARY TABLE tmp_project_skill_summary AS
SELECT
  ab.project_id,
  ab.project_code,
  COUNT(DISTINCT ab.employee_id) AS assigned_member_count,
  COUNT(DISTINCT CASE WHEN ess.is_high_skill = 1 THEN ab.employee_id END) AS high_skill_member_count,
  4 - COALESCE(pcc.covered_skill_category_count, 0) AS missing_skill_category_count
FROM tmp_project_skill_assignment_base AS ab
LEFT JOIN tmp_project_skill_employee_summary AS ess
  ON ess.employee_id = ab.employee_id
LEFT JOIN tmp_project_skill_category_coverage AS pcc
  ON pcc.project_id = ab.project_id
GROUP BY ab.project_id, ab.project_code, pcc.covered_skill_category_count;

SELECT
  pss.project_id,
  pss.project_code,
  pss.assigned_member_count,
  pss.high_skill_member_count,
  CAST(ROUND(
    pss.high_skill_member_count / NULLIF(pss.assigned_member_count, 0),
    2
  ) AS CHAR) AS high_skill_coverage_ratio,
  pss.missing_skill_category_count,
  CASE
    WHEN (pss.high_skill_member_count / NULLIF(pss.assigned_member_count, 0)) < 0.6
      AND pss.missing_skill_category_count >= 2 THEN 'HIGH'
    WHEN (pss.high_skill_member_count / NULLIF(pss.assigned_member_count, 0)) < 0.6 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS staffing_risk_level
FROM tmp_project_skill_summary AS pss
ORDER BY
  CASE
    WHEN (pss.high_skill_member_count / NULLIF(pss.assigned_member_count, 0)) < 0.6
      AND pss.missing_skill_category_count >= 2 THEN 1
    WHEN (pss.high_skill_member_count / NULLIF(pss.assigned_member_count, 0)) < 0.6 THEN 2
    ELSE 3
  END,
  pss.project_id;
