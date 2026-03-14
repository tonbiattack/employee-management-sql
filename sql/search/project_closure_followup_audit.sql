/*
  目的:
    完了済み案件について、離任記録不足や現行所属残りを監査する。

  想定ユースケース:
    - 案件クローズ後の事務フォロー
    - 月次の案件棚卸し監査

  主要な出力項目:
    - 案件ID / 案件コード / 完了日
    - 配属人数 / 実績記録件数 / 現行所属人数 / 記録不足人数
    - 指摘コード

  実装方針:
    - 完了案件ごとの人数系指標を先に集約する。
    - 課題ごとに1行返すよう `UNION ALL` で監査結果を展開する。
*/
WITH assignment_summary AS (
  SELECT
    ap.project_id,
    COUNT(DISTINCT ap.employee_id) AS assigned_member_count
  FROM employee.assignment_project AS ap
  GROUP BY ap.project_id
),
project_record_summary AS (
  SELECT
    epr.project_id,
    COUNT(DISTINCT epr.employee_id) AS project_record_count
  FROM employee.employee_project_record AS epr
  GROUP BY epr.project_id
),
current_belonging_summary AS (
  SELECT
    bp.project_id,
    COUNT(DISTINCT bp.employee_id) AS current_belonging_member_count
  FROM employee.belonging_project AS bp
  GROUP BY bp.project_id
),
project_closure_summary AS (
  SELECT
    p.project_id,
    p.project_code,
    pcr.project_completion_date,
    COALESCE(asu.assigned_member_count, 0) AS assigned_member_count,
    COALESCE(prs.project_record_count, 0) AS project_record_count,
    COALESCE(cbs.current_belonging_member_count, 0) AS current_belonging_member_count,
    COALESCE(asu.assigned_member_count, 0) - COALESCE(prs.project_record_count, 0) AS missing_project_record_count
  FROM employee.project_completion_report AS pcr
  INNER JOIN employee.project AS p
    ON p.project_id = pcr.project_id
  LEFT JOIN assignment_summary AS asu
    ON asu.project_id = p.project_id
  LEFT JOIN project_record_summary AS prs
    ON prs.project_id = p.project_id
  LEFT JOIN current_belonging_summary AS cbs
    ON cbs.project_id = p.project_id
)
SELECT
  pcs.project_id,
  pcs.project_code,
  pcs.project_completion_date,
  pcs.assigned_member_count,
  pcs.project_record_count,
  pcs.current_belonging_member_count,
  pcs.missing_project_record_count,
  'COMPLETED_PROJECT_HAS_ACTIVE_BELONGING' AS audit_issue_code
FROM project_closure_summary AS pcs
WHERE pcs.current_belonging_member_count > 0

UNION ALL

SELECT
  pcs.project_id,
  pcs.project_code,
  pcs.project_completion_date,
  pcs.assigned_member_count,
  pcs.project_record_count,
  pcs.current_belonging_member_count,
  pcs.missing_project_record_count,
  'COMPLETED_PROJECT_MISSING_RECORDS' AS audit_issue_code
FROM project_closure_summary AS pcs
WHERE pcs.missing_project_record_count > 0

ORDER BY project_completion_date, project_id, audit_issue_code;
