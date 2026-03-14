/*
  目的:
    スキル保有数と評価推移から成長シグナルを把握する。

  想定ユースケース:
    - 育成対象者の抽出
    - 高成長社員の把握
*/
WITH all_skills AS (
  SELECT employee_id, skill_level FROM employee.employee_database_skill
  UNION ALL
  SELECT employee_id, skill_level FROM employee.employee_framework_skill
  UNION ALL
  SELECT employee_id, skill_level FROM employee.employee_infrastructure_skill
  UNION ALL
  SELECT employee_id, skill_level FROM employee.employee_programming_skill
),
skill_summary AS (
  SELECT
    employee_id,
    COUNT(*) AS total_skill_count,
    COUNT(CASE WHEN skill_level >= 8 THEN 1 END) AS high_skill_count
  FROM all_skills
  GROUP BY employee_id
),
evaluation_trend AS (
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
)
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
LEFT JOIN skill_summary AS ss
  ON ss.employee_id = e.employee_id
LEFT JOIN evaluation_trend AS et
  ON et.employee_id = e.employee_id
 AND et.rn = 1
ORDER BY
  CASE growth_signal
    WHEN 'GROWING' THEN 1
    WHEN 'STABLE' THEN 2
    ELSE 3
  END,
  COALESCE(ss.high_skill_count, 0) DESC,
  e.employee_id;
