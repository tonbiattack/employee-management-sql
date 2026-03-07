-- ========================================
-- SQLファイル: select_password.sql
-- 目的:
--   認証処理でメール（またはログインID）に紐づくパスワード情報を取得する。
-- 重要:
--   このSQLは email / enabled カラムを参照しており、
--   現行の employee.password 定義と一致しない旧仕様の可能性が高い。
--   実運用時は現行スキーマに合わせて更新すること。
-- ========================================

SELECT email, password, enabled FROM employee.password WHERE email = 'daichi' 




