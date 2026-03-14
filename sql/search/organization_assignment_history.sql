/*
  目的:
    社員ごとの会社・部署・課・チーム・役職の履歴を時系列で確認する。

  想定ユースケース:
    - 配属変更や昇格の履歴監査
    - 人事面談時の所属変遷確認

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - 履歴種別（会社 / 部署 / 課 / チーム / 役職）
    - 履歴名 / 開始日 / 終了日

  実装方針:
    - 期間管理テーブルを `UNION ALL` で束ねる。
    - 現行継続中の履歴は `end_date` が `NULL` のまま返す。
    - 社員、開始日、種別の順に並べて時系列比較しやすくする。
*/
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  h.history_type,
  h.history_name,
  h.start_date,
  h.end_date
FROM (
  SELECT
    ca.employee_id,
    'COMPANY' AS history_type,
    c.company_name AS history_name,
    ca.company_assignment_date AS start_date,
    ca.company_assignment_end_date AS end_date
  FROM employee.company_assignment AS ca
  INNER JOIN employee.company AS c
    ON c.company_id = ca.company_id

  UNION ALL

  SELECT
    ad.employee_id,
    'DEPARTMENT' AS history_type,
    d.department_name AS history_name,
    ad.assigned_department_date AS start_date,
    ad.assigned_department_end_date AS end_date
  FROM employee.assigned_department AS ad
  INNER JOIN employee.department AS d
    ON d.department_id = ad.department_id

  UNION ALL

  SELECT
    adv.employee_id,
    'DIVISION' AS history_type,
    dv.division_name AS history_name,
    adv.assigned_division_date AS start_date,
    adv.assigned_division_end_date AS end_date
  FROM employee.assigned_division AS adv
  INNER JOIN employee.division AS dv
    ON dv.division_id = adv.division_id

  UNION ALL

  SELECT
    at.employee_id,
    'TEAM' AS history_type,
    t.team_name AS history_name,
    at.assigned_team_date AS start_date,
    at.assigned_team_end_date AS end_date
  FROM employee.assigned_team AS at
  INNER JOIN employee.team AS t
    ON t.team_id = at.team_id

  UNION ALL

  SELECT
    ap.employee_id,
    'POSITION' AS history_type,
    p.position_name AS history_name,
    ap.assumption_of_position_date AS start_date,
    ap.assumption_of_position_end_date AS end_date
  FROM employee.assumption_of_position AS ap
  INNER JOIN employee.position AS p
    ON p.position_id = ap.position_id
) AS h
INNER JOIN employee.employee AS e
  ON e.employee_id = h.employee_id
ORDER BY e.employee_id, h.start_date, h.history_type;
