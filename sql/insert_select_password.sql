-- ========================================
-- SQLファイル: insert_select_password.sql
-- 目的:
--   社用メールから active_employee_contact_information_id を引き、
--   password レコードへ登録する一連の処理を想定したSQL雛形。
-- 重要:
--   現状は INSERT/SELECT 構文が未完成で、そのままでは実行不可。
--   「SELECTでID取得 → INSERT ... SELECT」で書き直して利用すること。
-- ========================================

	INSERT INTO password(active_employee_contact_information_id,password, password) values
    (
        password.active_employee_contact_information_id = aeci.active_employee_contact_information_id,
        password = 'test'
        
    )
    
    SELECT
    	aeci.active_employee_contact_information_id
	FROM
    	active_employee_contact_information AS aeci
	WHERE 
    	company_email = 'hayamamasahiro@example.co.jp'

