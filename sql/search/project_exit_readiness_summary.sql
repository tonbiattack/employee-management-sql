/*
  目的:
    完了報告前の案件について、離任・記録・所属解除の準備状況を要約する。

  想定ユースケース:
    - 案件クローズ前チェック
    - PMOの週次棚卸し

  主要な出力項目:
    - 案件ID / 案件コード
    - 想定離任完了日
    - 終了済み配属人数 / 現在所属人数 / 記録人数 / 未完了人数
    - 準備状態

  実装方針:
    - 終了日付き配属履歴がある案件を対象にする。
    - 完了報告済み案件は除外し、クローズ準備中の案件だけを見る。
    - 所属残りと記録不足人数から READY / NOT_READY を判定する。
*/
WITH ended_assignment_summary AS (
  SELECT
    ap.project_id,
    MAX(ap.assignment_project_end_date) AS planned_exit_date,
    COUNT(DISTINCT ap.employee_id) AS ended_assignment_count
  FROM employee.assignment_project AS ap
  WHERE ap.assignment_project_end_date IS NOT NULL
  GROUP BY ap.project_id
),
current_belonging_summary AS (
  SELECT
    bp.project_id,
    COUNT(DISTINCT bp.employee_id) AS current_belonging_count
  FROM employee.belonging_project AS bp
  GROUP BY bp.project_id
),
project_record_summary AS (
  SELECT
    epr.project_id,
    COUNT(DISTINCT epr.employee_id) AS project_record_count
  FROM employee.employee_project_record AS epr
  GROUP BY epr.project_id
)
SELECT
  p.project_id,
  p.project_code,
  eas.planned_exit_date,
  eas.ended_assignment_count,
  COALESCE(cbs.current_belonging_count, 0) AS current_belonging_count,
  COALESCE(prs.project_record_count, 0) AS project_record_count,
  GREATEST(eas.ended_assignment_count - COALESCE(prs.project_record_count, 0), 0) AS pending_exit_member_count,
  CASE
    WHEN COALESCE(cbs.current_belonging_count, 0) = 0
      AND GREATEST(eas.ended_assignment_count - COALESCE(prs.project_record_count, 0), 0) = 0 THEN 'READY'
    ELSE 'NOT_READY'
  END AS readiness_status
FROM ended_assignment_summary AS eas
INNER JOIN employee.project AS p
  ON p.project_id = eas.project_id
LEFT JOIN employee.project_completion_report AS pcr
  ON pcr.project_id = eas.project_id
LEFT JOIN current_belonging_summary AS cbs
  ON cbs.project_id = eas.project_id
LEFT JOIN project_record_summary AS prs
  ON prs.project_id = eas.project_id
WHERE pcr.project_id IS NULL
ORDER BY
  CASE readiness_status
    WHEN 'NOT_READY' THEN 1
    ELSE 2
  END,
  eas.planned_exit_date,
  p.project_id;
