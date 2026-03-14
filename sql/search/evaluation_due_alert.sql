/*
  目的:
    評価登録が未完了の四半期について、締切日と遅延状況を返す。

  想定ユースケース:
    - 人事の締切超過アラート
    - 評価締め前後の未登録フォロー

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - 対象年 / 対象四半期
    - 締切日 / 遅延日数 / ステータス
    - 指摘コード

  実装方針:
    - 評価が1件でも存在する年を監査対象年として扱う。
    - 1-4Q の期待集合を作り、未登録四半期を社員単位で抽出する。
    - 四半期ごとに固定締切日を割り当て、期限超過を判定する。
*/
WITH quarter_catalog AS (
  SELECT 1 AS quarter_no, '-04-15' AS due_suffix
  UNION ALL SELECT 2, '-07-15'
  UNION ALL SELECT 3, '-10-15'
  UNION ALL SELECT 4, '-01-15'
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
target_year AS (
  SELECT DISTINCT year
  FROM employee.evaluation
),
missing_quarter AS (
  SELECT
    ae.employee_id,
    ae.employee_code,
    ae.employee_name,
    ty.year AS target_year,
    qc.quarter_no AS target_quarter,
    CASE
      WHEN qc.quarter_no = 4 THEN STR_TO_DATE(CONCAT(ty.year + 1, qc.due_suffix), '%Y-%m-%d')
      ELSE STR_TO_DATE(CONCAT(ty.year, qc.due_suffix), '%Y-%m-%d')
    END AS due_date
  FROM active_employee AS ae
  CROSS JOIN target_year AS ty
  INNER JOIN quarter_catalog AS qc
    ON 1 = 1
  LEFT JOIN employee.evaluation AS ev
    ON ev.employee_id = ae.employee_id
   AND ev.year = ty.year
   AND ev.quarter = qc.quarter_no
  WHERE ev.evaluation_id IS NULL
)
SELECT
  mq.employee_id,
  mq.employee_code,
  mq.employee_name,
  mq.target_year,
  mq.target_quarter,
  mq.due_date,
  GREATEST(DATEDIFF(CURRENT_DATE, mq.due_date), 0) AS overdue_days,
  CASE
    WHEN CURRENT_DATE > mq.due_date THEN 'OVERDUE'
    ELSE 'PENDING'
  END AS due_status,
  'EVALUATION_DUE_DELAY' AS alert_issue_code
FROM missing_quarter AS mq
ORDER BY mq.target_year, mq.target_quarter, mq.employee_id;
