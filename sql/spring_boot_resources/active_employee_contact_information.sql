-- ========================================
-- SQLファイル: spring_boot_resources/active_employee_contact_information.sql
-- 目的: このSQLの実行内容を明示するためのヘッダーコメント
-- 備考: 必要に応じて詳細な業務目的・前提条件を追記してください
-- ========================================

insert into employee.active_employee_contact_information(employee_contact_information_id,company_phone_number,company_email) values 
    (1,'090-2663-0737','hayamamasahiro@example.co.jp')
  , (2,'090-0936-7033','mikikumagai@example.org')
  , (3,'090-8113-3201','haga_316@example.co.jp');

