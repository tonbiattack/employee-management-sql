/*
  目的:
    案件ごとのハイスキル充足度とスキルカテゴリ偏りを可視化する。

  想定ユースケース:
    - 要員計画時の案件リスク確認
    - ハイスキル偏在の検知

  主要な出力項目:
    - 案件ID / 案件コード
    - 配属人数 / ハイスキル人数 / ハイスキル充足率
    - 欠けているスキルカテゴリ数
    - リスクレベル

  実装方針:
    - 案件配属メンバーを起点にカテゴリ横断のスキルを集約する。
    - 案件単位で「ハイスキル保持者数」と「出現カテゴリ数」を別々に算出する。
    - 充足率とカテゴリ欠損から HIGH / MEDIUM / LOW を付ける。
*/
WITH assignment_base AS (
  SELECT
    ap.project_id,
    p.project_code,
    ap.employee_id
  FROM employee.assignment_project AS ap
  INNER JOIN employee.project AS p
    ON p.project_id = ap.project_id
),
employee_skill_summary AS (
  SELECT
    s.employee_id,
    MAX(CASE WHEN s.skill_level >= 8 THEN 1 ELSE 0 END) AS is_high_skill
  FROM (
    SELECT employee_id, skill_level FROM employee.employee_database_skill
    UNION ALL
    SELECT employee_id, skill_level FROM employee.employee_framework_skill
    UNION ALL
    SELECT employee_id, skill_level FROM employee.employee_infrastructure_skill
    UNION ALL
    SELECT employee_id, skill_level FROM employee.employee_programming_skill
  ) AS s
  GROUP BY s.employee_id
),
project_category_coverage AS (
  SELECT
    ab.project_id,
    COUNT(DISTINCT cat.skill_category) AS covered_skill_category_count
  FROM assignment_base AS ab
  LEFT JOIN (
    SELECT employee_id, 'DATABASE' AS skill_category FROM employee.employee_database_skill
    UNION ALL
    SELECT employee_id, 'FRAMEWORK' AS skill_category FROM employee.employee_framework_skill
    UNION ALL
    SELECT employee_id, 'INFRASTRUCTURE' AS skill_category FROM employee.employee_infrastructure_skill
    UNION ALL
    SELECT employee_id, 'PROGRAMMING' AS skill_category FROM employee.employee_programming_skill
  ) AS cat
    ON cat.employee_id = ab.employee_id
  GROUP BY ab.project_id
)
SELECT
  ab.project_id,
  ab.project_code,
  COUNT(DISTINCT ab.employee_id) AS assigned_member_count,
  COUNT(DISTINCT CASE WHEN ess.is_high_skill = 1 THEN ab.employee_id END) AS high_skill_member_count,
  CAST(ROUND(
    COUNT(DISTINCT CASE WHEN ess.is_high_skill = 1 THEN ab.employee_id END) /
    NULLIF(COUNT(DISTINCT ab.employee_id), 0),
    2
  ) AS CHAR) AS high_skill_coverage_ratio,
  4 - COALESCE(pcc.covered_skill_category_count, 0) AS missing_skill_category_count,
  CASE
    WHEN (
      COUNT(DISTINCT CASE WHEN ess.is_high_skill = 1 THEN ab.employee_id END) /
      NULLIF(COUNT(DISTINCT ab.employee_id), 0)
    ) < 0.6
      AND (4 - COALESCE(pcc.covered_skill_category_count, 0)) >= 2 THEN 'HIGH'
    WHEN (
      COUNT(DISTINCT CASE WHEN ess.is_high_skill = 1 THEN ab.employee_id END) /
      NULLIF(COUNT(DISTINCT ab.employee_id), 0)
    ) < 0.6 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS staffing_risk_level
FROM assignment_base AS ab
LEFT JOIN employee_skill_summary AS ess
  ON ess.employee_id = ab.employee_id
LEFT JOIN project_category_coverage AS pcc
  ON pcc.project_id = ab.project_id
GROUP BY ab.project_id, ab.project_code, pcc.covered_skill_category_count
ORDER BY
  CASE staffing_risk_level
    WHEN 'HIGH' THEN 1
    WHEN 'MEDIUM' THEN 2
    ELSE 3
  END,
  ab.project_id;
