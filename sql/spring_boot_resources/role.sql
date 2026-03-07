-- ========================================
-- SQLファイル: spring_boot_resources/role.sql
-- 目的: このSQLの実行内容を明示するためのヘッダーコメント
-- 備考: 必要に応じて詳細な業務目的・前提条件を追記してください
-- ========================================

insert into employee."role"(role_name) values 
    ('ROLE_ADMIN')
  , ('ROLE_SUPER_USER')
  , ('ROLE_USER');

