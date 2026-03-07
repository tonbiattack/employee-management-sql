-- ========================================
-- SQLファイル: exist_email_search.sql
-- 目的:
--   社用メールアドレスがパスワード連携済みか（=ログイン対象として存在するか）を確認する。
-- 入力:
--   company_email（社用メールアドレス）
-- 出力:
--   company_email（存在すれば1行、無ければ0行）
-- 利用場面:
--   新規アカウント作成時の重複チェック。
-- ========================================

SELECT
    ae.company_email
FROM
    password AS pass
INNER JOIN
    active_employee_contact_information AS ae ON
    pass.active_employee_contact_information_id = ae.active_employee_contact_information_id    
WHERE 
    ae.company_email = 'hayamamasahiro@example.co.jp'



