/*
  コピー元:
    - sql/search/position_stagnation_alert.sql

  元SQLの問題点:
    - 月数計算と評価抽出が都度式で繰り返され、閾値追加時に分岐が読みにくくなる。
    - 面談ロジックや追加判定条件を足す余地が少ない。

  この手続き版の方針:
    - 最新評価、継続中役職、在任月数を個別テーブルに分割する。
    - 最後にアラート判定だけを載せる。
*/
DROP TEMPORARY TABLE IF EXISTS tmp_position_latest_evaluation;
CREATE TEMPORARY TABLE tmp_position_latest_evaluation AS
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
WHERE rn = 1;

DROP TEMPORARY TABLE IF EXISTS tmp_position_open_history;
CREATE TEMPORARY TABLE tmp_position_open_history AS
SELECT
  ap.employee_id,
  ap.position_id,
  ap.assumption_of_position_date AS start_date
FROM employee.assumption_of_position AS ap
WHERE ap.assumption_of_position_end_date IS NULL;

DROP TEMPORARY TABLE IF EXISTS tmp_position_duration_summary;
CREATE TEMPORARY TABLE tmp_position_duration_summary AS
SELECT
  oph.employee_id,
  oph.position_id,
  oph.start_date,
  TIMESTAMPDIFF(MONTH, oph.start_date, CURRENT_DATE) AS months_in_position
FROM tmp_position_open_history AS oph;

SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  p.position_name,
  pds.start_date,
  pds.months_in_position,
  le.evaluation AS latest_evaluation,
  CASE
    WHEN pds.months_in_position >= 24
      AND COALESCE(le.evaluation, 0) <= 4 THEN 'HIGH'
    WHEN pds.months_in_position >= 18 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS alert_level
FROM tmp_position_duration_summary AS pds
INNER JOIN employee.employee AS e
  ON e.employee_id = pds.employee_id
INNER JOIN employee.position AS p
  ON p.position_id = pds.position_id
LEFT JOIN tmp_position_latest_evaluation AS le
  ON le.employee_id = pds.employee_id
WHERE pds.months_in_position >= 18
ORDER BY
  CASE
    WHEN pds.months_in_position >= 24
      AND COALESCE(le.evaluation, 0) <= 4 THEN 1
    WHEN pds.months_in_position >= 18 THEN 2
    ELSE 3
  END,
  pds.months_in_position DESC,
  e.employee_id;
