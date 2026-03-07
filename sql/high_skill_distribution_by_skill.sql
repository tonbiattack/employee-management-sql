/*
  目的:
    ハイスキル（>=8）が「どのスキルに偏っているか」をスキル単位で把握する。

  主な用途:
    - 技術ポートフォリオの偏り確認
    - 採用 / 育成の優先領域判断

  出力:
    skill_type / skill_name / high_skill_employee_count / avg_high_skill_level / max_high_skill_level
*/
WITH all_skills AS (
  SELECT
    eds.employee_id,
    'DATABASE' AS skill_type,
    ds.database_skill_name AS skill_name,
    eds.skill_level
  FROM employee.employee_database_skill AS eds
  INNER JOIN employee.database_skill AS ds
    ON ds.database_skill_id = eds.database_skill_id

  UNION ALL

  SELECT
    efs.employee_id,
    'FRAMEWORK' AS skill_type,
    fs.framework_skill_name AS skill_name,
    efs.skill_level
  FROM employee.employee_framework_skill AS efs
  INNER JOIN employee.framework_skill AS fs
    ON fs.framework_skill_id = efs.framework_skill_id

  UNION ALL

  SELECT
    eis.employee_id,
    'INFRASTRUCTURE' AS skill_type,
    ins.infrastructure_skill_name AS skill_name,
    eis.skill_level
  FROM employee.employee_infrastructure_skill AS eis
  INNER JOIN employee.infrastructure_skill AS ins
    ON ins.infrastructure_skill_id = eis.infrastructure_skill_id

  UNION ALL

  SELECT
    eps.employee_id,
    'PROGRAMMING' AS skill_type,
    ps.programming_skill_name AS skill_name,
    eps.skill_level
  FROM employee.employee_programming_skill AS eps
  INNER JOIN employee.programming_skill AS ps
    ON ps.programming_skill_id = eps.programming_skill_id
)
SELECT
  s.skill_type,
  s.skill_name,
  COUNT(DISTINCT s.employee_id) AS high_skill_employee_count,
  ROUND(AVG(s.skill_level), 2) AS avg_high_skill_level,
  MAX(s.skill_level) AS max_high_skill_level
FROM all_skills AS s
WHERE s.skill_level >= 8
GROUP BY s.skill_type, s.skill_name
ORDER BY high_skill_employee_count DESC, avg_high_skill_level DESC, s.skill_type, s.skill_name;
