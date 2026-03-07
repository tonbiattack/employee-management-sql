-- ========================================
-- SQLファイル: insert_role.sql
-- 目的:
--   認証ユーザーにロールを付与するための登録SQL。
-- 重要:
--   email / password_id を直接 role テーブルへ入れる旧仕様。
--   現行スキーマは role（マスタ）+ ownership（紐付け）構成のため、
--   適用前に INSERT 先とカラム定義を確認すること。
-- ========================================

INSERT 
INTO employee."role"(role_id, password_id, email, role_name) 
VALUES (1, 1, 'daichi', 'ADMIN')
