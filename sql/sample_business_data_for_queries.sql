/*
  目的:
    ビジネス向け分析SQLを試せるように、不足している業務系テーブルへサンプルデータを補完する。

  方針:
    - 既存データを壊さないよう INSERT ... SELECT ... WHERE NOT EXISTS を使う。
    - 主に空テーブルだった「組織」「案件」「評価」「イベント」に投入する。
*/

-- 役職マスタ
INSERT INTO employee.position (position_code, position_name)
SELECT 'POS-MGR', 'Manager'
WHERE NOT EXISTS (SELECT 1 FROM employee.position WHERE position_code = 'POS-MGR');

INSERT INTO employee.position (position_code, position_name)
SELECT 'POS-LDR', 'Team Leader'
WHERE NOT EXISTS (SELECT 1 FROM employee.position WHERE position_code = 'POS-LDR');

INSERT INTO employee.position (position_code, position_name)
SELECT 'POS-ENG', 'Engineer'
WHERE NOT EXISTS (SELECT 1 FROM employee.position WHERE position_code = 'POS-ENG');

-- 取引先マスタ
INSERT INTO employee.business_partner (business_partner_code, business_partner_name)
SELECT 'BP001', 'Acme Holdings'
WHERE NOT EXISTS (SELECT 1 FROM employee.business_partner WHERE business_partner_code = 'BP001');

INSERT INTO employee.business_partner (business_partner_code, business_partner_name)
SELECT 'BP002', 'Globex Japan'
WHERE NOT EXISTS (SELECT 1 FROM employee.business_partner WHERE business_partner_code = 'BP002');

INSERT INTO employee.business_partner (business_partner_code, business_partner_name)
SELECT 'BP003', 'Innotech Systems'
WHERE NOT EXISTS (SELECT 1 FROM employee.business_partner WHERE business_partner_code = 'BP003');

-- 部署・課・チーム
INSERT INTO employee.department (company_id, department_code, department_name)
SELECT 1, 'D001', 'Engineering'
WHERE NOT EXISTS (SELECT 1 FROM employee.department WHERE department_code = 'D001');

INSERT INTO employee.department (company_id, department_code, department_name)
SELECT 2, 'D002', 'Product'
WHERE NOT EXISTS (SELECT 1 FROM employee.department WHERE department_code = 'D002');

INSERT INTO employee.department (company_id, department_code, department_name)
SELECT 3, 'D003', 'Platform'
WHERE NOT EXISTS (SELECT 1 FROM employee.department WHERE department_code = 'D003');

INSERT INTO employee.division (department_id, division_code, division_name, business_partner_id)
SELECT d.department_id, 'DV001', 'Backend Division', bp.business_partner_id
FROM employee.department d
CROSS JOIN employee.business_partner bp
WHERE d.department_code = 'D001'
  AND bp.business_partner_code = 'BP001'
  AND NOT EXISTS (SELECT 1 FROM employee.division WHERE division_code = 'DV001');

INSERT INTO employee.division (department_id, division_code, division_name, business_partner_id)
SELECT d.department_id, 'DV002', 'Frontend Division', bp.business_partner_id
FROM employee.department d
CROSS JOIN employee.business_partner bp
WHERE d.department_code = 'D002'
  AND bp.business_partner_code = 'BP002'
  AND NOT EXISTS (SELECT 1 FROM employee.division WHERE division_code = 'DV002');

INSERT INTO employee.division (department_id, division_code, division_name, business_partner_id)
SELECT d.department_id, 'DV003', 'Data Division', bp.business_partner_id
FROM employee.department d
CROSS JOIN employee.business_partner bp
WHERE d.department_code = 'D003'
  AND bp.business_partner_code = 'BP003'
  AND NOT EXISTS (SELECT 1 FROM employee.division WHERE division_code = 'DV003');

INSERT INTO employee.team (division_id, team_code, team_name)
SELECT v.division_id, 'TM001', 'Core API Team'
FROM employee.division v
WHERE v.division_code = 'DV001'
  AND NOT EXISTS (SELECT 1 FROM employee.team WHERE team_code = 'TM001');

INSERT INTO employee.team (division_id, team_code, team_name)
SELECT v.division_id, 'TM002', 'Web UI Team'
FROM employee.division v
WHERE v.division_code = 'DV002'
  AND NOT EXISTS (SELECT 1 FROM employee.team WHERE team_code = 'TM002');

INSERT INTO employee.team (division_id, team_code, team_name)
SELECT v.division_id, 'TM003', 'Data Platform Team'
FROM employee.division v
WHERE v.division_code = 'DV003'
  AND NOT EXISTS (SELECT 1 FROM employee.team WHERE team_code = 'TM003');

-- 社員の所属（現役中心）
INSERT INTO employee.belonging_department (department_id, employee_id)
SELECT d.department_id, 1
FROM employee.department d
WHERE d.department_code = 'D001'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_department bd
    WHERE bd.employee_id = 1 AND bd.department_id = d.department_id
  );

INSERT INTO employee.belonging_department (department_id, employee_id)
SELECT d.department_id, 2
FROM employee.department d
WHERE d.department_code = 'D002'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_department bd
    WHERE bd.employee_id = 2 AND bd.department_id = d.department_id
  );

INSERT INTO employee.belonging_department (department_id, employee_id)
SELECT d.department_id, 4
FROM employee.department d
WHERE d.department_code = 'D001'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_department bd
    WHERE bd.employee_id = 4 AND bd.department_id = d.department_id
  );

INSERT INTO employee.belonging_department (department_id, employee_id)
SELECT d.department_id, 6
FROM employee.department d
WHERE d.department_code = 'D003'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_department bd
    WHERE bd.employee_id = 6 AND bd.department_id = d.department_id
  );

INSERT INTO employee.belonging_division (division_id, employee_id)
SELECT v.division_id, 1
FROM employee.division v
WHERE v.division_code = 'DV001'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_division bd
    WHERE bd.employee_id = 1 AND bd.division_id = v.division_id
  );

INSERT INTO employee.belonging_division (division_id, employee_id)
SELECT v.division_id, 2
FROM employee.division v
WHERE v.division_code = 'DV002'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_division bd
    WHERE bd.employee_id = 2 AND bd.division_id = v.division_id
  );

INSERT INTO employee.belonging_division (division_id, employee_id)
SELECT v.division_id, 4
FROM employee.division v
WHERE v.division_code = 'DV001'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_division bd
    WHERE bd.employee_id = 4 AND bd.division_id = v.division_id
  );

INSERT INTO employee.belonging_division (division_id, employee_id)
SELECT v.division_id, 6
FROM employee.division v
WHERE v.division_code = 'DV003'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_division bd
    WHERE bd.employee_id = 6 AND bd.division_id = v.division_id
  );

INSERT INTO employee.belonging_team (employee_id, team_id)
SELECT 1, t.team_id
FROM employee.team t
WHERE t.team_code = 'TM001'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_team bt
    WHERE bt.employee_id = 1 AND bt.team_id = t.team_id
  );

INSERT INTO employee.belonging_team (employee_id, team_id)
SELECT 2, t.team_id
FROM employee.team t
WHERE t.team_code = 'TM002'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_team bt
    WHERE bt.employee_id = 2 AND bt.team_id = t.team_id
  );

INSERT INTO employee.belonging_team (employee_id, team_id)
SELECT 4, t.team_id
FROM employee.team t
WHERE t.team_code = 'TM001'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_team bt
    WHERE bt.employee_id = 4 AND bt.team_id = t.team_id
  );

INSERT INTO employee.belonging_team (employee_id, team_id)
SELECT 6, t.team_id
FROM employee.team t
WHERE t.team_code = 'TM003'
  AND NOT EXISTS (
    SELECT 1 FROM employee.belonging_team bt
    WHERE bt.employee_id = 6 AND bt.team_id = t.team_id
  );

-- 現役職
INSERT INTO employee.current_position (position_id, employee_id)
SELECT p.position_id, 1
FROM employee.position p
WHERE p.position_code = 'POS-MGR'
  AND NOT EXISTS (SELECT 1 FROM employee.current_position cp WHERE cp.employee_id = 1);

INSERT INTO employee.current_position (position_id, employee_id)
SELECT p.position_id, 2
FROM employee.position p
WHERE p.position_code = 'POS-LDR'
  AND NOT EXISTS (SELECT 1 FROM employee.current_position cp WHERE cp.employee_id = 2);

INSERT INTO employee.current_position (position_id, employee_id)
SELECT p.position_id, 4
FROM employee.position p
WHERE p.position_code = 'POS-ENG'
  AND NOT EXISTS (SELECT 1 FROM employee.current_position cp WHERE cp.employee_id = 4);

INSERT INTO employee.current_position (position_id, employee_id)
SELECT p.position_id, 6
FROM employee.position p
WHERE p.position_code = 'POS-ENG'
  AND NOT EXISTS (SELECT 1 FROM employee.current_position cp WHERE cp.employee_id = 6);

-- 案件
INSERT INTO employee.project (project_code, project_start_date, project_content, business_partner_id)
SELECT 'PRJ-API-001', DATE '2024-04-01', 'Core API modernization', bp.business_partner_id
FROM employee.business_partner bp
WHERE bp.business_partner_code = 'BP001'
  AND NOT EXISTS (SELECT 1 FROM employee.project p WHERE p.project_code = 'PRJ-API-001');

INSERT INTO employee.project (project_code, project_start_date, project_content, business_partner_id)
SELECT 'PRJ-WEB-002', DATE '2024-07-01', 'Customer portal redesign', bp.business_partner_id
FROM employee.business_partner bp
WHERE bp.business_partner_code = 'BP002'
  AND NOT EXISTS (SELECT 1 FROM employee.project p WHERE p.project_code = 'PRJ-WEB-002');

INSERT INTO employee.project (project_code, project_start_date, project_content, business_partner_id)
SELECT 'PRJ-DATA-003', DATE '2025-01-15', 'Analytics data mart build', bp.business_partner_id
FROM employee.business_partner bp
WHERE bp.business_partner_code = 'BP003'
  AND NOT EXISTS (SELECT 1 FROM employee.project p WHERE p.project_code = 'PRJ-DATA-003');

-- 案件所属 / 配属
INSERT INTO employee.belonging_project (project_id, employee_id)
SELECT p.project_id, 1
FROM employee.project p
WHERE p.project_code = 'PRJ-API-001'
  AND NOT EXISTS (SELECT 1 FROM employee.belonging_project bp WHERE bp.employee_id = 1 AND bp.project_id = p.project_id);

INSERT INTO employee.belonging_project (project_id, employee_id)
SELECT p.project_id, 4
FROM employee.project p
WHERE p.project_code = 'PRJ-API-001'
  AND NOT EXISTS (SELECT 1 FROM employee.belonging_project bp WHERE bp.employee_id = 4 AND bp.project_id = p.project_id);

INSERT INTO employee.belonging_project (project_id, employee_id)
SELECT p.project_id, 2
FROM employee.project p
WHERE p.project_code = 'PRJ-WEB-002'
  AND NOT EXISTS (SELECT 1 FROM employee.belonging_project bp WHERE bp.employee_id = 2 AND bp.project_id = p.project_id);

INSERT INTO employee.belonging_project (project_id, employee_id)
SELECT p.project_id, 6
FROM employee.project p
WHERE p.project_code = 'PRJ-DATA-003'
  AND NOT EXISTS (SELECT 1 FROM employee.belonging_project bp WHERE bp.employee_id = 6 AND bp.project_id = p.project_id);

INSERT INTO employee.assignment_project (assignment_project_date, project_id, employee_id)
SELECT DATE '2024-04-01', p.project_id, 1
FROM employee.project p
WHERE p.project_code = 'PRJ-API-001'
  AND NOT EXISTS (
    SELECT 1 FROM employee.assignment_project ap
    WHERE ap.employee_id = 1 AND ap.project_id = p.project_id
  );

INSERT INTO employee.assignment_project (assignment_project_date, project_id, employee_id)
SELECT DATE '2024-05-15', p.project_id, 4
FROM employee.project p
WHERE p.project_code = 'PRJ-API-001'
  AND NOT EXISTS (
    SELECT 1 FROM employee.assignment_project ap
    WHERE ap.employee_id = 4 AND ap.project_id = p.project_id
  );

INSERT INTO employee.assignment_project (assignment_project_date, project_id, employee_id)
SELECT DATE '2024-07-01', p.project_id, 2
FROM employee.project p
WHERE p.project_code = 'PRJ-WEB-002'
  AND NOT EXISTS (
    SELECT 1 FROM employee.assignment_project ap
    WHERE ap.employee_id = 2 AND ap.project_id = p.project_id
  );

INSERT INTO employee.assignment_project (assignment_project_date, project_id, employee_id)
SELECT DATE '2025-01-15', p.project_id, 6
FROM employee.project p
WHERE p.project_code = 'PRJ-DATA-003'
  AND NOT EXISTS (
    SELECT 1 FROM employee.assignment_project ap
    WHERE ap.employee_id = 6 AND ap.project_id = p.project_id
  );

-- 案件実績（離任済み）
INSERT INTO employee.employee_project_record (project_leaving_date, evaluation_point, reflection_point, project_id, employee_id)
SELECT DATE '2025-02-28', 'Delivered API milestone with stable performance.', 'Need stronger documentation cadence.', p.project_id, 4
FROM employee.project p
WHERE p.project_code = 'PRJ-API-001'
  AND NOT EXISTS (
    SELECT 1 FROM employee.employee_project_record r
    WHERE r.employee_id = 4 AND r.project_id = p.project_id
  );

-- 評価データ（四半期）
INSERT INTO employee.evaluation (year, quarter, comment, evaluation, employee_id)
SELECT 2025, 1, 'Solid delivery and mentorship.', 9, 1
WHERE NOT EXISTS (SELECT 1 FROM employee.evaluation e WHERE e.employee_id = 1 AND e.year = 2025 AND e.quarter = 1);

INSERT INTO employee.evaluation (year, quarter, comment, evaluation, employee_id)
SELECT 2025, 2, 'Delivery speed is good.', 8, 1
WHERE NOT EXISTS (SELECT 1 FROM employee.evaluation e WHERE e.employee_id = 1 AND e.year = 2025 AND e.quarter = 2);

INSERT INTO employee.evaluation (year, quarter, comment, evaluation, employee_id)
SELECT 2025, 1, 'UI quality improved significantly.', 8, 2
WHERE NOT EXISTS (SELECT 1 FROM employee.evaluation e WHERE e.employee_id = 2 AND e.year = 2025 AND e.quarter = 1);

INSERT INTO employee.evaluation (year, quarter, comment, evaluation, employee_id)
SELECT 2025, 2, 'Needs better test coverage discipline.', 7, 2
WHERE NOT EXISTS (SELECT 1 FROM employee.evaluation e WHERE e.employee_id = 2 AND e.year = 2025 AND e.quarter = 2);

INSERT INTO employee.evaluation (year, quarter, comment, evaluation, employee_id)
SELECT 2025, 2, 'Quick onboarding, still growing.', 6, 4
WHERE NOT EXISTS (SELECT 1 FROM employee.evaluation e WHERE e.employee_id = 4 AND e.year = 2025 AND e.quarter = 2);

INSERT INTO employee.evaluation (year, quarter, comment, evaluation, employee_id)
SELECT 2025, 2, 'Data pipeline quality is improving.', 7, 6
WHERE NOT EXISTS (SELECT 1 FROM employee.evaluation e WHERE e.employee_id = 6 AND e.year = 2025 AND e.quarter = 2);

-- ステータス系イベント
INSERT INTO employee.leave_of_absence (employee_id, leave_of_absence_date)
SELECT 3, DATE '2024-10-01'
WHERE NOT EXISTS (SELECT 1 FROM employee.leave_of_absence WHERE employee_id = 3);

INSERT INTO employee.reinstatement (employee_id, reinstatement_date)
SELECT 3, DATE '2025-03-01'
WHERE NOT EXISTS (SELECT 1 FROM employee.reinstatement WHERE employee_id = 3);

INSERT INTO employee.retirement (employee_id, retirement_reason, retirement_date)
SELECT 5, 'Personal career change', DATE '2024-12-31'
WHERE NOT EXISTS (SELECT 1 FROM employee.retirement WHERE employee_id = 5);

-- 案件完了
INSERT INTO employee.project_completion_report (project_completion_date, project_id)
SELECT DATE '2025-03-31', p.project_id
FROM employee.project p
WHERE p.project_code = 'PRJ-API-001'
  AND NOT EXISTS (SELECT 1 FROM employee.project_completion_report r WHERE r.project_id = p.project_id);
