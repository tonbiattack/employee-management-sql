/*
  目的:
    指定した社員ID一覧に紐づくフレームワークスキル詳細を取得する。

  想定ユースケース:
    - 社員一覧の検索結果に対するスキル明細補完
    - 経歴書出力時の一括スキル取得

  入力:
    - 社員ID一覧

  出力:
    - framework_skill_id
    - framework_skill_name
    - skill_level

  実装方針:
    - スキル明細テーブルからマスタを JOIN して名称を解決する。
    - 現役社員のみに限定して、退職・休職者の明細を除外する。

  注意点:
    - 現状は `(61,91)` 固定値のため、実運用では動的IN句へ置き換える。
*/
SELECT
  framework_skill.framework_skill_id,
  framework_skill.framework_skill_name,
  emp_framework.skill_level
FROM
  employee_framework_skill AS emp_framework
INNER JOIN
  framework_skill AS framework_skill ON
  framework_skill.framework_skill_id = emp_framework.framework_skill_id
INNER JOIN
  employee AS emp ON
  emp.employee_id = emp_framework.employee_id
INNER JOIN
  employee_status AS es ON
  es.employee_status_id = emp.employee_status_id
  AND es.employee_status_id = 1
WHERE
  emp.employee_id IN
  (61,91)
ORDER BY
  emp.employee_id;

