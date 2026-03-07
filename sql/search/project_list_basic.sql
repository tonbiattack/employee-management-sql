-- ========================================
-- SQLファイル: project_list_basic.sql
-- 目的:
--   案件一覧画面で使う基本SQL。
-- 出力:
--   案件ID / 案件コード / 開始日 / 取引先名 / 案件内容
-- ========================================
SELECT
  p.project_id,
  p.project_code,
  p.project_start_date,
  bp.business_partner_name,
  p.project_content
FROM employee.project AS p
INNER JOIN employee.business_partner AS bp
  ON bp.business_partner_id = p.business_partner_id
ORDER BY p.project_id;
