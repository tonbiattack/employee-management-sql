-- ========================================
-- SQLファイル: spring_boot_resources/company_assignment.sql
-- 目的: このSQLの実行内容を明示するためのヘッダーコメント
-- 備考: 必要に応じて詳細な業務目的・前提条件を追記してください
-- ========================================

insert into employee.company_assignment(company_id,employee_id,company_assignment_date,company_assignment_end_date) values 
    (1,1,DATE '1993-06-01',NULL)
  , (2,2,DATE '1992-10-24',NULL)
  , (3,3,DATE '1999-09-02',NULL)
  , (4,4,DATE '1999-09-25',NULL)
  , (5,5,DATE '1995-02-16',NULL)
  , (6,6,DATE '1992-06-01',NULL);

