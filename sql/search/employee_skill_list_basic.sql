-- ========================================
-- SQLファイル: employee_skill_list_basic.sql
-- 目的:
--   社員詳細画面の「スキル一覧」タブ向けSQL。
-- 入力:
--   employee_id（例では 1 を固定）
-- 出力:
--   スキル種別 / スキル名 / スキルレベル
-- ========================================
SELECT
  'DATABASE' AS skill_type,
  ds.database_skill_name AS skill_name,
  eds.skill_level
FROM employee.employee_database_skill AS eds
INNER JOIN employee.database_skill AS ds
  ON ds.database_skill_id = eds.database_skill_id
WHERE eds.employee_id = 1

UNION ALL

SELECT
  'FRAMEWORK' AS skill_type,
  fs.framework_skill_name AS skill_name,
  efs.skill_level
FROM employee.employee_framework_skill AS efs
INNER JOIN employee.framework_skill AS fs
  ON fs.framework_skill_id = efs.framework_skill_id
WHERE efs.employee_id = 1

UNION ALL

SELECT
  'INFRASTRUCTURE' AS skill_type,
  ins.infrastructure_skill_name AS skill_name,
  eis.skill_level
FROM employee.employee_infrastructure_skill AS eis
INNER JOIN employee.infrastructure_skill AS ins
  ON ins.infrastructure_skill_id = eis.infrastructure_skill_id
WHERE eis.employee_id = 1

UNION ALL

SELECT
  'PROGRAMMING' AS skill_type,
  ps.programming_skill_name AS skill_name,
  eps.skill_level
FROM employee.employee_programming_skill AS eps
INNER JOIN employee.programming_skill AS ps
  ON ps.programming_skill_id = eps.programming_skill_id
WHERE eps.employee_id = 1

ORDER BY skill_type, skill_level DESC, skill_name;
