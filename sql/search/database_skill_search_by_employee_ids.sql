/*
  目的:
    指定した社員ID一覧に紐づくデータベーススキル詳細を取得する。

  想定ユースケース:
    - 社員詳細APIでスキル明細を一括取得する
    - 検索結果に対して追加情報としてスキルをぶら下げる

  入力:
    - employeeIdList: MyBatis の `<foreach>` で展開する社員ID一覧

  出力:
    - database_skill_id
    - database_skill_name
    - skill_level

  実装方針:
    - スキル明細テーブルからスキルマスタを JOIN して名称を解決する。
    - `employee_status = 1` を付け、現役社員だけに限定する。
    - 呼び出し側で社員単位に束ねやすいよう、社員ID順に並べる。
*/
SELECT
  database_skill.database_skill_id,
  database_skill.database_skill_name,
  emp_databaase.skill_level
FROM
  employee_database_skill AS emp_databaase
INNER JOIN
  database_skill AS database_skill ON
  database_skill.database_skill_id = emp_databaase.database_skill_id
INNER JOIN
  employee AS emp ON
  emp.employee_id = emp_databaase.employee_id
INNER JOIN
  employee_status AS es ON
  es.employee_status_id = emp.employee_status_id
  AND es.employee_status_id = 1
WHERE
  -- MyBatis 側で employeeIdList を展開して対象社員を絞り込む。
  emp.employee_id IN
  <foreach item="item" open="(" close=")" collection="employeeIdList" separator=",">
    #{item}
  </foreach>
ORDER BY
  emp.employee_id;

