-- ========================================
-- SQLファイル: employee_list_basic.sql
-- 目的:
--   社員一覧画面で使う最小限の一覧取得SQL。
-- 出力:
--   社員ID / 社員コード / 氏名 / 在籍区分 / 等級
-- ========================================
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  es.employee_status_name,
  e.grade
FROM employee.employee AS e
INNER JOIN employee.employee_status AS es
  ON es.employee_status_id = e.employee_status_id
ORDER BY e.employee_id;
