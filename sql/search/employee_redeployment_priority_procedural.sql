/*
  コピー元:
    - sql/search/employee_redeployment_priority.sql

  元SQLの問題点:
    - 優先度判定の材料が1本のCTE連鎖に集約されており、途中結果を業務側が確認しにくい。
    - 閾値や判定条件を増やすと、単一SQLの可読性が急速に落ちる。

  この手続き版の方針:
    - 評価、スキル、未登録カテゴリ、現在所属を段階テーブルに分解する。
    - 最後の優先度判定だけを最終SELECTに集約し、途中検証しやすくする。
*/
DROP TEMPORARY TABLE IF EXISTS tmp_redeployment_latest_evaluation;
CREATE TEMPORARY TABLE tmp_redeployment_latest_evaluation AS
SELECT employee_id, evaluation
FROM (
  SELECT
    ev.employee_id,
    ev.evaluation,
    ROW_NUMBER() OVER (
      PARTITION BY ev.employee_id
      ORDER BY ev.year DESC, ev.quarter DESC
    ) AS rn
  FROM employee.evaluation AS ev
) AS ranked
WHERE rn = 1;

DROP TEMPORARY TABLE IF EXISTS tmp_redeployment_all_skill_rows;
CREATE TEMPORARY TABLE tmp_redeployment_all_skill_rows AS
SELECT employee_id, skill_level, 'DATABASE' AS skill_category FROM employee.employee_database_skill
UNION ALL
SELECT employee_id, skill_level, 'FRAMEWORK' AS skill_category FROM employee.employee_framework_skill
UNION ALL
SELECT employee_id, skill_level, 'INFRASTRUCTURE' AS skill_category FROM employee.employee_infrastructure_skill
UNION ALL
SELECT employee_id, skill_level, 'PROGRAMMING' AS skill_category FROM employee.employee_programming_skill;

DROP TEMPORARY TABLE IF EXISTS tmp_redeployment_skill_summary;
CREATE TEMPORARY TABLE tmp_redeployment_skill_summary AS
SELECT
  employee_id,
  COUNT(CASE WHEN skill_level >= 8 THEN 1 END) AS high_skill_count
FROM tmp_redeployment_all_skill_rows
GROUP BY employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_redeployment_skill_coverage;
CREATE TEMPORARY TABLE tmp_redeployment_skill_coverage AS
SELECT DISTINCT employee_id, skill_category
FROM tmp_redeployment_all_skill_rows;

DROP TEMPORARY TABLE IF EXISTS tmp_redeployment_missing_skill_category_summary;
CREATE TEMPORARY TABLE tmp_redeployment_missing_skill_category_summary AS
SELECT
  e.employee_id,
  SUM(CASE WHEN covered.skill_category IS NULL THEN 1 ELSE 0 END) AS missing_skill_category_count
FROM employee.employee AS e
LEFT JOIN (
  SELECT 'DATABASE' AS skill_category
  UNION ALL SELECT 'FRAMEWORK'
  UNION ALL SELECT 'INFRASTRUCTURE'
  UNION ALL SELECT 'PROGRAMMING'
) AS catalog
  ON 1 = 1
LEFT JOIN tmp_redeployment_skill_coverage AS covered
  ON covered.employee_id = e.employee_id
 AND covered.skill_category = catalog.skill_category
GROUP BY e.employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_redeployment_active_context;
CREATE TEMPORARY TABLE tmp_redeployment_active_context AS
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  c.company_name,
  t.team_name,
  p.position_name AS current_position_name,
  le.evaluation AS latest_evaluation,
  COALESCE(ss.high_skill_count, 0) AS high_skill_count,
  COALESCE(ms.missing_skill_category_count, 4) AS missing_skill_category_count,
  CASE
    WHEN bp.project_id IS NULL THEN 'PROJECT_UNASSIGNED'
    WHEN bt.team_id IS NULL THEN 'TEAM_UNASSIGNED'
    ELSE 'ASSIGNED'
  END AS assignment_status
FROM employee.employee AS e
INNER JOIN employee.employee_status AS es
  ON es.employee_status_id = e.employee_status_id
 AND es.employee_status_id = 1
LEFT JOIN employee.belonging_company AS bc
  ON bc.employee_id = e.employee_id
LEFT JOIN employee.company AS c
  ON c.company_id = bc.company_id
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
LEFT JOIN tmp_redeployment_latest_evaluation AS le
  ON le.employee_id = e.employee_id
LEFT JOIN tmp_redeployment_skill_summary AS ss
  ON ss.employee_id = e.employee_id
LEFT JOIN tmp_redeployment_missing_skill_category_summary AS ms
  ON ms.employee_id = e.employee_id;

SELECT
  employee_id,
  employee_code,
  employee_name,
  company_name,
  team_name,
  current_position_name,
  latest_evaluation,
  high_skill_count,
  missing_skill_category_count,
  assignment_status,
  CASE
    WHEN assignment_status = 'PROJECT_UNASSIGNED'
      AND COALESCE(latest_evaluation, 0) >= 7
      AND high_skill_count >= 1 THEN 'HIGH'
    WHEN assignment_status IN ('PROJECT_UNASSIGNED', 'TEAM_UNASSIGNED')
      AND COALESCE(latest_evaluation, 0) >= 5 THEN 'MEDIUM'
    WHEN assignment_status IN ('PROJECT_UNASSIGNED', 'TEAM_UNASSIGNED') THEN 'LOW'
    ELSE 'ASSIGNED'
  END AS redeployment_priority
FROM tmp_redeployment_active_context
WHERE assignment_status IN ('PROJECT_UNASSIGNED', 'TEAM_UNASSIGNED')
ORDER BY
  CASE
    WHEN assignment_status = 'PROJECT_UNASSIGNED'
      AND COALESCE(latest_evaluation, 0) >= 7
      AND high_skill_count >= 1 THEN 1
    WHEN assignment_status IN ('PROJECT_UNASSIGNED', 'TEAM_UNASSIGNED')
      AND COALESCE(latest_evaluation, 0) >= 5 THEN 2
    ELSE 3
  END,
  high_skill_count DESC,
  COALESCE(latest_evaluation, 0) DESC,
  employee_id;
