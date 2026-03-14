/*
  目的:
    社員詳細画面の「スキル一覧」タブ用に、全スキルカテゴリを横断して取得する。

  想定ユースケース:
    - 社員詳細画面のスキル一覧表示
    - 経歴書作成時の保有技術一覧出力

  入力:
    - employee_id: 対象社員ID

  出力:
    - skill_type
    - skill_name
    - skill_level

  実装方針:
    - 4つのスキルカテゴリを `UNION ALL` で縦持ちに統一する。
    - 表示時に扱いやすいよう `skill_type`, `skill_level DESC`, `skill_name` で整列する。

  注意点:
    - 現状は `employee_id = 1` 固定のため、実運用ではパラメータ化する。
*/
SELECT
  -- データベーススキル
  'DATABASE' AS skill_type,
  ds.database_skill_name AS skill_name,
  eds.skill_level
FROM employee.employee_database_skill AS eds
INNER JOIN employee.database_skill AS ds
  ON ds.database_skill_id = eds.database_skill_id
WHERE eds.employee_id = 1

UNION ALL

SELECT
  -- フレームワークスキル
  'FRAMEWORK' AS skill_type,
  fs.framework_skill_name AS skill_name,
  efs.skill_level
FROM employee.employee_framework_skill AS efs
INNER JOIN employee.framework_skill AS fs
  ON fs.framework_skill_id = efs.framework_skill_id
WHERE efs.employee_id = 1

UNION ALL

SELECT
  -- インフラスキル
  'INFRASTRUCTURE' AS skill_type,
  ins.infrastructure_skill_name AS skill_name,
  eis.skill_level
FROM employee.employee_infrastructure_skill AS eis
INNER JOIN employee.infrastructure_skill AS ins
  ON ins.infrastructure_skill_id = eis.infrastructure_skill_id
WHERE eis.employee_id = 1

UNION ALL

SELECT
  -- プログラミングスキル
  'PROGRAMMING' AS skill_type,
  ps.programming_skill_name AS skill_name,
  eps.skill_level
FROM employee.employee_programming_skill AS eps
INNER JOIN employee.programming_skill AS ps
  ON ps.programming_skill_id = eps.programming_skill_id
WHERE eps.employee_id = 1

ORDER BY skill_type, skill_level DESC, skill_name;
