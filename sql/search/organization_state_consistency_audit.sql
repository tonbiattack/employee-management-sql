/*
  目的:
    現在値テーブルと期間履歴テーブルの不整合を検出する。

  想定ユースケース:
    - ステータス遷移バッチ後の監査
    - 所属移管や役職変更時のデータ整合性チェック

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - 監査スコープ（COMPANY / DEPARTMENT / DIVISION / TEAM / POSITION）
    - 現在値名称 / 履歴上の継続中名称
    - 監査指摘コード

  実装方針:
    - 現在値テーブル群を `current_state` に正規化する。
    - `*_end_date IS NULL` を継続中履歴として `open_history` に正規化する。
    - 現在値あり・継続中履歴なし、継続中履歴あり・現在値なし、名称不一致を検出する。
*/
WITH current_state AS (
  SELECT bc.employee_id, 'COMPANY' AS audit_scope, c.company_name AS current_value_name
  FROM employee.belonging_company AS bc
  INNER JOIN employee.company AS c
    ON c.company_id = bc.company_id

  UNION ALL

  SELECT bd.employee_id, 'DEPARTMENT' AS audit_scope, d.department_name AS current_value_name
  FROM employee.belonging_department AS bd
  INNER JOIN employee.department AS d
    ON d.department_id = bd.department_id

  UNION ALL

  SELECT bdv.employee_id, 'DIVISION' AS audit_scope, dv.division_name AS current_value_name
  FROM employee.belonging_division AS bdv
  INNER JOIN employee.division AS dv
    ON dv.division_id = bdv.division_id

  UNION ALL

  SELECT bt.employee_id, 'TEAM' AS audit_scope, t.team_name AS current_value_name
  FROM employee.belonging_team AS bt
  INNER JOIN employee.team AS t
    ON t.team_id = bt.team_id

  UNION ALL

  SELECT cp.employee_id, 'POSITION' AS audit_scope, p.position_name AS current_value_name
  FROM employee.current_position AS cp
  INNER JOIN employee.position AS p
    ON p.position_id = cp.position_id
),
open_history AS (
  SELECT ca.employee_id, 'COMPANY' AS audit_scope, c.company_name AS open_history_value_name
  FROM employee.company_assignment AS ca
  INNER JOIN employee.company AS c
    ON c.company_id = ca.company_id
  WHERE ca.company_assignment_end_date IS NULL

  UNION ALL

  SELECT ad.employee_id, 'DEPARTMENT' AS audit_scope, d.department_name AS open_history_value_name
  FROM employee.assigned_department AS ad
  INNER JOIN employee.department AS d
    ON d.department_id = ad.department_id
  WHERE ad.assigned_department_end_date IS NULL

  UNION ALL

  SELECT adv.employee_id, 'DIVISION' AS audit_scope, dv.division_name AS open_history_value_name
  FROM employee.assigned_division AS adv
  INNER JOIN employee.division AS dv
    ON dv.division_id = adv.division_id
  WHERE adv.assigned_division_end_date IS NULL

  UNION ALL

  SELECT at.employee_id, 'TEAM' AS audit_scope, t.team_name AS open_history_value_name
  FROM employee.assigned_team AS at
  INNER JOIN employee.team AS t
    ON t.team_id = at.team_id
  WHERE at.assigned_team_end_date IS NULL

  UNION ALL

  SELECT ap.employee_id, 'POSITION' AS audit_scope, p.position_name AS open_history_value_name
  FROM employee.assumption_of_position AS ap
  INNER JOIN employee.position AS p
    ON p.position_id = ap.position_id
  WHERE ap.assumption_of_position_end_date IS NULL
),
audit_rows AS (
  SELECT
    e.employee_id,
    e.employee_code,
    CONCAT(e.family_name, e.last_name) AS employee_name,
    cs.audit_scope,
    cs.current_value_name,
    oh.open_history_value_name,
    CASE
      WHEN oh.employee_id IS NULL THEN 'CURRENT_WITHOUT_OPEN_HISTORY'
      WHEN cs.current_value_name <> oh.open_history_value_name THEN 'CURRENT_HISTORY_MISMATCH'
    END AS audit_issue_code
  FROM current_state AS cs
  INNER JOIN employee.employee AS e
    ON e.employee_id = cs.employee_id
  LEFT JOIN open_history AS oh
    ON oh.employee_id = cs.employee_id
   AND oh.audit_scope = cs.audit_scope
  WHERE oh.employee_id IS NULL
     OR cs.current_value_name <> oh.open_history_value_name

  UNION ALL

  SELECT
    e.employee_id,
    e.employee_code,
    CONCAT(e.family_name, e.last_name) AS employee_name,
    oh.audit_scope,
    cs.current_value_name,
    oh.open_history_value_name,
    'OPEN_HISTORY_WITHOUT_CURRENT' AS audit_issue_code
  FROM open_history AS oh
  INNER JOIN employee.employee AS e
    ON e.employee_id = oh.employee_id
  LEFT JOIN current_state AS cs
    ON cs.employee_id = oh.employee_id
   AND cs.audit_scope = oh.audit_scope
  WHERE cs.employee_id IS NULL
)
SELECT
  employee_id,
  employee_code,
  employee_name,
  audit_scope,
  current_value_name,
  open_history_value_name,
  audit_issue_code
FROM audit_rows
ORDER BY employee_id, audit_scope, audit_issue_code;
