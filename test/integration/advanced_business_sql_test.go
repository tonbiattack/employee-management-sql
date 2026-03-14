package integration_test

import (
	"database/sql"
	"testing"
	"time"
)

type duplicateOpenHistoryRow struct {
	EmployeeID      int
	EmployeeCode    string
	EmployeeName    string
	HistoryType     string
	OpenRecordCount int
	IssueCode       string
}

type orgDismantleImpactRow struct {
	OrganizationType        string
	OrganizationID          int
	OrganizationName        string
	AffectedEmployeeCount   int
	ActiveProjectMemberCount int
	HighSkillEmployeeCount  int
	ImpactRiskLevel         string
}

type positionStagnationRow struct {
	EmployeeID          int
	EmployeeCode        string
	EmployeeName        string
	PositionName        string
	StartDate           time.Time
	MonthsInPosition    int
	LatestEvaluation    sql.NullInt64
	AlertLevel          string
}

type leaveReturnFollowupRow struct {
	EmployeeID                int
	EmployeeCode              string
	EmployeeName              string
	ReinstatementDate         time.Time
	CurrentOrganizationCount  int
	CurrentProjectCount       int
	PostReturnEvaluationCount int
	IssueCode                 string
}

type projectAssignmentTimelineRow struct {
	ProjectID        int
	ProjectCode      string
	EmployeeID       int
	EmployeeCode     string
	EmployeeName     string
	StartDate        time.Time
	EndDate          sql.NullTime
	IsCurrent        int
}

type skillGrowthSnapshotRow struct {
	EmployeeID         int
	EmployeeCode       string
	EmployeeName       string
	TotalSkillCount    int
	HighSkillCount     int
	LatestEvaluation   sql.NullInt64
	EvaluationDiff     sql.NullInt64
	GrowthSignal       string
}

func TestDuplicateOpenHistoryAuditSQL(t *testing.T) {
	t.Run("重複する継続中履歴を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareDuplicateOpenHistoryFixture(t, db.SQL)
		query := loadSearchQuery(t, "duplicate_open_history_audit.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query duplicate open history audit: %v", err)
		}
		defer rows.Close()

		var actual []duplicateOpenHistoryRow
		for rows.Next() {
			var row duplicateOpenHistoryRow
			if err := rows.Scan(&row.EmployeeID, &row.EmployeeCode, &row.EmployeeName, &row.HistoryType, &row.OpenRecordCount, &row.IssueCode); err != nil {
				t.Fatalf("failed to scan duplicate open history row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating duplicate open history rows: %v", err)
		}

		assertDuplicateOpenHistoryRow(t, actual, 1, "56001", "田嶋研人", "TEAM", 2, "DUPLICATE_OPEN_HISTORY")
	})
}

func TestOrgDismantleImpactSummarySQL(t *testing.T) {
	t.Run("組織解体時の影響要約を返す", func(t *testing.T) {
			db := openMySQLForTransitionTest(t)
			fixture := prepareOrgDismantleImpactFixture(t, db.SQL)
			query := loadSearchQuery(t, "org_dismantle_impact_summary.sql")

			rows, err := db.SQL.Query(query)
			if err != nil {
				t.Fatalf("failed to query org dismantle impact summary: %v", err)
			}
			defer rows.Close()

			var actual []orgDismantleImpactRow
			for rows.Next() {
				var row orgDismantleImpactRow
				if err := rows.Scan(&row.OrganizationType, &row.OrganizationID, &row.OrganizationName, &row.AffectedEmployeeCount, &row.ActiveProjectMemberCount, &row.HighSkillEmployeeCount, &row.ImpactRiskLevel); err != nil {
					t.Fatalf("failed to scan org dismantle impact row: %v", err)
				}
				actual = append(actual, row)
			}
			if err := rows.Err(); err != nil {
				t.Fatalf("failed while iterating org dismantle impact rows: %v", err)
			}

			assertOrgDismantleImpactRow(t, actual, "TEAM", fixture.TeamID, fixture.TeamName, 2, 1, 2, "HIGH")
	})
}

func TestPositionStagnationAlertSQL(t *testing.T) {
	t.Run("役職停滞アラートを返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := preparePositionStagnationFixture(t, db.SQL)
		query := loadSearchQuery(t, "position_stagnation_alert.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query position stagnation alert: %v", err)
		}
		defer rows.Close()

		var actual []positionStagnationRow
		for rows.Next() {
			var row positionStagnationRow
			if err := rows.Scan(&row.EmployeeID, &row.EmployeeCode, &row.EmployeeName, &row.PositionName, &row.StartDate, &row.MonthsInPosition, &row.LatestEvaluation, &row.AlertLevel); err != nil {
				t.Fatalf("failed to scan position stagnation row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating position stagnation rows: %v", err)
		}

		assertPositionStagnationRow(t, actual, 1, "56001", "田嶋研人", fixture.PositionName, "2023-01-01", 24, sql.NullInt64{Int64: 4, Valid: true}, "HIGH")
	})
}

func TestLeaveReturnFollowupSummarySQL(t *testing.T) {
	t.Run("復職後フォローアップ課題を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareLeaveReturnFollowupFixture(t, db.SQL)
		query := loadSearchQuery(t, "leave_return_followup_summary.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query leave return followup summary: %v", err)
		}
		defer rows.Close()

		var actual []leaveReturnFollowupRow
		for rows.Next() {
			var row leaveReturnFollowupRow
			if err := rows.Scan(&row.EmployeeID, &row.EmployeeCode, &row.EmployeeName, &row.ReinstatementDate, &row.CurrentOrganizationCount, &row.CurrentProjectCount, &row.PostReturnEvaluationCount, &row.IssueCode); err != nil {
				t.Fatalf("failed to scan leave return followup row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating leave return followup rows: %v", err)
		}

		assertLeaveReturnFollowupRow(t, actual, 5, "57003", "河合陽子", "2028-01-15", 1, 0, 0, "POST_RETURN_PROJECT_MISSING")
		assertLeaveReturnFollowupRow(t, actual, 5, "57003", "河合陽子", "2028-01-15", 1, 0, 0, "POST_RETURN_EVALUATION_MISSING")
	})
}

func TestProjectAssignmentTimelineSQL(t *testing.T) {
	t.Run("案件配属タイムラインを返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareProjectAssignmentTimelineFixture(t, db.SQL)
		query := loadSearchQuery(t, "project_assignment_timeline.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query project assignment timeline: %v", err)
		}
		defer rows.Close()

		var actual []projectAssignmentTimelineRow
		for rows.Next() {
			var row projectAssignmentTimelineRow
			if err := rows.Scan(&row.ProjectID, &row.ProjectCode, &row.EmployeeID, &row.EmployeeCode, &row.EmployeeName, &row.StartDate, &row.EndDate, &row.IsCurrent); err != nil {
				t.Fatalf("failed to scan project assignment timeline row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating project assignment timeline rows: %v", err)
		}

		assertProjectAssignmentTimelineRow(t, actual, fixture.ProjectID, fixture.ProjectCode, 1, "56001", "田嶋研人", "2028-02-01", "2028-06-30", 0)
	})
}

func TestSkillGrowthSnapshotSQL(t *testing.T) {
	t.Run("スキル成長シグナルを返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareSkillGrowthSnapshotFixture(t, db.SQL)
		query := loadSearchQuery(t, "skill_growth_snapshot.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query skill growth snapshot: %v", err)
		}
		defer rows.Close()

		var actual []skillGrowthSnapshotRow
		for rows.Next() {
			var row skillGrowthSnapshotRow
			if err := rows.Scan(&row.EmployeeID, &row.EmployeeCode, &row.EmployeeName, &row.TotalSkillCount, &row.HighSkillCount, &row.LatestEvaluation, &row.EvaluationDiff, &row.GrowthSignal); err != nil {
				t.Fatalf("failed to scan skill growth snapshot row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating skill growth snapshot rows: %v", err)
		}

		assertSkillGrowthSnapshotRow(t, actual, 1, "56001", "田嶋研人", 8, 3, sql.NullInt64{Int64: 8, Valid: true}, sql.NullInt64{Int64: 2, Valid: true}, "GROWING")
	})
}

type orgImpactFixture struct {
	TeamID   int
	TeamName string
}

type positionFixture struct {
	PositionName string
}

func prepareDuplicateOpenHistoryFixture(t *testing.T, db *sql.Tx) {
	t.Helper()
	_, teamID := getOrCreateTwoTeamIDs(t, db)
	if _, err := db.Exec(`DELETE FROM employee.assigned_team WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup duplicate team history fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assigned_team(team_id, employee_id, assigned_team_date, assigned_team_end_date) VALUES (?, ?, ?, NULL)`, teamID, 1, "2028-01-01"); err != nil {
		t.Fatalf("failed to insert first duplicate open team history: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assigned_team(team_id, employee_id, assigned_team_date, assigned_team_end_date) VALUES (?, ?, ?, NULL)`, teamID, 1, "2028-02-01"); err != nil {
		t.Fatalf("failed to insert second duplicate open team history: %v", err)
	}
}

func prepareOrgDismantleImpactFixture(t *testing.T, db *sql.Tx) orgImpactFixture {
	t.Helper()
	sourceTeamID, _ := getOrCreateTwoTeamIDs(t, db)
	projectID := getOrCreateProjectID(t, db)
	if _, err := db.Exec(`DELETE FROM employee.belonging_team WHERE employee_id IN (1,2)`); err != nil {
		t.Fatalf("failed to cleanup org impact team belonging: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE employee_id IN (1,2)`); err != nil {
		t.Fatalf("failed to cleanup org impact project belonging: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE employee_id = ?`, 2); err != nil {
		t.Fatalf("failed to cleanup org impact project belonging: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.belonging_team(team_id, employee_id) VALUES (?, ?), (?, ?)`, sourceTeamID, 1, sourceTeamID, 2); err != nil {
		t.Fatalf("failed to setup org impact team belonging: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.belonging_project(project_id, employee_id) VALUES (?, ?)`, projectID, 1); err != nil {
		t.Fatalf("failed to setup org impact project belonging: %v", err)
	}
	return orgImpactFixture{TeamID: sourceTeamID, TeamName: getTeamName(t, db, sourceTeamID)}
}

func preparePositionStagnationFixture(t *testing.T, db *sql.Tx) positionFixture {
	t.Helper()
	positionID := insertPositionFixture(t, db, "POS-STAG-001", "Stagnation Position")
	if _, err := db.Exec(`DELETE FROM employee.current_position WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup current position for stagnation fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.assumption_of_position WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup position history for stagnation fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id = ? AND year IN (?, ?)`, 1, 2027, 2028); err != nil {
		t.Fatalf("failed to cleanup evaluations for stagnation fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.current_position(position_id, employee_id) VALUES (?, ?)`, positionID, 1); err != nil {
		t.Fatalf("failed to insert current position for stagnation fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assumption_of_position(position_id, employee_id, assumption_of_position_date, assumption_of_position_end_date) VALUES (?, ?, ?, NULL)`, positionID, 1, "2023-01-01"); err != nil {
		t.Fatalf("failed to insert position history for stagnation fixture: %v", err)
	}
	insertEvaluation(t, db, 1, 2027, 4, "stagnation baseline", 2)
	insertEvaluation(t, db, 1, 2028, 1, "stagnation latest", 4)
	return positionFixture{PositionName: "Stagnation Position"}
}

func prepareLeaveReturnFollowupFixture(t *testing.T, db *sql.Tx) {
	t.Helper()
	companyID := getOrCreateCompanyID(t, db)
	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 1 WHERE employee_id = ?`, 5); err != nil {
		t.Fatalf("failed to reset employee 5 to active for leave return fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.reinstatement WHERE employee_id = ?`, 5); err != nil {
		t.Fatalf("failed to cleanup reinstatement fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_company WHERE employee_id = ?`, 5); err != nil {
		t.Fatalf("failed to cleanup belonging company for leave return fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE employee_id = ?`, 5); err != nil {
		t.Fatalf("failed to cleanup belonging project for leave return fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id = ? AND year = ?`, 5, 2028); err != nil {
		t.Fatalf("failed to cleanup post return evaluations: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.reinstatement(employee_id, reinstatement_date) VALUES (?, ?)`, 5, "2028-01-15"); err != nil {
		t.Fatalf("failed to insert reinstatement fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.belonging_company(company_id, employee_id) VALUES (?, ?)`, companyID, 5); err != nil {
		t.Fatalf("failed to insert company belonging for leave return fixture: %v", err)
	}
}

type timelineFixture struct {
	ProjectID   int
	ProjectCode string
}

func prepareProjectAssignmentTimelineFixture(t *testing.T, db *sql.Tx) timelineFixture {
	t.Helper()
	bpID := getOrCreateBusinessPartnerID(t, db)
	projectID := insertProjectFixture(t, db, bpID, "PRJ-TIME-001", "Timeline Project", "2028-02-01")
	if _, err := db.Exec(`DELETE FROM employee.assignment_project WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup project assignment timeline fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup current project belonging for timeline fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, assignment_project_end_date, project_id, employee_id) VALUES (?, ?, ?, ?)`, "2028-02-01", "2028-06-30", projectID, 1); err != nil {
		t.Fatalf("failed to insert closed project timeline row: %v", err)
	}
	return timelineFixture{ProjectID: projectID, ProjectCode: "PRJ-TIME-001"}
}

func prepareSkillGrowthSnapshotFixture(t *testing.T, db *sql.Tx) {
	t.Helper()
	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id = ? AND year IN (?, ?)`, 1, 2029, 2030); err != nil {
		t.Fatalf("failed to cleanup skill growth evaluations: %v", err)
	}
	insertEvaluation(t, db, 1, 2029, 4, "growth base", 6)
	insertEvaluation(t, db, 1, 2030, 1, "growth latest", 8)
}

func getTeamName(t *testing.T, db *sql.Tx, teamID int) string {
	t.Helper()
	var name string
	if err := db.QueryRow(`SELECT team_name FROM employee.team WHERE team_id = ?`, teamID).Scan(&name); err != nil {
		t.Fatalf("failed to get team name: %v", err)
	}
	return name
}

func assertDuplicateOpenHistoryRow(t *testing.T, actual []duplicateOpenHistoryRow, employeeID int, employeeCode, employeeName, historyType string, count int, issue string) {
	t.Helper()
	for _, row := range actual {
		if row.EmployeeID == employeeID && row.EmployeeCode == employeeCode && row.EmployeeName == employeeName && row.HistoryType == historyType && row.OpenRecordCount == count && row.IssueCode == issue {
			return
		}
	}
	t.Fatalf("expected duplicate open history row not found: employee_id=%d", employeeID)
}

func assertOrgDismantleImpactRow(t *testing.T, actual []orgDismantleImpactRow, orgType string, orgID int, orgName string, affected, projectMembers, highSkill int, risk string) {
	t.Helper()
	for _, row := range actual {
		if row.OrganizationType == orgType && row.OrganizationID == orgID && row.OrganizationName == orgName && row.AffectedEmployeeCount == affected && row.ActiveProjectMemberCount == projectMembers && row.HighSkillEmployeeCount == highSkill && row.ImpactRiskLevel == risk {
			return
		}
	}
	t.Fatalf("expected org dismantle impact row not found: organization_id=%d", orgID)
}

func assertPositionStagnationRow(t *testing.T, actual []positionStagnationRow, employeeID int, employeeCode, employeeName, positionName, startDate string, months int, latestEvaluation sql.NullInt64, alert string) {
	t.Helper()
	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.PositionName == positionName &&
			row.StartDate.Format("2006-01-02") == startDate &&
			row.MonthsInPosition >= months &&
			row.LatestEvaluation == latestEvaluation &&
			row.AlertLevel == alert {
			return
		}
	}
	t.Fatalf("expected position stagnation row not found: employee_id=%d", employeeID)
}

func assertLeaveReturnFollowupRow(t *testing.T, actual []leaveReturnFollowupRow, employeeID int, employeeCode, employeeName, reinstatementDate string, orgCount, projectCount, evalCount int, issue string) {
	t.Helper()
	for _, row := range actual {
		if row.EmployeeID == employeeID && row.EmployeeCode == employeeCode && row.EmployeeName == employeeName && row.ReinstatementDate.Format("2006-01-02") == reinstatementDate && row.CurrentOrganizationCount == orgCount && row.CurrentProjectCount == projectCount && row.PostReturnEvaluationCount == evalCount && row.IssueCode == issue {
			return
		}
	}
	t.Fatalf("expected leave return followup row not found: employee_id=%d issue=%s", employeeID, issue)
}

func assertProjectAssignmentTimelineRow(t *testing.T, actual []projectAssignmentTimelineRow, projectID int, projectCode string, employeeID int, employeeCode, employeeName, startDate, endDate string, isCurrent int) {
	t.Helper()
	for _, row := range actual {
		if row.ProjectID == projectID && row.ProjectCode == projectCode && row.EmployeeID == employeeID && row.EmployeeCode == employeeCode && row.EmployeeName == employeeName && row.StartDate.Format("2006-01-02") == startDate && nullTimeValue(row.EndDate) == endDate && row.IsCurrent == isCurrent {
			return
		}
	}
	t.Fatalf("expected project assignment timeline row not found: project_id=%d employee_id=%d", projectID, employeeID)
}

func assertSkillGrowthSnapshotRow(t *testing.T, actual []skillGrowthSnapshotRow, employeeID int, employeeCode, employeeName string, totalSkills, highSkills int, latestEvaluation, evaluationDiff sql.NullInt64, signal string) {
	t.Helper()
	for _, row := range actual {
		if row.EmployeeID == employeeID && row.EmployeeCode == employeeCode && row.EmployeeName == employeeName && row.TotalSkillCount == totalSkills && row.HighSkillCount == highSkills && row.LatestEvaluation == latestEvaluation && row.EvaluationDiff == evaluationDiff && row.GrowthSignal == signal {
			return
		}
	}
	t.Fatalf("expected skill growth snapshot row not found: employee_id=%d", employeeID)
}

func nullTimeValue(v sql.NullTime) string {
	if !v.Valid {
		return ""
	}
	return v.Time.Format("2006-01-02")
}
