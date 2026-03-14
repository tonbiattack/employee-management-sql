/*
  コピー元:
    - sql/search/inactive_employee_followup_queue.sql

  元SQLの問題点:
    - ステータスイベント、認証状態、所属件数、課題展開が1本にまとまり、課題ごとの追加変更がしづらい。
    - 通知や承認に近い処理を足し始めると責務が膨らみやすい。

  この手続き版の方針:
    - 社員状態の集約を段階化し、最後に課題コードを展開する。
    - 将来のワークフロー連携時に、中間テーブルをそのまま確認できるようにする。
*/
DROP TEMPORARY TABLE IF EXISTS tmp_inactive_latest_leave_event;
CREATE TEMPORARY TABLE tmp_inactive_latest_leave_event AS
SELECT
  loa.employee_id,
  MAX(loa.leave_of_absence_date) AS latest_status_event_date
FROM employee.leave_of_absence AS loa
GROUP BY loa.employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_inactive_latest_retirement_event;
CREATE TEMPORARY TABLE tmp_inactive_latest_retirement_event AS
SELECT
  rt.employee_id,
  MAX(rt.retirement_date) AS latest_status_event_date
FROM employee.retirement AS rt
GROUP BY rt.employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_inactive_access_summary;
CREATE TEMPORARY TABLE tmp_inactive_access_summary AS
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
GROUP BY e.employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_inactive_current_belonging_rows;
CREATE TEMPORARY TABLE tmp_inactive_current_belonging_rows AS
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
SELECT employee_id FROM employee.current_position;

DROP TEMPORARY TABLE IF EXISTS tmp_inactive_current_belonging_summary;
CREATE TEMPORARY TABLE tmp_inactive_current_belonging_summary AS
SELECT employee_id, COUNT(*) AS current_belonging_count
FROM tmp_inactive_current_belonging_rows
GROUP BY employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_inactive_employee_summary;
CREATE TEMPORARY TABLE tmp_inactive_employee_summary AS
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
LEFT JOIN tmp_inactive_latest_leave_event AS lle
  ON lle.employee_id = e.employee_id
LEFT JOIN tmp_inactive_latest_retirement_event AS lre
  ON lre.employee_id = e.employee_id
LEFT JOIN employee.retired_employee AS re
  ON re.employee_id = e.employee_id
LEFT JOIN tmp_inactive_access_summary AS acc
  ON acc.employee_id = e.employee_id
LEFT JOIN tmp_inactive_current_belonging_summary AS cbs
  ON cbs.employee_id = e.employee_id
WHERE es.employee_status_id IN (2, 3);

DROP TEMPORARY TABLE IF EXISTS tmp_inactive_issue_has_login;
CREATE TEMPORARY TABLE tmp_inactive_issue_has_login AS
SELECT employee_id, 'INACTIVE_HAS_LOGIN' AS issue_code
FROM tmp_inactive_employee_summary
WHERE has_login_account = 1;

DROP TEMPORARY TABLE IF EXISTS tmp_inactive_issue_has_belonging;
CREATE TEMPORARY TABLE tmp_inactive_issue_has_belonging AS
SELECT employee_id, 'INACTIVE_STILL_HAS_BELONGING' AS issue_code
FROM tmp_inactive_employee_summary
WHERE current_belonging_count > 0;

DROP TEMPORARY TABLE IF EXISTS tmp_inactive_issue_rehire_review;
CREATE TEMPORARY TABLE tmp_inactive_issue_rehire_review AS
SELECT employee_id, 'RETIRED_ELIGIBLE_FOR_REHIRE_REVIEW' AS issue_code
FROM tmp_inactive_employee_summary
WHERE employee_status_name = '退職社員'
  AND returning_permission = TRUE;

DROP TEMPORARY TABLE IF EXISTS tmp_inactive_followup_issue;
CREATE TEMPORARY TABLE tmp_inactive_followup_issue AS
SELECT * FROM tmp_inactive_issue_has_login
UNION ALL
SELECT * FROM tmp_inactive_issue_has_belonging
UNION ALL
SELECT * FROM tmp_inactive_issue_rehire_review;

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
  issue.issue_code AS followup_issue_code
FROM tmp_inactive_employee_summary AS ies
INNER JOIN tmp_inactive_followup_issue AS issue
  ON issue.employee_id = ies.employee_id
ORDER BY ies.employee_id, issue.issue_code;
