/*
  目的:
    チーム単位で「人数」「ハイスキル比率」「最新評価平均」を可視化し、キャパシティリスクを把握する。

  想定ユースケース:
    - チーム編成見直し
    - リーダーの育成/配置計画
*/
WITH latest_evaluation AS (
  SELECT
    e.employee_id,
    e.evaluation,
    ROW_NUMBER() OVER (
      PARTITION BY e.employee_id
      ORDER BY e.year DESC, e.quarter DESC
    ) AS rn
  FROM employee.evaluation AS e
),
employee_high_skill AS (
  SELECT
    x.employee_id,
    MAX(CASE WHEN x.skill_level >= 8 THEN 1 ELSE 0 END) AS is_high_skill
  FROM (
    SELECT employee_id, skill_level FROM employee.employee_database_skill
    UNION ALL
    SELECT employee_id, skill_level FROM employee.employee_framework_skill
    UNION ALL
    SELECT employee_id, skill_level FROM employee.employee_infrastructure_skill
    UNION ALL
    SELECT employee_id, skill_level FROM employee.employee_programming_skill
  ) AS x
  GROUP BY x.employee_id
)
SELECT
  t.team_id,
  t.team_code,
  t.team_name,
  COUNT(DISTINCT bt.employee_id) AS team_member_count,
  COUNT(DISTINCT CASE WHEN hs.is_high_skill = 1 THEN bt.employee_id END) AS high_skill_member_count,
  ROUND(
    COUNT(DISTINCT CASE WHEN hs.is_high_skill = 1 THEN bt.employee_id END) / NULLIF(COUNT(DISTINCT bt.employee_id), 0),
    2
  ) AS high_skill_ratio,
  ROUND(AVG(le.evaluation), 2) AS avg_latest_evaluation
FROM employee.team AS t
LEFT JOIN employee.belonging_team AS bt
  ON bt.team_id = t.team_id
LEFT JOIN employee_high_skill AS hs
  ON hs.employee_id = bt.employee_id
LEFT JOIN latest_evaluation AS le
  ON le.employee_id = bt.employee_id
 AND le.rn = 1
GROUP BY t.team_id, t.team_code, t.team_name
ORDER BY high_skill_ratio ASC, avg_latest_evaluation ASC, team_member_count DESC, t.team_id;
