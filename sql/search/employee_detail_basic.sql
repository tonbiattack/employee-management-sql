-- ========================================
-- SQLファイル: employee_detail_basic.sql
-- 目的:
--   社員詳細画面で、1名分の基本情報を取得するSQL。
-- 入力:
--   employee_id（例では 1 を固定）
-- ========================================
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  e.family_name_furigana,
  e.last_name_furigana,
  e.date_of_birth,
  e.grade,
  e.comment,
  es.employee_status_name,
  g.gender_name
FROM employee.employee AS e
INNER JOIN employee.employee_status AS es
  ON es.employee_status_id = e.employee_status_id
INNER JOIN employee.gender AS g
  ON g.gender_id = e.gender_id
WHERE e.employee_id = 1;
