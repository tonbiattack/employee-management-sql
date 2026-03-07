-- ========================================
-- SQLファイル: insert_password.sql
-- 目的:
--   認証ユーザーのパスワード初期登録を行う。
-- 重要:
--   email / enabled カラムを使う旧仕様INSERT。
--   現行 employee.password スキーマ（active_employee_contact_information_id, password）
--   にはそのまま適用できないため、利用前に修正が必要。
-- ========================================

INSERT 
INTO employee.password(password_id, email, password, enabled) 
VALUES (1, 'daichi', '{bcrypt}$2a$08$684KJwMQUyWGnxR.Z8DX3OZE0IwPdmIhq.HhDrf7bmus260psiMdG', true)
