/*
  目的:
    社員詳細画面で表示する1名分の基本情報を取得する。

  想定ユースケース:
    - 社員詳細画面のヘッダー表示
    - プロフィール編集画面の初期表示

  入力:
    - employee_id: 対象社員ID

  出力:
    - 社員コード / 氏名 / フリガナ / 生年月日 / 等級 / コメント
    - 在籍ステータス名 / 性別名

  実装方針:
    - `employee` を起点に、状態名と性別名をマスタJOINで解決する。
    - 1件取得前提のため `employee_id` で直接絞り込む。

  注意点:
    - 現状は `employee_id = 1` 固定なので、実運用ではバインド変数化する。
*/
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  e.family_name_furigana,
  e.last_name_furigana,
  e.date_of_birth,
  e.grade,
  e.comment,
  es.employee_status_name,
  g.gender_name
FROM employee.employee AS e
INNER JOIN employee.employee_status AS es
  ON es.employee_status_id = e.employee_status_id
INNER JOIN employee.gender AS g
  ON g.gender_id = e.gender_id
WHERE e.employee_id = 1;
