/*
  目的:
    社員ごとの四半期評価推移を確認し、前回比と最新レコードを把握する。

  想定ユースケース:
    - 1on1 前の評価推移確認
    - 昇格候補やフォロー対象者の変化把握

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - 評価年度 / 四半期 / 評価点
    - 前回評価点 / 前回差分 / 最新フラグ

  実装方針:
    - `evaluation` を起点に `LAG` で前回値を算出する。
    - `ROW_NUMBER` で社員ごとの最新評価を判定する。
    - 比較しやすいよう社員、年度、四半期で安定ソートする。
*/
WITH evaluation_with_trend AS (
  SELECT
    ev.employee_id,
    ev.year,
    ev.quarter,
    ev.evaluation,
    LAG(ev.evaluation) OVER (
      PARTITION BY ev.employee_id
      ORDER BY ev.year, ev.quarter
    ) AS previous_evaluation,
    ROW_NUMBER() OVER (
      PARTITION BY ev.employee_id
      ORDER BY ev.year DESC, ev.quarter DESC
    ) AS latest_rank
  FROM employee.evaluation AS ev
)
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  ewt.year,
  ewt.quarter,
  ewt.evaluation,
  ewt.previous_evaluation,
  CASE
    WHEN ewt.previous_evaluation IS NULL THEN NULL
    ELSE ewt.evaluation - ewt.previous_evaluation
  END AS evaluation_diff,
  CASE
    WHEN ewt.latest_rank = 1 THEN 1
    ELSE 0
  END AS is_latest
FROM evaluation_with_trend AS ewt
INNER JOIN employee.employee AS e
  ON e.employee_id = ewt.employee_id
ORDER BY e.employee_id, ewt.year, ewt.quarter;
