/*
  目的:
    社用メールアドレスがログイン用アカウントとしてすでに利用中かを確認する。

  想定ユースケース:
    - 新規アカウント作成時の重複チェック
    - 招待メール送信前の存在確認

  入力:
    - company_email: 確認対象の社用メールアドレス

  出力:
    - company_email: 存在する場合のみ1行返す

  実装方針:
    - `password` と `active_employee_contact_information` を内部結合し、
      実際にログイン情報へ紐づいたメールだけを対象にする。
    - メールアドレス単位の存在確認なので、返却列は最小限にしている。

  注意点:
    - 現状はサンプル値を直書きしているため、実運用ではバインド変数化する。
*/
SELECT
  ae.company_email
FROM
  -- パスワードが存在する = ログイン対象として有効なメールだけを拾う。
  password AS pass
INNER JOIN
  active_employee_contact_information AS ae ON
  pass.active_employee_contact_information_id = ae.active_employee_contact_information_id
WHERE 
  ae.company_email = 'hayamamasahiro@example.co.jp';

