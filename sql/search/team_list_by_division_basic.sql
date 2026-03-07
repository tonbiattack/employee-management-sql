-- ========================================
-- SQLファイル: team_list_by_division_basic.sql
-- 目的:
--   課（division）配下のチーム一覧を表示するSQL。
-- 入力:
--   division_id（例では 1 を固定）
-- ========================================
SELECT
  t.team_id,
  t.team_code,
  t.team_name,
  d.division_name
FROM employee.team AS t
INNER JOIN employee.division AS d
  ON d.division_id = t.division_id
WHERE t.division_id = 1
ORDER BY t.team_id;
