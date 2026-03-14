/*
  目的:
    社員ごとの案件配属履歴と現在所属の不整合を監査する。

  想定ユースケース:
    - 配属メンテナンス漏れの検知
    - PMO/人事による配属台帳監査

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - 問題となる案件ID
    - 競合件数
    - 指摘コード

  実装方針:
    - 開いたままの案件履歴と現在所属を別々に集約する。
    - 複数オープン案件、現在所属だけ存在、オープン履歴だけ存在の3種類を返す。
*/
WITH active_employee AS (
  SELECT
    e.employee_id,
    e.employee_code,
    CONCAT(e.family_name, e.last_name) AS employee_name
  FROM employee.employee AS e
  INNER JOIN employee.employee_status AS es
    ON es.employee_status_id = e.employee_status_id
   AND es.employee_status_id = 1
),
open_assignment AS (
  SELECT DISTINCT employee_id, project_id
  FROM employee.assignment_project
  WHERE assignment_project_end_date IS NULL
),
current_project AS (
  SELECT DISTINCT employee_id, project_id
  FROM employee.belonging_project
),
multi_active_project AS (
  SELECT
    ae.employee_id,
    ae.employee_code,
    ae.employee_name,
    CAST(NULL AS SIGNED) AS conflict_project_id,
    COUNT(*) AS conflict_count,
    'MULTI_ACTIVE_PROJECT' AS issue_code
  FROM active_employee AS ae
  INNER JOIN open_assignment AS oa
    ON oa.employee_id = ae.employee_id
  GROUP BY ae.employee_id, ae.employee_code, ae.employee_name
  HAVING COUNT(*) > 1
),
current_without_history AS (
  SELECT
    ae.employee_id,
    ae.employee_code,
    ae.employee_name,
    cp.project_id AS conflict_project_id,
    1 AS conflict_count,
    'CURRENT_WITHOUT_OPEN_HISTORY' AS issue_code
  FROM active_employee AS ae
  INNER JOIN current_project AS cp
    ON cp.employee_id = ae.employee_id
  LEFT JOIN open_assignment AS oa
    ON oa.employee_id = cp.employee_id
   AND oa.project_id = cp.project_id
  WHERE oa.project_id IS NULL
),
history_without_current AS (
  SELECT
    ae.employee_id,
    ae.employee_code,
    ae.employee_name,
    oa.project_id AS conflict_project_id,
    1 AS conflict_count,
    'OPEN_HISTORY_WITHOUT_CURRENT' AS issue_code
  FROM active_employee AS ae
  INNER JOIN open_assignment AS oa
    ON oa.employee_id = ae.employee_id
  LEFT JOIN current_project AS cp
    ON cp.employee_id = oa.employee_id
   AND cp.project_id = oa.project_id
  WHERE cp.project_id IS NULL
)
SELECT
  employee_id,
  employee_code,
  employee_name,
  conflict_project_id,
  conflict_count,
  issue_code
FROM multi_active_project

UNION ALL

SELECT
  employee_id,
  employee_code,
  employee_name,
  conflict_project_id,
  conflict_count,
  issue_code
FROM current_without_history

UNION ALL

SELECT
  employee_id,
  employee_code,
  employee_name,
  conflict_project_id,
  conflict_count,
  issue_code
FROM history_without_current

ORDER BY employee_id, issue_code, conflict_project_id;
