/*
  目的:
    指定した複数のプログラミングスキル条件をすべて満たす現役社員を抽出する。

  想定ユースケース:
    - 要件スキルを複数持つ候補者検索
    - 案件アサイン前の人材絞り込み

  出力:
    - employee_id
    - matched_skill_count: 条件に一致したスキル件数

  実装方針:
    - `employee_programming_skill` を起点に現役社員へ絞り込む。
    - 現状は `programming_skill_id IN (4, 3)` かつ `skill_level >= 3` の固定条件。
    - `GROUP BY + HAVING COUNT(*) = 2` で、対象2スキルの両方を満たす社員だけを返す。

  注意点:
    - 条件数が可変になる実装では、`HAVING` の件数も入力条件数に合わせる必要がある。
    - WHERE句は可読性確保のため括弧を付けている。
*/
SELECT
  emp.employee_id,
  COUNT(*) AS matched_skill_count
FROM
  employee_programming_skill AS emp_program
INNER JOIN
  employee AS emp ON
  emp.employee_id = emp_program.employee_id
INNER JOIN
  employee_status AS es ON
  es.employee_status_id = emp.employee_status_id
  AND es.employee_status_id = 1
WHERE
  (
    emp_program.skill_level >= 3
    AND emp_program.programming_skill_id = 4
  )
  OR (
    emp_program.skill_level >= 3
    AND emp_program.programming_skill_id = 3
  )
GROUP BY
  emp.employee_id
HAVING
  COUNT(*) = 2
ORDER BY
  emp.employee_id;

