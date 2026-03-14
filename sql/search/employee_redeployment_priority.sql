/*
  目的:
    再配置候補となる現役社員を、評価・スキル・未配置状態から優先度付きで抽出する。

  想定ユースケース:
    - 案件アサイン会議の候補一覧
    - ベンチ人員の優先対応付け

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - 現在の会社 / チーム / 役職
    - 直近評価 / ハイスキル件数 / 未登録カテゴリ数
    - 配置状態 / 再配置優先度

  実装方針:
    - 直近評価、ハイスキル件数、スキルカテゴリ欠損数を CTE で前計算する。
    - 現役社員の現在値テーブルを JOIN して配置状態を判定する。
    - 無配置度合いと評価を組み合わせて HIGH / MEDIUM / LOW を付与する。
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
all_skill_rows AS (
  SELECT employee_id, skill_level, 'DATABASE' AS skill_category FROM employee.employee_database_skill
  UNION ALL
  SELECT employee_id, skill_level, 'FRAMEWORK' AS skill_category FROM employee.employee_framework_skill
  UNION ALL
  SELECT employee_id, skill_level, 'INFRASTRUCTURE' AS skill_category FROM employee.employee_infrastructure_skill
  UNION ALL
  SELECT employee_id, skill_level, 'PROGRAMMING' AS skill_category FROM employee.employee_programming_skill
),
skill_summary AS (
  SELECT
    asr.employee_id,
    COUNT(CASE WHEN asr.skill_level >= 8 THEN 1 END) AS high_skill_count
  FROM all_skill_rows AS asr
  GROUP BY asr.employee_id
),
skill_category_catalog AS (
  SELECT 'DATABASE' AS skill_category
  UNION ALL SELECT 'FRAMEWORK'
  UNION ALL SELECT 'INFRASTRUCTURE'
  UNION ALL SELECT 'PROGRAMMING'
),
missing_skill_category_summary AS (
  SELECT
    e.employee_id,
    COUNT(*) AS missing_skill_category_count
  FROM employee.employee AS e
  CROSS JOIN skill_category_catalog AS scc
  LEFT JOIN (
    SELECT DISTINCT employee_id, skill_category
    FROM all_skill_rows
  ) AS covered
    ON covered.employee_id = e.employee_id
   AND covered.skill_category = scc.skill_category
  WHERE covered.employee_id IS NULL
  GROUP BY e.employee_id
),
active_employee_context AS (
  SELECT
    e.employee_id,
    e.employee_code,
    CONCAT(e.family_name, e.last_name) AS employee_name,
    c.company_name,
    t.team_name,
    p.position_name AS current_position_name,
    le.evaluation AS latest_evaluation,
    COALESCE(ss.high_skill_count, 0) AS high_skill_count,
    COALESCE(ms.missing_skill_category_count, 4) AS missing_skill_category_count,
    CASE
      WHEN bp.project_id IS NULL THEN 'PROJECT_UNASSIGNED'
      WHEN bt.team_id IS NULL THEN 'TEAM_UNASSIGNED'
      ELSE 'ASSIGNED'
    END AS assignment_status
  FROM employee.employee AS e
  INNER JOIN employee.employee_status AS es
    ON es.employee_status_id = e.employee_status_id
   AND es.employee_status_id = 1
  LEFT JOIN employee.belonging_company AS bc
    ON bc.employee_id = e.employee_id
  LEFT JOIN employee.company AS c
    ON c.company_id = bc.company_id
  LEFT JOIN employee.belonging_team AS bt
    ON bt.employee_id = e.employee_id
  LEFT JOIN employee.team AS t
    ON t.team_id = bt.team_id
  LEFT JOIN employee.current_position AS cp
    ON cp.employee_id = e.employee_id
  LEFT JOIN employee.position AS p
    ON p.position_id = cp.position_id
  LEFT JOIN employee.belonging_project AS bp
    ON bp.employee_id = e.employee_id
  LEFT JOIN latest_evaluation AS le
    ON le.employee_id = e.employee_id
   AND le.rn = 1
  LEFT JOIN skill_summary AS ss
    ON ss.employee_id = e.employee_id
  LEFT JOIN missing_skill_category_summary AS ms
    ON ms.employee_id = e.employee_id
)
SELECT
  employee_id,
  employee_code,
  employee_name,
  company_name,
  team_name,
  current_position_name,
  latest_evaluation,
  high_skill_count,
  missing_skill_category_count,
  assignment_status,
  CASE
    WHEN assignment_status = 'PROJECT_UNASSIGNED'
      AND COALESCE(latest_evaluation, 0) >= 7
      AND high_skill_count >= 1 THEN 'HIGH'
    WHEN assignment_status IN ('PROJECT_UNASSIGNED', 'TEAM_UNASSIGNED')
      AND COALESCE(latest_evaluation, 0) >= 5 THEN 'MEDIUM'
    WHEN assignment_status IN ('PROJECT_UNASSIGNED', 'TEAM_UNASSIGNED') THEN 'LOW'
    ELSE 'ASSIGNED'
  END AS redeployment_priority
FROM active_employee_context
WHERE assignment_status IN ('PROJECT_UNASSIGNED', 'TEAM_UNASSIGNED')
ORDER BY
  CASE
    WHEN assignment_status = 'PROJECT_UNASSIGNED'
      AND COALESCE(latest_evaluation, 0) >= 7
      AND high_skill_count >= 1 THEN 1
    WHEN assignment_status IN ('PROJECT_UNASSIGNED', 'TEAM_UNASSIGNED')
      AND COALESCE(latest_evaluation, 0) >= 5 THEN 2
    ELSE 3
  END,
  high_skill_count DESC,
  COALESCE(latest_evaluation, 0) DESC,
  employee_id;
