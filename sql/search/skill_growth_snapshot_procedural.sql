/*
  コピー元:
    - sql/search/skill_growth_snapshot.sql

  元SQLの問題点:
    - スキル集約と評価差分計算が同じ問い合わせにあり、成長判定ロジックの差し替え箇所が分かりにくい。
    - 将来スキル履歴を入れる場合に拡張ポイントが少ない。

  この手続き版の方針:
    - 現在スキル集約と評価推移抽出を別テーブル化する。
    - 最後に成長シグナルを判定する。
*/
DROP TEMPORARY TABLE IF EXISTS tmp_skill_growth_all_skill;
CREATE TEMPORARY TABLE tmp_skill_growth_all_skill AS
SELECT employee_id, skill_level FROM employee.employee_database_skill
UNION ALL
SELECT employee_id, skill_level FROM employee.employee_framework_skill
UNION ALL
SELECT employee_id, skill_level FROM employee.employee_infrastructure_skill
UNION ALL
SELECT employee_id, skill_level FROM employee.employee_programming_skill;

DROP TEMPORARY TABLE IF EXISTS tmp_skill_growth_skill_summary;
CREATE TEMPORARY TABLE tmp_skill_growth_skill_summary AS
SELECT
  employee_id,
  COUNT(*) AS total_skill_count,
  COUNT(CASE WHEN skill_level >= 8 THEN 1 END) AS high_skill_count
FROM tmp_skill_growth_all_skill
GROUP BY employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_skill_growth_evaluation_trend;
CREATE TEMPORARY TABLE tmp_skill_growth_evaluation_trend AS
SELECT
  employee_id,
  evaluation,
  previous_evaluation
FROM (
  SELECT
    ev.employee_id,
    ev.evaluation,
    LAG(ev.evaluation) OVER (
      PARTITION BY ev.employee_id
      ORDER BY ev.year, ev.quarter
    ) AS previous_evaluation,
    ROW_NUMBER() OVER (
      PARTITION BY ev.employee_id
      ORDER BY ev.year DESC, ev.quarter DESC
    ) AS rn
  FROM employee.evaluation AS ev
) AS ranked
WHERE rn = 1;

SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  COALESCE(ss.total_skill_count, 0) AS total_skill_count,
  COALESCE(ss.high_skill_count, 0) AS high_skill_count,
  et.evaluation AS latest_evaluation,
  CASE
    WHEN et.previous_evaluation IS NULL THEN NULL
    ELSE et.evaluation - et.previous_evaluation
  END AS evaluation_diff,
  CASE
    WHEN et.previous_evaluation IS NOT NULL
      AND et.evaluation - et.previous_evaluation >= 2 THEN 'GROWING'
    WHEN et.previous_evaluation IS NOT NULL
      AND et.evaluation - et.previous_evaluation <= -2 THEN 'DECLINING'
    ELSE 'STABLE'
  END AS growth_signal
FROM employee.employee AS e
LEFT JOIN tmp_skill_growth_skill_summary AS ss
  ON ss.employee_id = e.employee_id
LEFT JOIN tmp_skill_growth_evaluation_trend AS et
  ON et.employee_id = e.employee_id
ORDER BY
  CASE
    WHEN et.previous_evaluation IS NOT NULL
      AND et.evaluation - et.previous_evaluation >= 2 THEN 1
    WHEN et.previous_evaluation IS NOT NULL
      AND et.evaluation - et.previous_evaluation <= -2 THEN 3
    ELSE 2
  END,
  COALESCE(ss.high_skill_count, 0) DESC,
  e.employee_id;
