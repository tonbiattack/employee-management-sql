/*
  目的:
    現役社員のうち、案件未所属またはチーム未所属の社員を抽出する。

  想定ユースケース:
    - ベンチ要員の検出
    - 復職直後や組織解除後の未再配置確認

  主要な出力項目:
    - 社員ID / 社員コード / 社員名
    - 現在の会社 / 部署 / 課 / チーム / 案件
    - 未所属理由コード

  実装方針:
    - 現役社員を基点に現在値テーブルを LEFT JOIN する。
    - 案件未所属とチーム未所属は `UNION ALL` で別行に分ける。
    - 運用画面で扱いやすいよう理由コードを固定文字列で返す。
*/
WITH active_employee_context AS (
  SELECT
    e.employee_id,
    e.employee_code,
    CONCAT(e.family_name, e.last_name) AS employee_name,
    c.company_name,
    d.department_name,
    dv.division_name,
    t.team_name,
    p.project_code
  FROM employee.employee AS e
  INNER JOIN employee.employee_status AS es
    ON es.employee_status_id = e.employee_status_id
  LEFT JOIN employee.belonging_company AS bc
    ON bc.employee_id = e.employee_id
  LEFT JOIN employee.company AS c
    ON c.company_id = bc.company_id
  LEFT JOIN employee.belonging_department AS bd
    ON bd.employee_id = e.employee_id
  LEFT JOIN employee.department AS d
    ON d.department_id = bd.department_id
  LEFT JOIN employee.belonging_division AS bdv
    ON bdv.employee_id = e.employee_id
  LEFT JOIN employee.division AS dv
    ON dv.division_id = bdv.division_id
  LEFT JOIN employee.belonging_team AS bt
    ON bt.employee_id = e.employee_id
  LEFT JOIN employee.team AS t
    ON t.team_id = bt.team_id
  LEFT JOIN employee.belonging_project AS bp
    ON bp.employee_id = e.employee_id
  LEFT JOIN employee.project AS p
    ON p.project_id = bp.project_id
  WHERE es.employee_status_id = 1
)
SELECT
  aec.employee_id,
  aec.employee_code,
  aec.employee_name,
  aec.company_name,
  aec.department_name,
  aec.division_name,
  aec.team_name,
  aec.project_code,
  'PROJECT_UNASSIGNED' AS bench_reason_code
FROM active_employee_context AS aec
WHERE aec.project_code IS NULL

UNION ALL

SELECT
  aec.employee_id,
  aec.employee_code,
  aec.employee_name,
  aec.company_name,
  aec.department_name,
  aec.division_name,
  aec.team_name,
  aec.project_code,
  'TEAM_UNASSIGNED' AS bench_reason_code
FROM active_employee_context AS aec
WHERE aec.team_name IS NULL

ORDER BY employee_id, bench_reason_code;
