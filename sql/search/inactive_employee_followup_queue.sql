/*
  目的:
    休職社員・退職社員について、残存権限や所属残り、再雇用確認などのフォローアップ課題を抽出する。

  想定ユースケース:
    - 人事/情シスの定期確認キュー
    - ステータス遷移後の漏れ監査

  主要な出力項目:
    - 社員ID / 社員コード / 社員名 / ステータス
    - 最新ステータスイベント日
    - 再雇用可否 / ログイン有無 / 連絡先バケット / 現在所属件数
    - フォローアップ課題コード

  実装方針:
    - 休職日・退職日からステータスイベント日を確定する。
    - 認証状態、連絡先状態、現在所属件数を社員単位で集約する。
    - 課題ごとに1行返し、監査キューとして扱いやすくする。

  SQLでやりすぎない判断:
    - 通知送信、担当者割当、期限計算、エスカレーション順序まで含めると
      手続き型のワークフロー処理になるため、SQLは課題抽出までに留める。
    - ステータスごとに異なる承認フローを持たせる場合は、アプリ層で扱うほうが自然。
*/
WITH latest_leave_event AS (
  SELECT
    loa.employee_id,
    MAX(loa.leave_of_absence_date) AS latest_status_event_date
  FROM employee.leave_of_absence AS loa
  GROUP BY loa.employee_id
),
latest_retirement_event AS (
  SELECT
    rt.employee_id,
    MAX(rt.retirement_date) AS latest_status_event_date
  FROM employee.retirement AS rt
  GROUP BY rt.employee_id
),
access_summary AS (
  SELECT
    e.employee_id,
    COUNT(DISTINCT p.password_id) AS password_count,
    CASE
      WHEN COUNT(DISTINCT a.active_employee_contact_information_id) > 0 THEN 'ACTIVE_CONTACT'
      WHEN COUNT(DISTINCT l.contact_information_for_staff_on_leave_id) > 0 THEN 'LEAVE_CONTACT'
      WHEN COUNT(DISTINCT rci.retired_employee_contact_information_id) > 0 THEN 'RETIRED_CONTACT'
      ELSE 'NO_CONTACT'
    END AS contact_bucket
  FROM employee.employee AS e
  LEFT JOIN employee.employee_contact_information AS eci
    ON eci.employee_id = e.employee_id
  LEFT JOIN employee.active_employee_contact_information AS a
    ON a.employee_contact_information_id = eci.employee_contact_information_id
  LEFT JOIN employee.password AS p
    ON p.active_employee_contact_information_id = a.active_employee_contact_information_id
  LEFT JOIN employee.contact_information_for_staff_on_leave AS l
    ON l.employee_contact_information_id = eci.employee_contact_information_id
  LEFT JOIN employee.retired_employee_contact_information AS rci
    ON rci.employee_contact_information_id = eci.employee_contact_information_id
  GROUP BY e.employee_id
),
current_belonging_summary AS (
  SELECT
    employee_id,
    COUNT(*) AS current_belonging_count
  FROM (
    SELECT employee_id FROM employee.belonging_company
    UNION ALL
    SELECT employee_id FROM employee.belonging_department
    UNION ALL
    SELECT employee_id FROM employee.belonging_division
    UNION ALL
    SELECT employee_id FROM employee.belonging_team
    UNION ALL
    SELECT employee_id FROM employee.belonging_project
    UNION ALL
    SELECT employee_id FROM employee.current_position
  ) AS x
  GROUP BY employee_id
),
inactive_employee_summary AS (
  SELECT
    e.employee_id,
    e.employee_code,
    CONCAT(e.family_name, e.last_name) AS employee_name,
    es.employee_status_name,
    CASE
      WHEN es.employee_status_id = 2 THEN lle.latest_status_event_date
      WHEN es.employee_status_id = 3 THEN lre.latest_status_event_date
    END AS latest_status_event_date,
    re.returning_permission,
    CASE WHEN COALESCE(acc.password_count, 0) > 0 THEN 1 ELSE 0 END AS has_login_account,
    COALESCE(acc.contact_bucket, 'NO_CONTACT') AS contact_bucket,
    COALESCE(cbs.current_belonging_count, 0) AS current_belonging_count
  FROM employee.employee AS e
  INNER JOIN employee.employee_status AS es
    ON es.employee_status_id = e.employee_status_id
  LEFT JOIN latest_leave_event AS lle
    ON lle.employee_id = e.employee_id
  LEFT JOIN latest_retirement_event AS lre
    ON lre.employee_id = e.employee_id
  LEFT JOIN employee.retired_employee AS re
    ON re.employee_id = e.employee_id
  LEFT JOIN access_summary AS acc
    ON acc.employee_id = e.employee_id
  LEFT JOIN current_belonging_summary AS cbs
    ON cbs.employee_id = e.employee_id
  WHERE es.employee_status_id IN (2, 3)
)
SELECT
  ies.employee_id,
  ies.employee_code,
  ies.employee_name,
  ies.employee_status_name,
  ies.latest_status_event_date,
  ies.returning_permission,
  ies.has_login_account,
  ies.contact_bucket,
  ies.current_belonging_count,
  'INACTIVE_HAS_LOGIN' AS followup_issue_code
FROM inactive_employee_summary AS ies
WHERE ies.has_login_account = 1

UNION ALL

SELECT
  ies.employee_id,
  ies.employee_code,
  ies.employee_name,
  ies.employee_status_name,
  ies.latest_status_event_date,
  ies.returning_permission,
  ies.has_login_account,
  ies.contact_bucket,
  ies.current_belonging_count,
  'INACTIVE_STILL_HAS_BELONGING' AS followup_issue_code
FROM inactive_employee_summary AS ies
WHERE ies.current_belonging_count > 0

UNION ALL

SELECT
  ies.employee_id,
  ies.employee_code,
  ies.employee_name,
  ies.employee_status_name,
  ies.latest_status_event_date,
  ies.returning_permission,
  ies.has_login_account,
  ies.contact_bucket,
  ies.current_belonging_count,
  'RETIRED_ELIGIBLE_FOR_REHIRE_REVIEW' AS followup_issue_code
FROM inactive_employee_summary AS ies
WHERE ies.employee_status_name = '退職社員'
  AND ies.returning_permission = TRUE

ORDER BY employee_id, followup_issue_code;
