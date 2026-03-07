/*
  目的:
    各スキルカテゴリ（DATABASE / FRAMEWORK / INFRASTRUCTURE / PROGRAMMING）で
    skill_level が 8 以上の社員を一覧取得する。

  出力カラム:
    employee_id    : 社員ID
    employee_code  : 社員コード
    employee_name  : 氏名（姓 + 名）
    skill_type     : スキルカテゴリ
    skill_name     : スキル名
    skill_level    : スキルレベル

  実装方針:
    - 各カテゴリごとに「社員テーブル + 中間テーブル + マスタテーブル」をJOINする。
    - UNION ALL で結合し、カテゴリ横断の結果セットを1本化する。
      （重複排除が不要なため UNION ではなく UNION ALL を使用）
    - ORDER BY で結果順を固定し、テストで比較しやすくする。
*/

-- 1) データベーススキル（employee_database_skill）
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  'DATABASE' AS skill_type,
  ds.database_skill_name AS skill_name,
  eds.skill_level
FROM employee.employee AS e
INNER JOIN employee.employee_database_skill AS eds
  ON e.employee_id = eds.employee_id
INNER JOIN employee.database_skill AS ds
  ON eds.database_skill_id = ds.database_skill_id
WHERE eds.skill_level >= 8

UNION ALL

-- 2) フレームワークスキル（employee_framework_skill）
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  'FRAMEWORK' AS skill_type,
  fs.framework_skill_name AS skill_name,
  efs.skill_level
FROM employee.employee AS e
INNER JOIN employee.employee_framework_skill AS efs
  ON e.employee_id = efs.employee_id
INNER JOIN employee.framework_skill AS fs
  ON efs.framework_skill_id = fs.framework_skill_id
WHERE efs.skill_level >= 8

UNION ALL

-- 3) インフラスキル（employee_infrastructure_skill）
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  'INFRASTRUCTURE' AS skill_type,
  ins.infrastructure_skill_name AS skill_name,
  eis.skill_level
FROM employee.employee AS e
INNER JOIN employee.employee_infrastructure_skill AS eis
  ON e.employee_id = eis.employee_id
INNER JOIN employee.infrastructure_skill AS ins
  ON eis.infrastructure_skill_id = ins.infrastructure_skill_id
WHERE eis.skill_level >= 8

UNION ALL

-- 4) プログラミングスキル（employee_programming_skill）
SELECT
  e.employee_id,
  e.employee_code,
  CONCAT(e.family_name, e.last_name) AS employee_name,
  'PROGRAMMING' AS skill_type,
  ps.programming_skill_name AS skill_name,
  eps.skill_level
FROM employee.employee AS e
INNER JOIN employee.employee_programming_skill AS eps
  ON e.employee_id = eps.employee_id
INNER JOIN employee.programming_skill AS ps
  ON eps.programming_skill_id = ps.programming_skill_id
WHERE eps.skill_level >= 8

-- テストで安定比較できるよう、順序を明示的に固定する。
ORDER BY employee_id, skill_type, skill_level DESC, skill_name;
