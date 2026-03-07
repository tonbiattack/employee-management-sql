-- ========================================
-- SQLファイル: select_role.sql
-- 目的:
--   認可処理でユーザー（email）に紐づくロールを取得する。
-- 重要:
--   このSQLは role テーブルに email カラムがある前提の旧仕様。
--   現行スキーマでは ownership 経由で role を辿る構造のため、
--   実運用時は join 構成を見直すこと。
-- ========================================

SELECT email, role_name FROM employee."role" WHERE email = 'daichi'





