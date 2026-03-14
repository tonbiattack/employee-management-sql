/*
  目的:
    認証処理でログインIDに紐づくパスワード情報を取得する旧版SQLを記録している。

  想定ユースケース:
    - 旧実装との差分確認
    - スキーマ移行時の参考資料

  出力:
    - email
    - password
    - enabled

  注意点:
    - 現行スキーマの `employee.password` には `email` / `enabled` カラムが存在しない。
    - 現在の認証構造は `employee_contact_information`
      -> `active_employee_contact_information`
      -> `password` の経路で参照する。
    - そのため、このSQLはそのままでは実行不可な旧仕様メモとして扱う。
*/
SELECT
  email,
  password,
  enabled
FROM employee.password
WHERE email = 'daichi';
