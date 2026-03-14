/*
  目的:
    社用メールアドレスから `active_employee_contact_information_id` を逆引きする。

  想定ユースケース:
    - `password` 登録前の参照キー解決
    - ログイン関連バッチでの連絡先ID特定

  入力:
    - company_email: 社用メールアドレス

  出力:
    - active_employee_contact_information_id: 1件想定の主キー

  実装方針:
    - `active_employee_contact_information` 単表で完結するため JOIN は行わない。
    - メールアドレスが一意である前提で、ID だけを返す。

  注意点:
    - サンプル値固定のため、実運用ではプレースホルダに置き換える。
*/
SELECT
  active_employee_contact_information_id
FROM
  active_employee_contact_information
WHERE
  company_email = 'hayamamasahiro@example.co.jp';

