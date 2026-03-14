/*
  目的:
    指定した複数のフレームワークスキル条件をすべて満たす現役社員を抽出する。

  想定ユースケース:
    - Spring Boot と Angular 両方の経験者を探す
    - 複数技術要件を持つ案件の候補者抽出

  出力:
    - employee_id

  実装方針:
    - `employee_framework_skill` を起点に条件一致するスキル行を拾う。
    - `GROUP BY + HAVING COUNT(*) = 2` で、2つの固定条件を両方満たす社員だけを返す。
    - 現役社員に限定するため `employee_status_id = 1` を JOIN 条件に置く。

  注意点:
    - 条件数を増減する場合は `HAVING` の件数も合わせて変更する。
    - 現状は固定条件のサンプル実装であり、運用時はパラメータ化が前提。
*/
SELECT
  emp.employee_id
FROM
  employee_framework_skill AS emp_framework
INNER JOIN
  employee AS emp ON
  emp.employee_id = emp_framework.employee_id
INNER JOIN
  employee_status AS es ON
  es.employee_status_id = emp.employee_status_id
  AND es.employee_status_id = 1
WHERE
  (
    emp_framework.skill_level >= 3
    AND emp_framework.framework_skill_id = 4
  )
  OR (
    emp_framework.skill_level >= 3
    AND emp_framework.framework_skill_id = 3
  )
GROUP BY
  emp.employee_id
HAVING
  COUNT(*) = 2
ORDER BY
  emp.employee_id;

