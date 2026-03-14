/*
  コピー元:
    - sql/search/evaluation_coverage_audit.sql

  元SQLの問題点:
    - 年度決定、対象社員、期待四半期、欠番集約が単一CTEにまとまり、制度条件を増やすと保守が難しい。
    - どの四半期が欠けたかの途中確認をしづらい。

  この手続き版の方針:
    - 対象年度、対象社員、期待四半期、欠番行を別テーブルに分割する。
    - 最終段で社員単位に集約する。
*/
DROP TEMPORARY TABLE IF EXISTS tmp_evaluation_coverage_latest_year;
CREATE TEMPORARY TABLE tmp_evaluation_coverage_latest_year AS
SELECT MAX(year) AS target_year
FROM employee.evaluation;

DROP TEMPORARY TABLE IF EXISTS tmp_evaluation_coverage_active_employee;
CREATE TEMPORARY TABLE tmp_evaluation_coverage_active_employee AS
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name
FROM employee.employee AS e
INNER JOIN employee.employee_status AS es
  ON es.employee_status_id = e.employee_status_id
 AND es.employee_status_id = 1;

DROP TEMPORARY TABLE IF EXISTS tmp_evaluation_coverage_expected_quarter;
CREATE TEMPORARY TABLE tmp_evaluation_coverage_expected_quarter AS
SELECT 1 AS quarter_no
UNION ALL SELECT 2
UNION ALL SELECT 3
UNION ALL SELECT 4;

DROP TEMPORARY TABLE IF EXISTS tmp_evaluation_coverage_missing_quarter;
CREATE TEMPORARY TABLE tmp_evaluation_coverage_missing_quarter AS
SELECT
  ae.employee_id,
  ae.employee_code,
  ae.employee_name,
  CONCAT(ly.target_year, '-Q', eq.quarter_no) AS missing_quarter
FROM tmp_evaluation_coverage_active_employee AS ae
INNER JOIN tmp_evaluation_coverage_latest_year AS ly
  ON 1 = 1
INNER JOIN tmp_evaluation_coverage_expected_quarter AS eq
  ON 1 = 1
LEFT JOIN employee.evaluation AS ev
  ON ev.employee_id = ae.employee_id
 AND ev.year = ly.target_year
 AND ev.quarter = eq.quarter_no
WHERE ev.evaluation_id IS NULL;

SELECT
  employee_id,
  employee_code,
  employee_name,
  4 AS expected_quarter_count,
  4 - COUNT(*) AS registered_quarter_count,
  GROUP_CONCAT(missing_quarter ORDER BY missing_quarter SEPARATOR ',') AS missing_quarter_list,
  'EVALUATION_QUARTER_MISSING' AS coverage_issue_code
FROM tmp_evaluation_coverage_missing_quarter
GROUP BY employee_id, employee_code, employee_name
HAVING COUNT(*) > 0
ORDER BY employee_id;
