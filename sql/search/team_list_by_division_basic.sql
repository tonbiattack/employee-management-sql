/*
  目的:
    指定した課（division）配下のチーム一覧を取得する。

  想定ユースケース:
    - 組織選択画面でのチーム候補表示
    - 課詳細画面での配下チーム一覧表示

  入力:
    - division_id: 対象課ID

  出力:
    - team_id
    - team_code
    - team_name
    - division_name

  実装方針:
    - `team` に `division` を JOIN して課名を補完する。
    - 指定課に属するチームだけを `division_id` で絞り込む。

  注意点:
    - 現状は `division_id = 1` 固定のため、実運用ではバインド変数化する。
*/
SELECT
  t.team_id,
  t.team_code,
  t.team_name,
  d.division_name
FROM employee.team AS t
INNER JOIN employee.division AS d
  ON d.division_id = t.division_id
WHERE t.division_id = 1
ORDER BY t.team_id;
