-- ========================================
-- SQLファイル: select_active_information_id_by_company_email.sql
-- 目的:
--   ログイン/アカウント登録時に、社用メールアドレスから
--   active_employee_contact_information_id を逆引きする。
-- 入力:
--   company_email（社用メールアドレス）
-- 出力:
--   active_employee_contact_information_id（1件想定）
-- 利用場面:
--   password テーブル登録前の参照キー解決。
-- ========================================

	SELECT
    	active_employee_contact_information_id
	FROM
    	active_employee_contact_information
	WHERE 
    	company_email = 'hayamamasahiro@example.co.jp'

