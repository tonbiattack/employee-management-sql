/*
  目的:
    社員一覧画面で使う最小限の一覧情報を取得する。

  想定ユースケース:
    - 社員一覧画面
    - 社員検索APIのベースクエリ

  出力:
    - employee_id
    - employee_code
    - employee_name
    - employee_status_name
    - grade

  実装方針:
    - `employee` に `employee_status` を JOIN し、表示用の状態名を付与する。
    - 一覧の基準順として `employee_id` 昇順で返す。
*/
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  es.employee_status_name,
  e.grade
FROM employee.employee AS e
INNER JOIN employee.employee_status AS es
  ON es.employee_status_id = e.employee_status_id
ORDER BY e.employee_id;
