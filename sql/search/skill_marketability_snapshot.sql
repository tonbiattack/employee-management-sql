/*
  目的:
    社員ごとのスキル横断性と高水準カテゴリ数から、市場価値の目安を返す。

  想定ユースケース:
    - 提案人材の棚卸し
    - 営業/人事向けの人材ポートフォリオ確認

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - スキルカテゴリ数 / ハイスキルカテゴリ数 / 総スキル件数
    - 直近評価
    - 市場価値ティア

  実装方針:
    - 4カテゴリのスキルを横断してカテゴリ数と件数を集約する。
    - 直近評価を結合し、カテゴリの広さと質の両面で HIGH / MEDIUM / LOW を判定する。
*/
WITH all_skill_rows AS (
  SELECT employee_id, skill_level, 'DATABASE' AS skill_category FROM employee.employee_database_skill
  UNION ALL
  SELECT employee_id, skill_level, 'FRAMEWORK' AS skill_category FROM employee.employee_framework_skill
  UNION ALL
  SELECT employee_id, skill_level, 'INFRASTRUCTURE' AS skill_category FROM employee.employee_infrastructure_skill
  UNION ALL
  SELECT employee_id, skill_level, 'PROGRAMMING' AS skill_category FROM employee.employee_programming_skill
),
skill_summary AS (
  SELECT
    employee_id,
    COUNT(DISTINCT skill_category) AS skill_category_count,
    COUNT(DISTINCT CASE WHEN skill_level >= 8 THEN skill_category END) AS high_skill_category_count,
    COUNT(*) AS total_skill_count
  FROM all_skill_rows
  GROUP BY employee_id
),
latest_evaluation AS (
  SELECT employee_id, evaluation
  FROM (
    SELECT
      ev.employee_id,
      ev.evaluation,
      ROW_NUMBER() OVER (
        PARTITION BY ev.employee_id
        ORDER BY ev.year DESC, ev.quarter DESC
      ) AS rn
    FROM employee.evaluation AS ev
  ) AS ranked
  WHERE rn = 1
)
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  COALESCE(ss.skill_category_count, 0) AS skill_category_count,
  COALESCE(ss.high_skill_category_count, 0) AS high_skill_category_count,
  COALESCE(ss.total_skill_count, 0) AS total_skill_count,
  le.evaluation AS latest_evaluation,
  CASE
    WHEN COALESCE(ss.skill_category_count, 0) >= 4
      AND COALESCE(ss.high_skill_category_count, 0) >= 3
      AND COALESCE(le.evaluation, 0) >= 7 THEN 'HIGH'
    WHEN COALESCE(ss.skill_category_count, 0) >= 3
      AND COALESCE(ss.high_skill_category_count, 0) >= 1 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS marketability_tier
FROM employee.employee AS e
LEFT JOIN skill_summary AS ss
  ON ss.employee_id = e.employee_id
LEFT JOIN latest_evaluation AS le
  ON le.employee_id = e.employee_id
ORDER BY
  CASE marketability_tier
    WHEN 'HIGH' THEN 1
    WHEN 'MEDIUM' THEN 2
    ELSE 3
  END,
  COALESCE(ss.high_skill_category_count, 0) DESC,
  e.employee_id;
