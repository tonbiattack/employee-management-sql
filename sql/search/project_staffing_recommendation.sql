/*
  目的:
    案件ごとに、現在未配属または未整備の現役社員から補充候補を優先順位付きで返す。

  想定ユースケース:
    - 要員計画会議での候補提示
    - スキルギャップを埋める追加アサイン候補の抽出

  主要な出力項目:
    - 案件ID / 案件コード
    - 候補社員ID / 社員コード / 社員名
    - 候補社員の配置状態 / 直近評価 / ハイスキル件数
    - 案件側の不足カテゴリ数 / 候補者が補完できる不足カテゴリ数
    - 推薦スコア / 案件内順位

  実装方針:
    - まず案件ごとの現行スキルカテゴリ網羅状況を集計する。
    - 次に再配置候補となる現役社員の状態を集約する。
    - 案件の不足カテゴリをどれだけ補完できるかでスコア化し、案件単位で順位付けする。
*/
WITH all_skill_rows AS (
  SELECT employee_id, skill_level, 'DATABASE' AS skill_category FROM employee.employee_database_skill
  UNION ALL
  SELECT employee_id, skill_level, 'FRAMEWORK' AS skill_category FROM employee.employee_framework_skill
  UNION ALL
  SELECT employee_id, skill_level, 'INFRASTRUCTURE' AS skill_category FROM employee.employee_infrastructure_skill
  UNION ALL
  SELECT employee_id, skill_level, 'PROGRAMMING' AS skill_category FROM employee.employee_programming_skill
),
skill_category_catalog AS (
  SELECT 'DATABASE' AS skill_category
  UNION ALL SELECT 'FRAMEWORK'
  UNION ALL SELECT 'INFRASTRUCTURE'
  UNION ALL SELECT 'PROGRAMMING'
),
latest_evaluation AS (
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
  WHERE rn = 1
),
candidate_skill_summary AS (
  SELECT
    employee_id,
    COUNT(CASE WHEN skill_level >= 8 THEN 1 END) AS high_skill_count
  FROM all_skill_rows
  GROUP BY employee_id
),
candidate_skill_coverage AS (
  SELECT DISTINCT employee_id, skill_category
  FROM all_skill_rows
),
redeployment_candidate AS (
  SELECT
    e.employee_id,
    e.employee_code,
    CONCAT(e.family_name, e.last_name) AS employee_name,
    CASE
      WHEN bp.project_id IS NULL THEN 'PROJECT_UNASSIGNED'
      WHEN bt.team_id IS NULL THEN 'TEAM_UNASSIGNED'
      ELSE 'ASSIGNED'
    END AS assignment_status,
    le.evaluation AS latest_evaluation,
    COALESCE(css.high_skill_count, 0) AS high_skill_count
  FROM employee.employee AS e
  INNER JOIN employee.employee_status AS es
    ON es.employee_status_id = e.employee_status_id
   AND es.employee_status_id = 1
  LEFT JOIN employee.belonging_project AS bp
    ON bp.employee_id = e.employee_id
  LEFT JOIN employee.belonging_team AS bt
    ON bt.employee_id = e.employee_id
  LEFT JOIN latest_evaluation AS le
    ON le.employee_id = e.employee_id
  LEFT JOIN candidate_skill_summary AS css
    ON css.employee_id = e.employee_id
  WHERE bp.project_id IS NULL OR bt.team_id IS NULL
),
current_project_member AS (
  SELECT DISTINCT project_id, employee_id
  FROM employee.assignment_project
  WHERE assignment_project_end_date IS NULL
),
project_missing_category AS (
  SELECT
    p.project_id,
    p.project_code,
    scc.skill_category,
    CASE WHEN covered.skill_category IS NULL THEN 1 ELSE 0 END AS is_missing
  FROM employee.project AS p
  CROSS JOIN skill_category_catalog AS scc
  LEFT JOIN (
    SELECT DISTINCT cpm.project_id, csc.skill_category
    FROM current_project_member AS cpm
    INNER JOIN candidate_skill_coverage AS csc
      ON csc.employee_id = cpm.employee_id
  ) AS covered
    ON covered.project_id = p.project_id
   AND covered.skill_category = scc.skill_category
),
project_missing_summary AS (
  SELECT
    project_id,
    project_code,
    SUM(is_missing) AS project_missing_skill_category_count
  FROM project_missing_category
  GROUP BY project_id, project_code
),
recommendation_base AS (
  SELECT
    pms.project_id,
    pms.project_code,
    rc.employee_id,
    rc.employee_code,
    rc.employee_name,
    rc.assignment_status,
    rc.latest_evaluation,
    rc.high_skill_count,
    pms.project_missing_skill_category_count,
    COUNT(CASE WHEN csc.skill_category IS NOT NULL THEN 1 END) AS candidate_covered_missing_category_count
  FROM project_missing_summary AS pms
  INNER JOIN redeployment_candidate AS rc
    ON rc.assignment_status IN ('PROJECT_UNASSIGNED', 'TEAM_UNASSIGNED')
  LEFT JOIN project_missing_category AS pmc
    ON pmc.project_id = pms.project_id
   AND pmc.is_missing = 1
  LEFT JOIN candidate_skill_coverage AS csc
    ON csc.employee_id = rc.employee_id
   AND csc.skill_category = pmc.skill_category
  WHERE NOT EXISTS (
    SELECT 1
    FROM current_project_member AS cpm
    WHERE cpm.project_id = pms.project_id
      AND cpm.employee_id = rc.employee_id
  )
  GROUP BY
    pms.project_id,
    pms.project_code,
    rc.employee_id,
    rc.employee_code,
    rc.employee_name,
    rc.assignment_status,
    rc.latest_evaluation,
    rc.high_skill_count,
    pms.project_missing_skill_category_count
)
SELECT
  rb.project_id,
  rb.project_code,
  rb.employee_id,
  rb.employee_code,
  rb.employee_name,
  rb.assignment_status,
  rb.latest_evaluation,
  rb.high_skill_count,
  rb.project_missing_skill_category_count,
  rb.candidate_covered_missing_category_count,
  rb.candidate_covered_missing_category_count * 10
    + COALESCE(rb.latest_evaluation, 0)
    + CASE WHEN rb.high_skill_count >= 1 THEN 2 ELSE 0 END AS recommendation_score,
  ROW_NUMBER() OVER (
    PARTITION BY rb.project_id
    ORDER BY
      rb.candidate_covered_missing_category_count DESC,
      COALESCE(rb.latest_evaluation, 0) DESC,
      rb.high_skill_count DESC,
      rb.employee_id
  ) AS recommendation_rank
FROM recommendation_base AS rb
WHERE rb.candidate_covered_missing_category_count > 0
ORDER BY rb.project_id, recommendation_rank, rb.employee_id;
