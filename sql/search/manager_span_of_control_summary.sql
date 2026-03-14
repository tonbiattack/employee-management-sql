/*
  目的:
    管理職ごとの担当人数と、担当下の高リスク社員・評価漏れ人数を要約する。

  想定ユースケース:
    - 管理職の負荷把握
    - 人事/部門長向けのチーム健全性確認

  主要な出力項目:
    - 管理職社員ID / 社員コード / 社員名 / 役職名
    - チームID / チーム名
    - 担当人数 / 高リスク人数 / 評価未登録人数

  実装方針:
    - 現在役職名から管理職らしい役割名を持つ社員を抽出する。
    - 同じチームに所属する他社員を担当メンバーとみなす。
    - 評価最新年の未登録と、低評価または案件未所属をリスクとして集計する。

  注意点:
    - 管理職判定は役職名のキーワード依存であり、厳密な上長関係テーブルがある場合は差し替えが望ましい。
*/
WITH latest_year AS (
  SELECT MAX(year) AS target_year
  FROM employee.evaluation
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
manager_base AS (
  SELECT
    e.employee_id AS manager_employee_id,
    e.employee_code AS manager_employee_code,
    CONCAT(e.family_name, e.last_name) AS manager_employee_name,
    p.position_name,
    t.team_id,
    t.team_name
  FROM employee.employee AS e
  INNER JOIN employee.employee_status AS es
    ON es.employee_status_id = e.employee_status_id
   AND es.employee_status_id = 1
  INNER JOIN employee.current_position AS cp
    ON cp.employee_id = e.employee_id
  INNER JOIN employee.position AS p
    ON p.position_id = cp.position_id
  INNER JOIN employee.belonging_team AS bt
    ON bt.employee_id = e.employee_id
  INNER JOIN employee.team AS t
    ON t.team_id = bt.team_id
  WHERE LOWER(p.position_name) LIKE '%manager%'
     OR LOWER(p.position_name) LIKE '%lead%'
     OR p.position_name LIKE '%マネージャ%'
     OR p.position_name LIKE '%リーダー%'
),
team_member_context AS (
  SELECT
    mb.manager_employee_id,
    mb.manager_employee_code,
    mb.manager_employee_name,
    mb.position_name,
    mb.team_id,
    mb.team_name,
    e.employee_id AS member_employee_id,
    le.evaluation AS latest_evaluation,
    CASE WHEN bp.project_id IS NULL THEN 1 ELSE 0 END AS has_no_project,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM employee.evaluation AS ev
        INNER JOIN latest_year AS ly
          ON ly.target_year = ev.year
        WHERE ev.employee_id = e.employee_id
      ) THEN 0
      ELSE 1
    END AS is_evaluation_missing
  FROM manager_base AS mb
  INNER JOIN employee.belonging_team AS bt
    ON bt.team_id = mb.team_id
   AND bt.employee_id <> mb.manager_employee_id
  INNER JOIN employee.employee AS e
    ON e.employee_id = bt.employee_id
  INNER JOIN employee.employee_status AS es
    ON es.employee_status_id = e.employee_status_id
   AND es.employee_status_id = 1
  LEFT JOIN latest_evaluation AS le
    ON le.employee_id = e.employee_id
  LEFT JOIN employee.belonging_project AS bp
    ON bp.employee_id = e.employee_id
)
SELECT
  manager_employee_id,
  manager_employee_code,
  manager_employee_name,
  position_name,
  team_id,
  team_name,
  COUNT(DISTINCT member_employee_id) AS managed_member_count,
  COUNT(DISTINCT CASE WHEN (latest_evaluation IS NOT NULL AND latest_evaluation <= 4) OR has_no_project = 1 THEN member_employee_id END) AS high_risk_member_count,
  COUNT(DISTINCT CASE WHEN is_evaluation_missing = 1 THEN member_employee_id END) AS evaluation_missing_member_count
FROM team_member_context
GROUP BY
  manager_employee_id,
  manager_employee_code,
  manager_employee_name,
  position_name,
  team_id,
  team_name
ORDER BY high_risk_member_count DESC, evaluation_missing_member_count DESC, manager_employee_id;
