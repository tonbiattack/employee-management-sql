/*
  目的:
    対象年度の四半期評価に欠番がある現役社員を抽出する。

  想定ユースケース:
    - 半期 / 年次評価の登録漏れ監査
    - 人事評価締め前の未登録確認

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - 想定四半期数 / 登録済み四半期数 / 未登録四半期一覧
    - 指摘コード

  実装方針:
    - 監査対象年度は、評価テーブルに存在する最新年度を基準にする。
    - 1-4Q の期待集合を作り、実登録との突合で欠番を求める。
    - 欠番がある社員だけ返す。

  SQLでやりすぎない判断:
    - 評価年度の締め日、対象部署、免除条件まで含めると制度ロジックになるため、
      その場合は手続き型のバッチやアプリ層で判定するほうがよい。
    - このSQLは「最新年度の単純な欠番監査」に限定している。
*/
WITH latest_year AS (
  SELECT MAX(year) AS target_year
  FROM employee.evaluation
),
quarter_catalog AS (
  SELECT 1 AS quarter_no
  UNION ALL SELECT 2
  UNION ALL SELECT 3
  UNION ALL SELECT 4
),
active_employee AS (
  SELECT
    e.employee_id,
    e.employee_code,
    CONCAT(e.family_name, e.last_name) AS employee_name
  FROM employee.employee AS e
  INNER JOIN employee.employee_status AS es
    ON es.employee_status_id = e.employee_status_id
   AND es.employee_status_id = 1
),
missing_quarters AS (
  SELECT
    ae.employee_id,
    ae.employee_code,
    ae.employee_name,
    CONCAT(ly.target_year, '-Q', qc.quarter_no) AS missing_quarter
  FROM active_employee AS ae
  CROSS JOIN latest_year AS ly
  CROSS JOIN quarter_catalog AS qc
  LEFT JOIN employee.evaluation AS ev
    ON ev.employee_id = ae.employee_id
   AND ev.year = ly.target_year
   AND ev.quarter = qc.quarter_no
  WHERE ev.evaluation_id IS NULL
)
SELECT
  mq.employee_id,
  mq.employee_code,
  mq.employee_name,
  4 AS expected_quarter_count,
  4 - COUNT(*) AS registered_quarter_count,
  GROUP_CONCAT(mq.missing_quarter ORDER BY mq.missing_quarter SEPARATOR ',') AS missing_quarter_list,
  'EVALUATION_QUARTER_MISSING' AS coverage_issue_code
FROM missing_quarters AS mq
GROUP BY mq.employee_id, mq.employee_code, mq.employee_name
HAVING COUNT(*) > 0
ORDER BY mq.employee_id;
