/*
  目的:
    再雇用候補となる退職社員を、直近評価とスキルから優先度付きで抽出する。

  想定ユースケース:
    - 再雇用候補リスト作成
    - 急募案件向けの過去人材棚卸し

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - 退職日 / 再雇用許可
    - 直近評価 / ハイスキル件数 / 連絡先バケット
    - 再雇用優先度

  実装方針:
    - `retired_employee.returning_permission = true` のみ対象にする。
    - 退職日、直近評価、カテゴリ横断ハイスキル件数を集約する。
    - 評価とハイスキル件数が高い候補を HIGH とする。
*/
WITH latest_retirement AS (
  SELECT
    rt.employee_id,
    MAX(rt.retirement_date) AS retirement_date
  FROM employee.retirement AS rt
  GROUP BY rt.employee_id
),
latest_evaluation AS (
  SELECT
    ev.employee_id,
    ev.evaluation,
    ROW_NUMBER() OVER (
      PARTITION BY ev.employee_id
      ORDER BY ev.year DESC, ev.quarter DESC
    ) AS rn
  FROM employee.evaluation AS ev
),
high_skill_summary AS (
  SELECT
    s.employee_id,
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
  GROUP BY s.employee_id
),
contact_summary AS (
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
  GROUP BY eci.employee_id
)
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  lr.retirement_date,
  re.returning_permission,
  le.evaluation AS latest_evaluation,
  COALESCE(hss.high_skill_count, 0) AS high_skill_count,
  COALESCE(cs.contact_bucket, 'NO_CONTACT') AS contact_bucket,
  CASE
    WHEN COALESCE(le.evaluation, 0) >= 8 AND COALESCE(hss.high_skill_count, 0) >= 2 THEN 'HIGH'
    WHEN COALESCE(le.evaluation, 0) >= 6 OR COALESCE(hss.high_skill_count, 0) >= 1 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS rehire_priority
FROM employee.retired_employee AS re
INNER JOIN employee.employee AS e
  ON e.employee_id = re.employee_id
INNER JOIN latest_retirement AS lr
  ON lr.employee_id = re.employee_id
LEFT JOIN latest_evaluation AS le
  ON le.employee_id = re.employee_id
 AND le.rn = 1
LEFT JOIN high_skill_summary AS hss
  ON hss.employee_id = re.employee_id
LEFT JOIN contact_summary AS cs
  ON cs.employee_id = re.employee_id
WHERE re.returning_permission = TRUE
ORDER BY
  CASE rehire_priority
    WHEN 'HIGH' THEN 1
    WHEN 'MEDIUM' THEN 2
    ELSE 3
  END,
  lr.retirement_date DESC,
  e.employee_id;
