-- ========================================
-- SQLファイル: constraint.sql
-- 目的: このSQLの実行内容を明示するためのヘッダーコメント
-- 備考: 必要に応じて詳細な業務目的・前提条件を追記してください
-- ========================================

alter table active_employee_contact_information
  add constraint active_employee_contact_information_FK1 foreign key (employee_contact_information_id) references employee_contact_information(employee_contact_information_id);

alter table assigned_department
  add constraint assigned_department_FK1 foreign key (employee_id) references employee(employee_id);

alter table assigned_department
  add constraint assigned_department_FK2 foreign key (department_id) references department(department_id);

alter table assigned_division
  add constraint assigned_division_FK1 foreign key (employee_id) references employee(employee_id);

alter table assigned_division
  add constraint assigned_division_FK2 foreign key (division_id) references division(division_id);

alter table assigned_team
  add constraint assigned_team_FK1 foreign key (employee_id) references employee(employee_id);

alter table assigned_team
  add constraint assigned_team_FK2 foreign key (team_id) references team(team_id);

alter table assignment_project
  add constraint assignment_project_FK1 foreign key (project_id) references project(project_id);

alter table assignment_project
  add constraint assignment_project_FK2 foreign key (employee_id) references employee(employee_id);

alter table assumption_of_position
  add constraint assumption_of_position_FK1 foreign key (position_id) references position(position_id);

alter table assumption_of_position
  add constraint assumption_of_position_FK2 foreign key (employee_id) references employee(employee_id);

alter table belonging_company
  add constraint belonging_company_FK1 foreign key (employee_id) references employee(employee_id);

alter table belonging_company
  add constraint belonging_company_FK2 foreign key (company_id) references company(company_id);

alter table belonging_department
  add constraint belonging_department_FK1 foreign key (employee_id) references employee(employee_id);

alter table belonging_department
  add constraint belonging_department_FK2 foreign key (department_id) references department(department_id);

alter table belonging_division
  add constraint belonging_division_FK1 foreign key (division_id) references division(division_id);

alter table belonging_division
  add constraint belonging_division_FK2 foreign key (employee_id) references employee(employee_id);

alter table belonging_project
  add constraint belonging_project_FK1 foreign key (project_id) references project(project_id);

alter table belonging_project
  add constraint belonging_project_FK2 foreign key (employee_id) references employee(employee_id);

alter table belonging_team
  add constraint belonging_team_FK1 foreign key (employee_id) references employee(employee_id);

alter table belonging_team
  add constraint belonging_team_FK2 foreign key (team_id) references team(team_id);

alter table company_assignment
  add constraint company_assignment_FK1 foreign key (company_id) references company(company_id);

alter table company_assignment
  add constraint company_assignment_FK2 foreign key (employee_id) references employee(employee_id);

alter table contact_information_for_staff_on_leave
  add constraint contact_information_for_staff_on_leave_FK1 foreign key (employee_contact_information_id) references employee_contact_information(employee_contact_information_id);

alter table current_position
  add constraint current_position_FK1 foreign key (employee_id) references employee(employee_id);

alter table current_position
  add constraint current_position_FK2 foreign key (position_id) references position(position_id);

alter table department
  add constraint department_FK1 foreign key (company_id) references company(company_id);

alter table division
  add constraint division_FK1 foreign key (business_partner_id) references business_partner(business_partner_id);

alter table division
  add constraint division_FK2 foreign key (department_id) references department(department_id);

alter table employee
  add constraint employee_FK1 foreign key (employee_status_id) references employee_status(employee_status_id);

alter table employee
  add constraint employee_FK2 foreign key (gender_id) references gender(gender_id);

alter table employee_address
  add constraint employee_address_FK1 foreign key (employee_id) references employee(employee_id);

alter table employee_contact_information
  add constraint employee_contact_information_FK1 foreign key (employee_id) references employee(employee_id);

alter table employee_database_skill
  add constraint employee_database_skill_FK1 foreign key (employee_id) references employee(employee_id);

alter table employee_database_skill
  add constraint employee_database_skill_FK2 foreign key (database_skill_id) references database_skill(database_skill_id);

alter table employee_framework_skill
  add constraint employee_framework_skill_FK1 foreign key (employee_id) references employee(employee_id);

alter table employee_framework_skill
  add constraint employee_framework_skill_FK2 foreign key (framework_skill_id) references framework_skill(framework_skill_id);

alter table employee_infrastructure_skill
  add constraint employee_infrastructure_skill_FK1 foreign key (employee_id) references employee(employee_id);

alter table employee_infrastructure_skill
  add constraint employee_infrastructure_skill_FK2 foreign key (infrastructure_skill_id) references infrastructure_skill(infrastructure_skill_id);

alter table employee_programming_skill
  add constraint employee_programming_skill_FK1 foreign key (employee_id) references employee(employee_id);

alter table employee_programming_skill
  add constraint employee_programming_skill_FK2 foreign key (programming_skill_id) references programming_skill(programming_skill_id);

alter table employee_project_record
  add constraint employee_project_record_FK1 foreign key (project_id) references project(project_id);

alter table employee_project_record
  add constraint employee_project_record_FK2 foreign key (employee_id) references employee(employee_id);

alter table evaluation
  add constraint evaluation_FK1 foreign key (employee_id) references employee(employee_id);

alter table joining_the_company
  add constraint joining_the_company_FK1 foreign key (employee_id) references employee(employee_id);

alter table leave_of_absence
  add constraint leave_of_absence_FK1 foreign key (employee_id) references employee(employee_id);

alter table project
  add constraint project_FK1 foreign key (business_partner_id) references business_partner(business_partner_id);

alter table project_completion_report
  add constraint project_completion_report_FK1 foreign key (project_id) references project(project_id);

alter table reinstatement
  add constraint reinstatement_FK1 foreign key (employee_id) references employee(employee_id);

alter table retired_employee
  add constraint retired_employee_FK1 foreign key (employee_id) references employee(employee_id);

alter table retired_employee_contact_information
  add constraint retired_employee_contact_information_FK1 foreign key (employee_contact_information_id) references employee_contact_information(employee_contact_information_id);

alter table retirement
  add constraint retirement_FK1 foreign key (employee_id) references employee(employee_id);

alter table team
  add constraint team_FK1 foreign key (division_id) references division(division_id);

-- ========================================
-- 追加: UNIQUE / CHECK 制約
-- ========================================
-- このセクションの目的:
--   1) データ重複をDBレベルで防止する（UNIQUE）
--   2) 不正値の登録をDBレベルで防止する（CHECK）
--   3) アプリ側の実装ミスがあっても整合性を崩さない最終防衛線にする

-- 社員コードは社員を一意に識別する業務キーのため重複不可。
alter table employee
  add constraint employee_UK1 unique (employee_code);

-- 会社コードはマスタ連携・画面表示で利用される識別子のため重複不可。
alter table company
  add constraint company_UK1 unique (company_code);

-- 取引先コードは外部連携・参照で利用される識別子のため重複不可。
alter table business_partner
  add constraint business_partner_UK1 unique (business_partner_code);

-- 部署コードは「会社内」で一意に管理する想定のため複合一意にする。
alter table department
  add constraint department_UK1 unique (company_id, department_code);

-- 課コードは「部署内」で一意に管理する想定のため複合一意にする。
alter table division
  add constraint division_UK1 unique (department_id, division_code);

-- チームコードは「課内」で一意に管理する想定のため複合一意にする。
alter table team
  add constraint team_UK1 unique (division_id, team_code);

-- ロール名は権限の識別子であり同名ロール重複を防ぐ。
alter table role
  add constraint role_UK1 unique (role_name);

-- 役職コードは役職マスタの識別子であり重複不可。
alter table position
  add constraint position_UK1 unique (position_code);

-- スキルマスタ名は同義重複を防ぎ検索・集計の一貫性を保つため一意にする。
alter table database_skill
  add constraint database_skill_UK1 unique (database_skill_name);

alter table framework_skill
  add constraint framework_skill_UK1 unique (framework_skill_name);

alter table infrastructure_skill
  add constraint infrastructure_skill_UK1 unique (infrastructure_skill_name);

alter table programming_skill
  add constraint programming_skill_UK1 unique (programming_skill_name);

-- 現在所属は社員ごとに1件を想定するため employee_id を一意にする。
-- （履歴は company_assignment など履歴テーブル側で管理する）
alter table belonging_company
  add constraint belonging_company_UK1 unique (employee_id);

alter table belonging_department
  add constraint belonging_department_UK1 unique (employee_id);

alter table belonging_division
  add constraint belonging_division_UK1 unique (employee_id);

alter table belonging_team
  add constraint belonging_team_UK1 unique (employee_id);

alter table belonging_project
  add constraint belonging_project_UK1 unique (employee_id);

-- 連絡先ロールテーブルは同一連絡先の重複登録を防ぐ。
-- （現役/休職/退職のどこに属するかは状態遷移ロジックで制御）
alter table active_employee_contact_information
  add constraint active_employee_contact_information_UK1 unique (employee_contact_information_id);

alter table contact_information_for_staff_on_leave
  add constraint contact_information_for_staff_on_leave_UK1 unique (employee_contact_information_id);

alter table retired_employee_contact_information
  add constraint retired_employee_contact_information_UK1 unique (employee_contact_information_id);

-- 退職状態テーブルは社員単位で1件に制限する。
alter table retired_employee
  add constraint retired_employee_UK1 unique (employee_id);

-- 同一社員・同一期間の評価重複を防止する。
alter table evaluation
  add constraint evaluation_UK1 unique (employee_id, year, quarter);

-- 入社/休職/復職/退職/配属履歴は同日重複イベントを防止する。
alter table joining_the_company
  add constraint joining_the_company_UK1 unique (employee_id, joining_the_company_date);

alter table leave_of_absence
  add constraint leave_of_absence_UK1 unique (employee_id, leave_of_absence_date);

alter table reinstatement
  add constraint reinstatement_UK1 unique (employee_id, reinstatement_date);

alter table retirement
  add constraint retirement_UK1 unique (employee_id, retirement_date);

alter table company_assignment
  add constraint company_assignment_UK1 unique (employee_id, company_assignment_date);

-- 会社所属期間の終了日は、開始日以前にならないようにする。
-- NULL は「現在も所属中」を表す必要悪として許容する。
alter table company_assignment
  add constraint company_assignment_CK1 check (
    company_assignment_end_date is null
    or company_assignment_date <= company_assignment_end_date
  );

-- 配属/就任の期間終了日は、開始日以前にならないようにする。
-- NULL は「現在も継続中」を表すため許容する。
alter table assigned_department
  add constraint assigned_department_CK1 check (
    assigned_department_end_date is null
    or assigned_department_date <= assigned_department_end_date
  );

alter table assigned_division
  add constraint assigned_division_CK1 check (
    assigned_division_end_date is null
    or assigned_division_date <= assigned_division_end_date
  );

alter table assigned_team
  add constraint assigned_team_CK1 check (
    assigned_team_end_date is null
    or assigned_team_date <= assigned_team_end_date
  );

alter table assignment_project
  add constraint assignment_project_CK1 check (
    assignment_project_end_date is null
    or assignment_project_date <= assignment_project_end_date
  );

alter table assumption_of_position
  add constraint assumption_of_position_CK1 check (
    assumption_of_position_end_date is null
    or assumption_of_position_date <= assumption_of_position_end_date
  );

-- quarter は業務定義上 1〜4 のみ許可。
alter table evaluation
  add constraint evaluation_CK1 check (quarter between 1 and 4);

-- 評価点は業務定義上 1〜10 のみ許可。
alter table evaluation
  add constraint evaluation_CK2 check (evaluation between 1 and 10);

-- 等級は1以上を前提とし、0以下の不正データを防止。
alter table employee
  add constraint employee_CK1 check (grade >= 1);

-- スキルレベルは全カテゴリで 1〜10 の共通尺度を強制する。
alter table employee_database_skill
  add constraint employee_database_skill_CK1 check (skill_level between 1 and 10);

alter table employee_framework_skill
  add constraint employee_framework_skill_CK1 check (skill_level between 1 and 10);

alter table employee_infrastructure_skill
  add constraint employee_infrastructure_skill_CK1 check (skill_level between 1 and 10);

alter table employee_programming_skill
  add constraint employee_programming_skill_CK1 check (skill_level between 1 and 10);

-- 期間検索の性能劣化を防ぐための業務インデックス。
create index company_assignment_IDX1
  on company_assignment (employee_id, company_assignment_end_date, company_assignment_date);

create index assigned_department_IDX1
  on assigned_department (employee_id, assigned_department_end_date, assigned_department_date);

create index assigned_division_IDX1
  on assigned_division (employee_id, assigned_division_end_date, assigned_division_date);

create index assigned_team_IDX1
  on assigned_team (employee_id, assigned_team_end_date, assigned_team_date);

create index assignment_project_IDX1
  on assignment_project (employee_id, assignment_project_end_date, assignment_project_date);

create index assumption_of_position_IDX1
  on assumption_of_position (employee_id, assumption_of_position_end_date, assumption_of_position_date);


