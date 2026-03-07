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
  add constraint retired_employee_FK1 foreign key (retired_employee_id) references employee(employee_id);

alter table retired_employee
  add constraint retired_employee_FK2 foreign key (employee_id) references employee(employee_id);

alter table retired_employee_contact_information
  add constraint retired_employee_contact_information_FK1 foreign key (employee_contact_information_id) references employee_contact_information(employee_contact_information_id);

alter table retirement
  add constraint retirement_FK1 foreign key (employee_id) references employee(employee_id);

alter table role
  add constraint role_FK1 foreign key (password_id) references password(password_id);

alter table team
  add constraint team_FK1 foreign key (division_id) references division(division_id);



