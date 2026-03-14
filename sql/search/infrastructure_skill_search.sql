/*
  目的:
    指定した複数のインフラスキル条件をすべて満たす現役社員を抽出する。

  想定ユースケース:
    - Linux と AWS の両方を扱える要員検索
    - 運用保守案件向けの候補者抽出

  出力:
    - employee_id
    - matched_skill_count

  実装方針:
    - `employee_infrastructure_skill` を起点に条件一致したスキルを集計する。
    - `HAVING COUNT(*) = 2` により2条件を両方満たす社員だけを返す。
    - `employee_status_id = 1` の現役社員に限定する。

  注意点:
    - 現状は `infrastructure_skill_id = 4, 3` の固定条件。
    - 可変条件化する場合は `HAVING` の値も動的に見直す。
*/
SELECT
  emp.employee_id,
  COUNT(*) AS matched_skill_count
FROM
  employee_infrastructure_skill AS emp_infra
INNER JOIN
  employee AS emp ON
  emp.employee_id = emp_infra.employee_id
INNER JOIN
  employee_status AS es ON
  es.employee_status_id = emp.employee_status_id
  AND es.employee_status_id = 1
WHERE
  (
    emp_infra.skill_level >= 3
    AND emp_infra.infrastructure_skill_id = 4
  )
  OR (
    emp_infra.skill_level >= 3
    AND emp_infra.infrastructure_skill_id = 3
  )
GROUP BY
  emp.employee_id
HAVING
  COUNT(*) = 2
ORDER BY
  emp.employee_id;
