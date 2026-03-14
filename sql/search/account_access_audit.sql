/*
  目的:
    社員ステータスと認証情報の不整合を検出し、監査用に一覧化する。

  想定ユースケース:
    - 休職 / 退職時の認証停止漏れ確認
    - 現役社員のログイン不可状態の検知

  主要な出力項目:
    - 社員ID / 社員コード / 社員名 / 社員ステータス
    - 社用メールアドレス
    - 保有ロール一覧
    - 監査指摘コード

  実装方針:
    - 社員連絡先から現役連絡先、パスワード、権限を順に LEFT JOIN して認証状態を集約する。
    - 現役なのにログイン情報がないケースと、休職/退職なのにログイン情報が残るケースを `UNION ALL` で返す。
    - 同一社員で重複しないよう社員単位に集約してから判定する。
*/
WITH access_summary AS (
  SELECT
    e.employee_id,
    e.employee_code,
    CONCAT(e.family_name, e.last_name) AS employee_name,
    es.employee_status_name,
    MAX(a.company_email) AS company_email,
    COUNT(DISTINCT a.active_employee_contact_information_id) AS active_contact_count,
    COUNT(DISTINCT p.password_id) AS password_count,
    GROUP_CONCAT(DISTINCT r.role_name ORDER BY r.role_name SEPARATOR ',') AS role_names
  FROM employee.employee AS e
  INNER JOIN employee.employee_status AS es
    ON es.employee_status_id = e.employee_status_id
  LEFT JOIN employee.employee_contact_information AS eci
    ON eci.employee_id = e.employee_id
  LEFT JOIN employee.active_employee_contact_information AS a
    ON a.employee_contact_information_id = eci.employee_contact_information_id
  LEFT JOIN employee.password AS p
    ON p.active_employee_contact_information_id = a.active_employee_contact_information_id
  LEFT JOIN employee.ownership AS o
    ON o.password_id = p.password_id
  LEFT JOIN employee.role AS r
    ON r.role_id = o.role_id
  GROUP BY
    e.employee_id,
    e.employee_code,
    employee_name,
    es.employee_status_name
)
SELECT
  acs.employee_id,
  acs.employee_code,
  acs.employee_name,
  acs.employee_status_name,
  acs.company_email,
  acs.role_names,
  'ACTIVE_NO_LOGIN' AS audit_issue_code
FROM access_summary AS acs
WHERE acs.employee_status_name = '現役社員'
  AND acs.password_count = 0

UNION ALL

SELECT
  acs.employee_id,
  acs.employee_code,
  acs.employee_name,
  acs.employee_status_name,
  acs.company_email,
  acs.role_names,
  'INACTIVE_HAS_LOGIN' AS audit_issue_code
FROM access_summary AS acs
WHERE acs.employee_status_name IN ('休職社員', '退職社員')
  AND acs.password_count > 0

ORDER BY employee_id, audit_issue_code;
