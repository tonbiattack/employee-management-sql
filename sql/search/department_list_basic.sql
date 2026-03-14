/*
  目的:
    部署一覧画面で使う部署マスタ一覧を取得する。

  想定ユースケース:
    - 管理画面の部署一覧表示
    - 部署選択プルダウンの元データ取得

  出力:
    - department_id
    - department_code
    - department_name
    - company_name

  実装方針:
    - `department` に `company` を JOIN して所属会社名を補完する。
    - マスタ系一覧として安定した `department_id` 順で返す。
*/
SELECT
  d.department_id,
  d.department_code,
  d.department_name,
  c.company_name
FROM employee.department AS d
INNER JOIN employee.company AS c
  ON c.company_id = d.company_id
ORDER BY d.department_id;
