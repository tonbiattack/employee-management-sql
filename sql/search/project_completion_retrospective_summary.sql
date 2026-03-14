/*
  目的:
    完了済み案件ごとの参画人数と案件実績記録件数をまとめて確認する。

  想定ユースケース:
    - 振り返り会の事前確認
    - 完了案件の記録充足状況チェック

  主要な出力項目:
    - 案件ID / 案件コード / 案件内容
    - 完了日
    - 参画人数
    - 実績件数 / 評価点記録件数 / 反省点記録件数

  実装方針:
    - 完了報告を起点に案件単位の集計を行う。
    - 参画人数と実績件数は別集計に分け、JOIN による重複集計を避ける。
    - 完了日が古い順、案件ID順に並べる。
*/
WITH assignment_summary AS (
  SELECT
    ap.project_id,
    COUNT(DISTINCT ap.employee_id) AS assigned_member_count
  FROM employee.assignment_project AS ap
  GROUP BY ap.project_id
),
project_record_summary AS (
  SELECT
    epr.project_id,
    COUNT(*) AS project_record_count,
    COUNT(CASE WHEN epr.reflection_point IS NOT NULL AND epr.reflection_point <> '' THEN 1 END) AS reflection_point_record_count,
    COUNT(CASE WHEN epr.evaluation_point IS NOT NULL AND epr.evaluation_point <> '' THEN 1 END) AS evaluation_point_record_count
  FROM employee.employee_project_record AS epr
  GROUP BY epr.project_id
)
SELECT
  p.project_id,
  p.project_code,
  p.project_content,
  pcr.project_completion_date,
  COALESCE(asu.assigned_member_count, 0) AS assigned_member_count,
  COALESCE(prs.project_record_count, 0) AS project_record_count,
  COALESCE(prs.reflection_point_record_count, 0) AS reflection_point_record_count,
  COALESCE(prs.evaluation_point_record_count, 0) AS evaluation_point_record_count
FROM employee.project_completion_report AS pcr
INNER JOIN employee.project AS p
  ON p.project_id = pcr.project_id
LEFT JOIN assignment_summary AS asu
  ON asu.project_id = p.project_id
LEFT JOIN project_record_summary AS prs
  ON prs.project_id = p.project_id
ORDER BY pcr.project_completion_date, p.project_id;
