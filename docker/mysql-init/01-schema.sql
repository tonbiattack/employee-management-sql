DROP DATABASE IF EXISTS employee;
CREATE DATABASE employee CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE employee;
SET FOREIGN_KEY_CHECKS = 0;
-- ========================================
-- SQLファイル: spring_boot_resources/schema.sql
-- 目的: このSQLの実行内容を明示するためのヘッダーコメント
-- 備考: 必要に応じて詳細な業務目的・前提条件を追記してください
-- ========================================




-- 現役社員連絡先
drop table if exists active_employee_contact_information;

create table active_employee_contact_information (
  active_employee_contact_information_id integer not null auto_increment
  , employee_contact_information_id integer not null
  , company_phone_number varchar(21) not null
  , company_email varchar(256) not null
  , constraint active_employee_contact_information_PKC primary key (active_employee_contact_information_id)
) ;

-- 配属部署
drop table if exists assigned_department;

create table assigned_department (
  assigned_department_id integer not null auto_increment
  , employee_id integer not null
  , department_id integer not null
  , assigned_department_date date not null
  , assigned_department_end_date date null
  , constraint assigned_department_PKC primary key (assigned_department_id)
  , constraint assigned_department_CK1 check (
      assigned_department_end_date is null
      or assigned_department_date <= assigned_department_end_date
    )
) ;

-- 配属課
drop table if exists assigned_division;

create table assigned_division (
  assigned_division_id integer not null auto_increment
  , division_id integer not null
  , employee_id integer not null
  , assigned_division_date date not null
  , assigned_division_end_date date null
  , constraint assigned_division_PKC primary key (assigned_division_id)
  , constraint assigned_division_CK1 check (
      assigned_division_end_date is null
      or assigned_division_date <= assigned_division_end_date
    )
) ;

-- 配属チーム
drop table if exists assigned_team;

create table assigned_team (
  assigned_team_id integer not null auto_increment
  , employee_id integer not null
  , team_id integer not null
  , assigned_team_date date not null
  , assigned_team_end_date date null
  , constraint assigned_team_PKC primary key (assigned_team_id)
  , constraint assigned_team_CK1 check (
      assigned_team_end_date is null
      or assigned_team_date <= assigned_team_end_date
    )
) ;

-- 配属案件
drop table if exists assignment_project;

create table assignment_project (
  assignment_project_id integer not null auto_increment
  , assignment_project_date date not null
  , assignment_project_end_date date null
  , project_id integer not null
  , employee_id integer not null
  , constraint assignment_project_PKC primary key (assignment_project_id)
  , constraint assignment_project_CK1 check (
      assignment_project_end_date is null
      or assignment_project_date <= assignment_project_end_date
    )
) ;

-- 役職就任
drop table if exists assumption_of_position;

create table assumption_of_position (
  assumption_of_position_id integer not null auto_increment
  , position_id integer not null
  , employee_id integer not null
  , assumption_of_position_date date not null
  , assumption_of_position_end_date date null
  , constraint assumption_of_position_PKC primary key (assumption_of_position_id)
  , constraint assumption_of_position_CK1 check (
      assumption_of_position_end_date is null
      or assumption_of_position_date <= assumption_of_position_end_date
    )
) ;

-- 所属会社
drop table if exists belonging_company;

create table belonging_company (
  belonging_company_id integer not null auto_increment
  , company_id integer not null
  , employee_id integer not null
  , constraint belonging_company_PKC primary key (belonging_company_id)
) ;

-- 所属部署
drop table if exists belonging_department;

create table belonging_department (
  belonging_department_id integer not null auto_increment
  , department_id integer not null
  , employee_id integer not null
  , constraint belonging_department_PKC primary key (belonging_department_id)
) ;

-- 所属課
drop table if exists belonging_division;

create table belonging_division (
  belonging_division_id integer not null auto_increment
  , division_id integer not null
  , employee_id integer not null
  , constraint belonging_division_PKC primary key (belonging_division_id)
) ;

-- 所属案件
drop table if exists belonging_project;

create table belonging_project (
  belonging_project_id integer not null auto_increment
  , project_id integer not null
  , employee_id integer not null
  , constraint belonging_project_PKC primary key (belonging_project_id)
) ;

-- 所属チーム
drop table if exists belonging_team;

create table belonging_team (
  belonging_team_id integer not null auto_increment
  , employee_id integer not null
  , team_id integer not null
  , constraint belonging_team_PKC primary key (belonging_team_id)
) ;

-- 会社配属
drop table if exists company_assignment;

create table company_assignment (
  company_assignment_id integer not null auto_increment
  , company_id integer not null
  , employee_id integer not null
  , company_assignment_date date not null
  , company_assignment_end_date date null
  , constraint company_assignment_PKC primary key (company_assignment_id)
  , constraint company_assignment_CK1 check (
      company_assignment_end_date is null
      or company_assignment_date <= company_assignment_end_date
    )
) ;

-- 休職社員連絡先
drop table if exists contact_information_for_staff_on_leave;

create table contact_information_for_staff_on_leave (
  contact_information_for_staff_on_leave_id integer not null auto_increment
  , employee_contact_information_id integer not null
  , company_email varchar(256) not null
  , constraint contact_information_for_staff_on_leave_PKC primary key (contact_information_for_staff_on_leave_id)
) ;

-- 現役職
drop table if exists current_position;

create table current_position (
  current_position_id integer not null auto_increment
  , position_id integer not null
  , employee_id integer not null
  , constraint current_position_PKC primary key (current_position_id)
) ;

-- 社員住所
drop table if exists employee_address;

create table employee_address (
  employee_address_id integer not null auto_increment
  , employee_id integer not null
  , post_code character(8) not null
  , address varchar(161) not null
  , constraint employee_address_PKC primary key (employee_address_id)
) ;

-- 社員データベーススキル
drop table if exists employee_database_skill;

create table employee_database_skill (
  employee_database_skill_id integer not null auto_increment
  , database_skill_id integer not null
  , skill_level integer not null
  , employee_id integer not null
  , constraint employee_database_skill_PKC primary key (employee_database_skill_id)
) ;

-- 社員フレームワークスキル
drop table if exists employee_framework_skill;

create table employee_framework_skill (
  employee_framework_skill_id integer not null auto_increment
  , framework_skill_id integer not null
  , skill_level integer not null
  , employee_id integer not null
  , constraint employee_framework_skill_PKC primary key (employee_framework_skill_id)
) ;

-- 社員インフラスキル
drop table if exists employee_infrastructure_skill;

create table employee_infrastructure_skill (
  employee_infrastructure_skill_id integer not null auto_increment
  , infrastructure_skill_id integer not null
  , skill_level integer not null
  , employee_id integer not null
  , constraint employee_infrastructure_skill_PKC primary key (employee_infrastructure_skill_id)
) ;

-- 社員プログラミングスキル
drop table if exists employee_programming_skill;

create table employee_programming_skill (
  employee_programming_skill_id integer not null auto_increment
  , programming_skill_id integer not null
  , skill_level integer not null
  , employee_id integer not null
  , constraint employee_programming_skill_PKC primary key (employee_programming_skill_id)
) ;

-- 社員案件実績
drop table if exists employee_project_record;

create table employee_project_record (
  employee_project_record_id integer not null auto_increment
  , project_leaving_date date not null
  , evaluation_point text not null
  , reflection_point text not null
  , project_id integer not null
  , employee_id integer not null
  , constraint employee_project_record_PKC primary key (employee_project_record_id)
) ;

-- 評価
drop table if exists evaluation;

create table evaluation (
  evaluation_id integer not null auto_increment
  , `year` integer not null
  , `quarter` integer not null
  , `comment` text not null
  , evaluation integer not null
  , employee_id integer not null
  , constraint evaluation_PKC primary key (evaluation_id)
) ;

-- フレームワークスキル
drop table if exists framework_skill;

create table framework_skill (
  framework_skill_id integer not null auto_increment
  , framework_skill_name varchar(20) not null
  , constraint framework_skill_PKC primary key (framework_skill_id)
) ;

-- インフラスキル
drop table if exists infrastructure_skill;

create table infrastructure_skill (
  infrastructure_skill_id integer not null auto_increment
  , infrastructure_skill_name varchar(20) not null
  , constraint infrastructure_skill_PKC primary key (infrastructure_skill_id)
) ;

-- 入社
drop table if exists joining_the_company;

create table joining_the_company (
  joining_the_company_id integer not null auto_increment
  , employee_id integer not null
  , joining_the_company_date date not null
  , constraint joining_the_company_PKC primary key (joining_the_company_id)
) ;

-- 休職
drop table if exists leave_of_absence;

create table leave_of_absence (
  leave_of_absence_id integer not null auto_increment
  , employee_id integer not null
  , leave_of_absence_date date not null
  , constraint leave_of_absence_PKC primary key (leave_of_absence_id)
) ;

-- 役職
drop table if exists `position`;

create table `position` (
  position_id integer not null auto_increment
  , position_code varchar(20) not null
  , position_name varchar(50) not null
  , constraint position_PKC primary key (position_id)
) ;

-- プログラミングスキル
drop table if exists programming_skill;

create table programming_skill (
  programming_skill_id integer not null auto_increment
  , programming_skill_name varchar(20) not null
  , constraint programming_skill_PKC primary key (programming_skill_id)
) ;

-- 案件完了報告
drop table if exists project_completion_report;

create table project_completion_report (
  project_completion_report_id integer not null auto_increment
  , project_completion_date date not null
  , project_id integer not null
  , constraint project_completion_report_PKC primary key (project_completion_report_id)
) ;

-- 復職
drop table if exists reinstatement;

create table reinstatement (
  reinstatement_id integer not null auto_increment
  , employee_id integer not null
  , reinstatement_date date not null
  , constraint reinstatement_PKC primary key (reinstatement_id)
) ;

-- 退職社員
drop table if exists retired_employee;

create table retired_employee (
  retired_employee_id integer not null auto_increment
  , employee_id integer not null
  , returning_permission boolean not null
  , constraint retired_employee_PKC primary key (retired_employee_id)
  , constraint retired_employee_UK1 unique (employee_id)
) ;

-- 退職社員連絡先
drop table if exists retired_employee_contact_information;

create table retired_employee_contact_information (
  retired_employee_contact_information_id integer not null auto_increment
  , employee_contact_information_id integer not null
  , constraint retired_employee_contact_information_PKC primary key (retired_employee_contact_information_id)
) ;

-- 退職
drop table if exists retirement;

create table retirement (
  retirement_id integer not null auto_increment
  , employee_id integer not null
  , retirement_reason text not null
  , retirement_date date not null
  , constraint retirement_PKC primary key (retirement_id)
) ;

-- 権限
drop table if exists `role`;

create table `role` (
  role_id integer not null auto_increment
  , role_name varchar(50) not null
  , constraint role_PKC primary key (role_id)
) ;

-- チーム
drop table if exists team;

create table team (
  team_id integer not null auto_increment
  , division_id integer not null
  , team_code varchar(30) not null
  , team_name varchar(70) not null
  , constraint team_PKC primary key (team_id)
) ;

-- データベーススキル
drop table if exists database_skill;

create table database_skill (
  database_skill_id integer not null auto_increment
  , database_skill_name varchar(20) not null
  , constraint database_skill_PKC primary key (database_skill_id)
) ;

-- 課
drop table if exists division;

create table division (
  division_id integer not null auto_increment
  , department_id integer not null
  , division_code varchar(20) not null
  , division_name varchar(50) not null
  , business_partner_id integer not null
  , constraint division_PKC primary key (division_id)
) ;

-- 社員連絡先
drop table if exists employee_contact_information;

create table employee_contact_information (
  employee_contact_information_id integer not null auto_increment
  , employee_id integer not null
  , private_phone_number varchar(21) not null
  , private_email varchar(254) not null
  , constraint employee_contact_information_PKC primary key (employee_contact_information_id)
) ;

-- パスワード
drop table if exists password;

create table password (
  password_id integer not null auto_increment
  , active_employee_contact_information_id integer not null
  , password text not null
  , constraint password_PKC primary key (password_id)
) ;

-- 所有権限
drop table if exists ownership;

create table ownership (
  ownership_id integer not null auto_increment
  , password_id integer not null
  , role_id integer not null
  , constraint ownership_PKC primary key (ownership_id)
) ;

-- 案件
drop table if exists project;

create table project (
  project_id integer not null auto_increment
  , project_code varchar(30) not null
  , project_start_date date not null
  , project_content text not null
  , business_partner_id integer not null
  , constraint project_PKC primary key (project_id)
) ;

-- 取引先企業
drop table if exists business_partner;

create table business_partner (
  business_partner_id integer not null auto_increment
  , business_partner_code varchar(20) not null
  , business_partner_name varchar(50) not null
  , constraint business_partner_PKC primary key (business_partner_id)
) ;

-- 部署
drop table if exists department;

create table department (
  department_id integer not null auto_increment
  , company_id integer not null
  , department_code varchar(20) not null
  , department_name varchar(50) not null
  , constraint department_PKC primary key (department_id)
) ;

-- 社員
drop table if exists employee;

create table employee (
  employee_id integer not null auto_increment
  , gender_id integer not null
  , employee_status_id integer not null
  , employee_code varchar(20) not null
  , family_name varchar(90) not null
  , last_name varchar(60) not null
  , family_name_furigana varchar(90) not null
  , last_name_furigana varchar(180) not null
  , date_of_birth date not null
  , grade integer not null
  , `comment` text not null
  , constraint employee_PKC primary key (employee_id)
) ;

-- 社員在籍区分
drop table if exists employee_status;

create table employee_status (
  employee_status_id integer not null auto_increment
  , employee_status_name varchar(20) not null
  , constraint employee_status_PKC primary key (employee_status_id)
) ;

-- 性別
drop table if exists gender;

create table gender (
  gender_id integer not null auto_increment
  , gender_code varchar(20) not null
  , gender_name varchar(20) not null
  , constraint gender_PKC primary key (gender_id)
) ;

-- 会社
drop table if exists company;

create table company (
  company_id integer not null auto_increment
  , company_code varchar(20) not null
  , company_name varchar(50) not null
  , company_business_content text not null
  , constraint company_PKC primary key (company_id)
) ;

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
  add constraint assignment_project_FK1 foreign key (employee_id) references employee(employee_id);

alter table assignment_project
  add constraint assignment_project_FK2 foreign key (project_id) references project(project_id);

alter table assumption_of_position
  add constraint assumption_of_position_FK1 foreign key (employee_id) references employee(employee_id);

alter table assumption_of_position
  add constraint assumption_of_position_FK2 foreign key (position_id) references `position`(position_id);

alter table belonging_company
  add constraint belonging_company_FK1 foreign key (employee_id) references employee(employee_id);

alter table belonging_department
  add constraint belonging_department_FK1 foreign key (department_id) references department(department_id);

alter table belonging_department
  add constraint belonging_department_FK2 foreign key (employee_id) references employee(employee_id);

alter table belonging_division
  add constraint belonging_division_FK1 foreign key (division_id) references division(division_id);

alter table belonging_division
  add constraint belonging_division_FK2 foreign key (employee_id) references employee(employee_id);

alter table belonging_project
  add constraint belonging_project_FK1 foreign key (project_id) references project(project_id);

alter table belonging_project
  add constraint belonging_project_FK2 foreign key (employee_id) references employee(employee_id);

alter table belonging_team
  add constraint belonging_team_FK1 foreign key (team_id) references team(team_id);

alter table belonging_team
  add constraint belonging_team_FK2 foreign key (employee_id) references employee(employee_id);

alter table company_assignment
  add constraint company_assignment_FK1 foreign key (company_id) references company(company_id);

alter table company_assignment
  add constraint company_assignment_FK2 foreign key (employee_id) references employee(employee_id);

alter table contact_information_for_staff_on_leave
  add constraint contact_information_for_staff_on_leave_FK1 foreign key (employee_contact_information_id) references employee_contact_information(employee_contact_information_id);

alter table current_position
  add constraint current_position_FK1 foreign key (employee_id) references employee(employee_id);

alter table current_position
  add constraint current_position_FK2 foreign key (position_id) references `position`(position_id);

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
  add constraint employee_framework_skill_FK1 foreign key (framework_skill_id) references framework_skill(framework_skill_id);

alter table employee_framework_skill
  add constraint employee_framework_skill_FK2 foreign key (employee_id) references employee(employee_id);

alter table employee_infrastructure_skill
  add constraint employee_infrastructure_skill_FK1 foreign key (infrastructure_skill_id) references infrastructure_skill(infrastructure_skill_id);

alter table employee_infrastructure_skill
  add constraint employee_infrastructure_skill_FK2 foreign key (employee_id) references employee(employee_id);

alter table employee_programming_skill
  add constraint employee_programming_skill_FK1 foreign key (programming_skill_id) references programming_skill(programming_skill_id);

alter table employee_programming_skill
  add constraint employee_programming_skill_FK2 foreign key (employee_id) references employee(employee_id);

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

alter table ownership
  add constraint ownership_FK1 foreign key (role_id) references `role`(role_id);

alter table ownership
  add constraint ownership_FK2 foreign key (password_id) references password(password_id);

alter table password
  add constraint password_FK1 foreign key (active_employee_contact_information_id) references active_employee_contact_information(active_employee_contact_information_id);

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



































































































































































































































































SET FOREIGN_KEY_CHECKS = 1;
