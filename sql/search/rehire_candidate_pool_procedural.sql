/*
  コピー元:
    - sql/search/rehire_candidate_pool.sql

  元SQLの問題点:
    - 退職情報、評価、スキル、連絡先、優先度判定が同一SELECTにまとまり、候補選定理由を追いづらい。
    - 人手レビュー前に中間データを確認しにくい。

  この手続き版の方針:
    - 候補基礎情報を段階テーブルに積み上げ、最終優先度だけを最後に判定する。
    - 人事レビュー時に途中テーブルを確認しやすくする。
*/
DROP TEMPORARY TABLE IF EXISTS tmp_rehire_latest_retirement;
CREATE TEMPORARY TABLE tmp_rehire_latest_retirement AS
SELECT
  rt.employee_id,
  MAX(rt.retirement_date) AS retirement_date
FROM employee.retirement AS rt
GROUP BY rt.employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_rehire_latest_evaluation;
CREATE TEMPORARY TABLE tmp_rehire_latest_evaluation AS
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

DROP TEMPORARY TABLE IF EXISTS tmp_rehire_high_skill_summary;
CREATE TEMPORARY TABLE tmp_rehire_high_skill_summary AS
SELECT
  employee_id,
  COUNT(*) AS high_skill_count
FROM (
  SELECT employee_id, skill_level FROM employee.employee_database_skill
  UNION ALL
  SELECT employee_id, skill_level FROM employee.employee_framework_skill
  UNION ALL
  SELECT employee_id, skill_level FROM employee.employee_infrastructure_skill
  UNION ALL
  SELECT employee_id, skill_level FROM employee.employee_programming_skill
) AS s
WHERE s.skill_level >= 8
GROUP BY employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_rehire_contact_summary;
CREATE TEMPORARY TABLE tmp_rehire_contact_summary AS
SELECT
  eci.employee_id,
  CASE
    WHEN COUNT(DISTINCT reci.retired_employee_contact_information_id) > 0 THEN 'RETIRED_CONTACT'
    WHEN COUNT(DISTINCT l.contact_information_for_staff_on_leave_id) > 0 THEN 'LEAVE_CONTACT'
    WHEN COUNT(DISTINCT a.active_employee_contact_information_id) > 0 THEN 'ACTIVE_CONTACT'
    ELSE 'NO_CONTACT'
  END AS contact_bucket
FROM employee.employee_contact_information AS eci
LEFT JOIN employee.retired_employee_contact_information AS reci
  ON reci.employee_contact_information_id = eci.employee_contact_information_id
LEFT JOIN employee.contact_information_for_staff_on_leave AS l
  ON l.employee_contact_information_id = eci.employee_contact_information_id
LEFT JOIN employee.active_employee_contact_information AS a
  ON a.employee_contact_information_id = eci.employee_contact_information_id
GROUP BY eci.employee_id;

DROP TEMPORARY TABLE IF EXISTS tmp_rehire_candidate_base;
CREATE TEMPORARY TABLE tmp_rehire_candidate_base AS
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  lr.retirement_date,
  re.returning_permission,
  le.evaluation AS latest_evaluation,
  COALESCE(hss.high_skill_count, 0) AS high_skill_count,
  COALESCE(cs.contact_bucket, 'NO_CONTACT') AS contact_bucket
FROM employee.retired_employee AS re
INNER JOIN employee.employee AS e
  ON e.employee_id = re.employee_id
INNER JOIN tmp_rehire_latest_retirement AS lr
  ON lr.employee_id = re.employee_id
LEFT JOIN tmp_rehire_latest_evaluation AS le
  ON le.employee_id = re.employee_id
LEFT JOIN tmp_rehire_high_skill_summary AS hss
  ON hss.employee_id = re.employee_id
LEFT JOIN tmp_rehire_contact_summary AS cs
  ON cs.employee_id = re.employee_id
WHERE re.returning_permission = TRUE;

SELECT
  employee_id,
  employee_code,
  employee_name,
  retirement_date,
  returning_permission,
  latest_evaluation,
  high_skill_count,
  contact_bucket,
  CASE
    WHEN COALESCE(latest_evaluation, 0) >= 8 AND high_skill_count >= 2 THEN 'HIGH'
    WHEN COALESCE(latest_evaluation, 0) >= 6 OR high_skill_count >= 1 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS rehire_priority
FROM tmp_rehire_candidate_base
ORDER BY
  CASE
    WHEN COALESCE(latest_evaluation, 0) >= 8 AND high_skill_count >= 2 THEN 1
    WHEN COALESCE(latest_evaluation, 0) >= 6 OR high_skill_count >= 1 THEN 2
    ELSE 3
  END,
  retirement_date DESC,
  employee_id;
