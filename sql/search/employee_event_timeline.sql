/*
  目的:
    社員ごとの主要イベント（入社・案件配属・休職・復職・退職）を時系列で確認する。

  想定ユースケース:
    - 人事/労務の履歴確認
    - 監査・問い合わせ時の時系列追跡

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - event_date / event_type / event_detail

  実装方針:
    - イベント種別ごとの履歴テーブルを `UNION ALL` で縦持ちに統一する。
    - 案件配属だけは案件コードが必要なので `project` を JOIN する。
    - 日付、社員ID、イベント種別の順で並べて追跡しやすくする。
*/
WITH employee_events AS (
  -- 入社イベント
  SELECT
    j.employee_id,
    j.joining_the_company_date AS event_date,
    'JOINING' AS event_type,
    'Joined company' AS event_detail
  FROM employee.joining_the_company AS j

  UNION ALL

  -- 案件配属イベント
  SELECT
    ap.employee_id,
    ap.assignment_project_date AS event_date,
    'PROJECT_ASSIGNMENT' AS event_type,
    CONCAT('Assigned to ', p.project_code) AS event_detail
  FROM employee.assignment_project AS ap
  INNER JOIN employee.project AS p
    ON p.project_id = ap.project_id

  UNION ALL

  -- 休職イベント
  SELECT
    l.employee_id,
    l.leave_of_absence_date AS event_date,
    'LEAVE_OF_ABSENCE' AS event_type,
    'Leave of absence started' AS event_detail
  FROM employee.leave_of_absence AS l

  UNION ALL

  -- 復職イベント
  SELECT
    r.employee_id,
    r.reinstatement_date AS event_date,
    'REINSTATEMENT' AS event_type,
    'Reinstated from leave' AS event_detail
  FROM employee.reinstatement AS r

  UNION ALL

  -- 退職イベント
  SELECT
    rt.employee_id,
    rt.retirement_date AS event_date,
    'RETIREMENT' AS event_type,
    rt.retirement_reason AS event_detail
  FROM employee.retirement AS rt
)
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  ev.event_date,
  ev.event_type,
  ev.event_detail
FROM employee_events AS ev
INNER JOIN employee.employee AS e
  ON e.employee_id = ev.employee_id
-- 同日の複数イベントも安定比較できるよう順序を固定する。
ORDER BY ev.event_date, e.employee_id, ev.event_type;
