-- ========================================
-- SQLファイル: department_list_basic.sql
-- 目的:
--   部署一覧画面で使う部署マスタ取得SQL。
-- 出力:
--   部署ID / 部署コード / 部署名 / 会社名
-- ========================================
SELECT
  d.department_id,
  d.department_code,
  d.department_name,
  c.company_name
FROM employee.department AS d
INNER JOIN employee.company AS c
  ON c.company_id = d.company_id
ORDER BY d.department_id;
