/*
  コピー元:
    - sql/search/leave_return_followup_summary.sql

  元SQLの問題点:
    - 復職対象抽出と不足課題展開が1本にまとまっており、後続のタスク生成に繋げにくい。
    - どの段階で何が不足しているかを確認しづらい。

  この手続き版の方針:
    - 復職社員、現在所属件数、案件件数、復職後評価件数を段階的に保持する。
    - 課題コードの展開は最後に行う。
*/
DROP TEMPORARY TABLE IF EXISTS tmp_leave_return_reinstated_employee;
CREATE TEMPORARY TABLE tmp_leave_return_reinstated_employee AS
SELECT
  r.employee_id,
  MAX(r.reinstatement_date) AS reinstatement_date
FROM employee.reinstatement AS r
GROUP BY r.employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_leave_return_current_org_count;
CREATE TEMPORARY TABLE tmp_leave_return_current_org_count AS
SELECT employee_id, COUNT(*) AS current_organization_count
FROM (
  SELECT employee_id FROM employee.belonging_company
  UNION ALL
  SELECT employee_id FROM employee.belonging_department
  UNION ALL
  SELECT employee_id FROM employee.belonging_division
  UNION ALL
  SELECT employee_id FROM employee.belonging_team
) AS org_rows
GROUP BY employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_leave_return_current_project_count;
CREATE TEMPORARY TABLE tmp_leave_return_current_project_count AS
SELECT employee_id, COUNT(*) AS current_project_count
FROM employee.belonging_project
GROUP BY employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_leave_return_post_return_evaluation;
CREATE TEMPORARY TABLE tmp_leave_return_post_return_evaluation AS
SELECT
  r.employee_id,
  COUNT(*) AS post_return_evaluation_count
FROM tmp_leave_return_reinstated_employee AS r
INNER JOIN employee.evaluation AS e
  ON e.employee_id = r.employee_id
 AND e.year >= YEAR(r.reinstatement_date)
GROUP BY r.employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_leave_return_summary;
CREATE TEMPORARY TABLE tmp_leave_return_summary AS
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  re.reinstatement_date,
  COALESCE(coc.current_organization_count, 0) AS current_organization_count,
  COALESCE(cpc.current_project_count, 0) AS current_project_count,
  COALESCE(pre.post_return_evaluation_count, 0) AS post_return_evaluation_count
FROM tmp_leave_return_reinstated_employee AS re
INNER JOIN employee.employee AS e
  ON e.employee_id = re.employee_id
LEFT JOIN tmp_leave_return_current_org_count AS coc
  ON coc.employee_id = re.employee_id
LEFT JOIN tmp_leave_return_current_project_count AS cpc
  ON cpc.employee_id = re.employee_id
LEFT JOIN tmp_leave_return_post_return_evaluation AS pre
  ON pre.employee_id = re.employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_leave_return_issue_project_missing;
CREATE TEMPORARY TABLE tmp_leave_return_issue_project_missing AS
SELECT employee_id, 'POST_RETURN_PROJECT_MISSING' AS issue_code
FROM tmp_leave_return_summary
WHERE current_project_count = 0;

DROP TEMPORARY TABLE IF EXISTS tmp_leave_return_issue_evaluation_missing;
CREATE TEMPORARY TABLE tmp_leave_return_issue_evaluation_missing AS
SELECT employee_id, 'POST_RETURN_EVALUATION_MISSING' AS issue_code
FROM tmp_leave_return_summary
WHERE post_return_evaluation_count = 0;

DROP TEMPORARY TABLE IF EXISTS tmp_leave_return_issue;
CREATE TEMPORARY TABLE tmp_leave_return_issue AS
SELECT * FROM tmp_leave_return_issue_project_missing
UNION ALL
SELECT * FROM tmp_leave_return_issue_evaluation_missing;

SELECT
  lrs.employee_id,
  lrs.employee_code,
  lrs.employee_name,
  lrs.reinstatement_date,
  lrs.current_organization_count,
  lrs.current_project_count,
  lrs.post_return_evaluation_count,
  issue.issue_code
FROM tmp_leave_return_summary AS lrs
INNER JOIN tmp_leave_return_issue AS issue
  ON issue.employee_id = lrs.employee_id
ORDER BY lrs.employee_id, issue.issue_code;
