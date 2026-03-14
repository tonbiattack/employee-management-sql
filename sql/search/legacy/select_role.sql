/*
  目的:
    認可処理でユーザーに紐づくロールを取得する旧版SQLを記録している。

  想定ユースケース:
    - 旧認可実装との差分確認
    - 現行スキーマへの移植方針検討

  出力:
    - email
    - role_name

  注意点:
    - 現行スキーマの `role` テーブルに `email` カラムは存在しない。
    - 現在は `ownership -> password -> active_employee_contact_information` を辿って
      対象ユーザーのロールを解決する構造である。
    - そのため、このSQLは旧仕様の参考として残している。
*/
SELECT
  email,
  role_name
FROM employee."role"
WHERE email = 'daichi';
