/*
  目的:
    指定した複数のデータベーススキル条件をすべて満たす現役社員を抽出する。

  想定ユースケース:
    - DB要件の厳しい案件向け候補者検索
    - 特定DB経験者の絞り込み

  出力:
    - employee_id

  実装方針:
    - `employee_database_skill` を起点に現役社員へ絞り込む。
    - 本来は `database_skill_id` と `skill_level` を組み合わせた複数条件を評価する。
    - `GROUP BY + HAVING COUNT(*)` で複数条件をすべて満たす社員だけを返す。

  注意点:
    - 現行SQLは旧版のコピペ痕跡があり、`WHERE` で `emp_framework.*` を参照している。
    - 実運用前に `emp_databaase.*` または適切なエイリアスへ修正すること。
*/
SELECT
  emp.employee_id
FROM
  employee_database_skill AS emp_databaase
INNER JOIN
  employee AS emp ON
  emp.employee_id = emp_databaase.employee_id
INNER JOIN
  employee_status AS es ON
  es.employee_status_id = emp.employee_status_id
  AND es.employee_status_id = 1
WHERE
  -- 旧版由来の誤参照が残っている。修正前提のサンプルとして保持している。
  emp_framework.skill_level >= 3 AND emp_framework.framework_skill_id = 4
  OR emp_framework.skill_level >= 3 AND emp_framework.framework_skill_id = 3
GROUP BY
  emp.employee_id
HAVING
  COUNT(*) = 2
ORDER BY
  emp.employee_id;

