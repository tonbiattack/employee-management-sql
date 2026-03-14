/*
  目的:
    案件一覧画面で使う基本的な案件情報を取得する。

  想定ユースケース:
    - 案件一覧画面
    - 案件選択ダイアログの候補表示

  出力:
    - project_id
    - project_code
    - project_start_date
    - business_partner_name
    - project_content

  実装方針:
    - `project` に `business_partner` を JOIN して取引先名を補完する。
    - 一覧表示用に `project_id` 順で返す。
*/
SELECT
  p.project_id,
  p.project_code,
  p.project_start_date,
  bp.business_partner_name,
  p.project_content
FROM employee.project AS p
INNER JOIN employee.business_partner AS bp
  ON bp.business_partner_id = p.business_partner_id
ORDER BY p.project_id;
