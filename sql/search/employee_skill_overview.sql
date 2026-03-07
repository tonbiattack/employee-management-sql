/*
  目的:
    社員ごとのスキル保有状況を横断集計する。
    「総スキル数」「ハイスキル数（>=8）」「最高スキルレベル」を1行で確認できる。

  主な用途:
    - 人材棚卸しの初期分析
    - 育成対象（ハイスキルが少ない社員）の抽出前チェック

  出力:
    employee_id / employee_code / employee_name / total_skills / high_skill_count / max_skill_level
*/
WITH all_skills AS (
  SELECT employee_id, skill_level FROM employee.employee_database_skill
  UNION ALL
  SELECT employee_id, skill_level FROM employee.employee_framework_skill
  UNION ALL
  SELECT employee_id, skill_level FROM employee.employee_infrastructure_skill
  UNION ALL
  SELECT employee_id, skill_level FROM employee.employee_programming_skill
)
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  COUNT(s.employee_id) AS total_skills,
  SUM(CASE WHEN s.skill_level >= 8 THEN 1 ELSE 0 END) AS high_skill_count,
  MAX(s.skill_level) AS max_skill_level
FROM employee.employee AS e
INNER JOIN employee.employee_status AS es
  ON es.employee_status_id = e.employee_status_id
LEFT JOIN all_skills AS s
  ON s.employee_id = e.employee_id
WHERE es.employee_status_id = 1
GROUP BY e.employee_id, e.employee_code, employee_name
ORDER BY high_skill_count DESC, max_skill_level DESC, e.employee_id;
