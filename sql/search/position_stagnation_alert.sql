/*
  目的:
    同一役職に長期間留まり、直近評価も低い社員を抽出する。

  想定ユースケース:
    - 育成面談の優先対象抽出
    - 昇格・配置転換候補の棚卸し
*/
WITH latest_evaluation AS (
  SELECT
    ev.employee_id,
    ev.evaluation,
    ROW_NUMBER() OVER (
      PARTITION BY ev.employee_id
      ORDER BY ev.year DESC, ev.quarter DESC
    ) AS rn
  FROM employee.evaluation AS ev
),
open_position_history AS (
  SELECT
    ap.employee_id,
    ap.position_id,
    ap.assumption_of_position_date AS start_date
  FROM employee.assumption_of_position AS ap
  WHERE ap.assumption_of_position_end_date IS NULL
)
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  p.position_name,
  oph.start_date,
  TIMESTAMPDIFF(MONTH, oph.start_date, CURRENT_DATE) AS months_in_position,
  le.evaluation AS latest_evaluation,
  CASE
    WHEN TIMESTAMPDIFF(MONTH, oph.start_date, CURRENT_DATE) >= 24
      AND COALESCE(le.evaluation, 0) <= 4 THEN 'HIGH'
    WHEN TIMESTAMPDIFF(MONTH, oph.start_date, CURRENT_DATE) >= 18 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS alert_level
FROM open_position_history AS oph
INNER JOIN employee.employee AS e
  ON e.employee_id = oph.employee_id
INNER JOIN employee.position AS p
  ON p.position_id = oph.position_id
LEFT JOIN latest_evaluation AS le
  ON le.employee_id = oph.employee_id
 AND le.rn = 1
WHERE TIMESTAMPDIFF(MONTH, oph.start_date, CURRENT_DATE) >= 18
ORDER BY
  CASE
    WHEN TIMESTAMPDIFF(MONTH, oph.start_date, CURRENT_DATE) >= 24
      AND COALESCE(le.evaluation, 0) <= 4 THEN 1
    WHEN TIMESTAMPDIFF(MONTH, oph.start_date, CURRENT_DATE) >= 18 THEN 2
    ELSE 3
  END,
  months_in_position DESC,
  e.employee_id;
