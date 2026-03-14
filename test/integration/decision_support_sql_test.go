package integration_test

import (
	"database/sql"
	"testing"
	"time"
)

type projectStaffingRecommendationRow struct {
	ProjectID                          int
	ProjectCode                        string
	EmployeeID                         int
	EmployeeCode                       string
	EmployeeName                       string
	AssignmentStatus                   string
	LatestEvaluation                   sql.NullInt64
	HighSkillCount                     int
	ProjectMissingSkillCategoryCount   int
	CandidateCoveredMissingCategoryCount int
	RecommendationScore                int
	RecommendationRank                 int
}

type evaluationDueAlertRow struct {
	EmployeeID       int
	EmployeeCode     string
	EmployeeName     string
	TargetYear       int
	TargetQuarter    int
	DueDate          time.Time
	OverdueDays      int
	DueStatus        string
	AlertIssueCode   string
}

type assignmentConflictRow struct {
	EmployeeID        int
	EmployeeCode      string
	EmployeeName      string
	ConflictProjectID sql.NullInt64
	ConflictCount     int
	IssueCode         string
}

type projectExitReadinessRow struct {
	ProjectID                int
	ProjectCode              string
	PlannedExitDate          time.Time
	EndedAssignmentCount     int
	CurrentBelongingCount    int
	ProjectRecordCount       int
	PendingExitMemberCount   int
	ReadinessStatus          string
}

type managerSpanRow struct {
	ManagerEmployeeID            int
	ManagerEmployeeCode          string
	ManagerEmployeeName          string
	PositionName                 string
	TeamID                       int
	TeamName                     string
	ManagedMemberCount           int
	HighRiskMemberCount          int
	EvaluationMissingMemberCount int
}

type skillMarketabilityRow struct {
	EmployeeID              int
	EmployeeCode            string
	EmployeeName            string
	SkillCategoryCount      int
	HighSkillCategoryCount  int
	TotalSkillCount         int
	LatestEvaluation        sql.NullInt64
	MarketabilityTier       string
}

func TestProjectStaffingRecommendationSQL(t *testing.T) {
	t.Run("案件向けの候補社員を順位付きで返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareProjectStaffingRecommendationFixture(t, db.SQL)
		query := loadSearchQuery(t, "project_staffing_recommendation.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query project staffing recommendation: %v", err)
		}
		defer rows.Close()

		var actual []projectStaffingRecommendationRow
		for rows.Next() {
			var row projectStaffingRecommendationRow
			if err := rows.Scan(
				&row.ProjectID,
				&row.ProjectCode,
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.AssignmentStatus,
				&row.LatestEvaluation,
				&row.HighSkillCount,
				&row.ProjectMissingSkillCategoryCount,
				&row.CandidateCoveredMissingCategoryCount,
				&row.RecommendationScore,
				&row.RecommendationRank,
			); err != nil {
				t.Fatalf("failed to scan project staffing recommendation row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating project staffing recommendation rows: %v", err)
		}

		assertProjectStaffingRecommendationRow(t, actual, fixture.ProjectID, fixture.ProjectCode, 1, "56001", "田嶋研人", "PROJECT_UNASSIGNED", 2, 2, 31, 1)
	})
}

func TestEvaluationDueAlertSQL(t *testing.T) {
	t.Run("評価締切超過の四半期を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareEvaluationDueAlertFixture(t, db.SQL)
		query := loadSearchQuery(t, "evaluation_due_alert.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query evaluation due alert: %v", err)
		}
		defer rows.Close()

		var actual []evaluationDueAlertRow
		for rows.Next() {
			var row evaluationDueAlertRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.TargetYear,
				&row.TargetQuarter,
				&row.DueDate,
				&row.OverdueDays,
				&row.DueStatus,
				&row.AlertIssueCode,
			); err != nil {
				t.Fatalf("failed to scan evaluation due alert row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating evaluation due alert rows: %v", err)
		}

		assertEvaluationDueAlertRow(t, actual, 1, "56001", "田嶋研人", 2024, 2, "2024-07-15", "OVERDUE", "EVALUATION_DUE_DELAY")
	})
}

func TestEmployeeAssignmentConflictAuditSQL(t *testing.T) {
	t.Run("案件配属の矛盾を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareEmployeeAssignmentConflictFixture(t, db.SQL)
		query := loadSearchQuery(t, "employee_assignment_conflict_audit.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query employee assignment conflict audit: %v", err)
		}
		defer rows.Close()

		var actual []assignmentConflictRow
		for rows.Next() {
			var row assignmentConflictRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.ConflictProjectID,
				&row.ConflictCount,
				&row.IssueCode,
			); err != nil {
				t.Fatalf("failed to scan assignment conflict row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating assignment conflict rows: %v", err)
		}

		assertAssignmentConflictRow(t, actual, 1, "56001", "田嶋研人", sql.NullInt64{}, 2, "MULTI_ACTIVE_PROJECT")
		assertAssignmentConflictRow(t, actual, 2, "11000", "中田あやか", sql.NullInt64{Int64: int64(fixture.ProjectWithoutHistoryID), Valid: true}, 1, "CURRENT_WITHOUT_OPEN_HISTORY")
		assertAssignmentConflictRow(t, actual, 3, "33000", "橘まゆみ", sql.NullInt64{Int64: int64(fixture.ProjectWithoutCurrentID), Valid: true}, 1, "OPEN_HISTORY_WITHOUT_CURRENT")
	})
}

func TestProjectExitReadinessSummarySQL(t *testing.T) {
	t.Run("完了前の離任準備状況を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareProjectExitReadinessFixture(t, db.SQL)
		query := loadSearchQuery(t, "project_exit_readiness_summary.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query project exit readiness summary: %v", err)
		}
		defer rows.Close()

		var actual []projectExitReadinessRow
		for rows.Next() {
			var row projectExitReadinessRow
			if err := rows.Scan(
				&row.ProjectID,
				&row.ProjectCode,
				&row.PlannedExitDate,
				&row.EndedAssignmentCount,
				&row.CurrentBelongingCount,
				&row.ProjectRecordCount,
				&row.PendingExitMemberCount,
				&row.ReadinessStatus,
			); err != nil {
				t.Fatalf("failed to scan project exit readiness row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating project exit readiness rows: %v", err)
		}

		assertProjectExitReadinessRow(t, actual, fixture.ProjectID, fixture.ProjectCode, "2028-06-30", 2, 1, 1, 1, "NOT_READY")
	})
}

func TestManagerSpanOfControlSummarySQL(t *testing.T) {
	t.Run("管理職ごとの担当人数とリスク件数を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareManagerSpanFixture(t, db.SQL)
		query := loadSearchQuery(t, "manager_span_of_control_summary.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query manager span of control summary: %v", err)
		}
		defer rows.Close()

		var actual []managerSpanRow
		for rows.Next() {
			var row managerSpanRow
			if err := rows.Scan(
				&row.ManagerEmployeeID,
				&row.ManagerEmployeeCode,
				&row.ManagerEmployeeName,
				&row.PositionName,
				&row.TeamID,
				&row.TeamName,
				&row.ManagedMemberCount,
				&row.HighRiskMemberCount,
				&row.EvaluationMissingMemberCount,
			); err != nil {
				t.Fatalf("failed to scan manager span row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating manager span rows: %v", err)
		}

		assertManagerSpanRow(t, actual, 1, "56001", "田嶋研人", fixture.PositionName, fixture.TeamID, fixture.TeamName, 2, 1, 1)
	})
}

func TestSkillMarketabilitySnapshotSQL(t *testing.T) {
	t.Run("スキル市場価値スナップショットを返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareSkillMarketabilityFixture(t, db.SQL)
		query := loadSearchQuery(t, "skill_marketability_snapshot.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query skill marketability snapshot: %v", err)
		}
		defer rows.Close()

		var actual []skillMarketabilityRow
		for rows.Next() {
			var row skillMarketabilityRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.SkillCategoryCount,
				&row.HighSkillCategoryCount,
				&row.TotalSkillCount,
				&row.LatestEvaluation,
				&row.MarketabilityTier,
			); err != nil {
				t.Fatalf("failed to scan skill marketability row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating skill marketability rows: %v", err)
		}

		assertSkillMarketabilityRow(t, actual, 1, "56001", "田嶋研人", 4, 3, 8, sql.NullInt64{Int64: 8, Valid: true}, "HIGH")
	})
}

type assignmentConflictFixture struct {
	ProjectWithoutHistoryID int
	ProjectWithoutCurrentID int
}

type projectExitReadinessFixture struct {
	ProjectID   int
	ProjectCode string
}

type managerSpanFixture struct {
	TeamID       int
	TeamName     string
	PositionName string
}

func prepareProjectStaffingRecommendationFixture(t *testing.T, db *sql.Tx) projectExitReadinessFixture {
	t.Helper()

	prepareRedeploymentFixture(t, db)

	projectID := insertProjectFixture(t, db, getOrCreateBusinessPartnerID(t, db), "PRJ-RECOMMEND-001", "Recommendation Project", "2028-01-01")
	if _, err := db.Exec(`DELETE FROM employee.assignment_project WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup staffing recommendation assignments: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup staffing recommendation belonging: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_database_skill WHERE employee_id = ?`, 4); err != nil {
		t.Fatalf("failed to cleanup employee 4 database skill for recommendation fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_framework_skill WHERE employee_id = ?`, 4); err != nil {
		t.Fatalf("failed to cleanup employee 4 framework skill for recommendation fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_infrastructure_skill WHERE employee_id = ?`, 4); err != nil {
		t.Fatalf("failed to cleanup employee 4 infrastructure skill for recommendation fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_programming_skill WHERE employee_id = ?`, 4); err != nil {
		t.Fatalf("failed to cleanup employee 4 programming skill for recommendation fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id IN (?, ?) AND year = ?`, 1, 2, 2028); err != nil {
		t.Fatalf("failed to cleanup staffing recommendation evaluations: %v", err)
	}
	insertEvaluation(t, db, 1, 2028, 1, "recommend high", 9)
	insertEvaluation(t, db, 2, 2028, 1, "recommend medium", 5)
	if _, err := db.Exec(`INSERT INTO employee.employee_framework_skill(framework_skill_id, skill_level, employee_id) VALUES (?, ?, ?)`, 4, 6, 4); err != nil {
		t.Fatalf("failed to insert employee 4 framework skill for recommendation fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.employee_programming_skill(programming_skill_id, skill_level, employee_id) VALUES (?, ?, ?)`, 10, 6, 4); err != nil {
		t.Fatalf("failed to insert employee 4 programming skill for recommendation fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, project_id, employee_id) VALUES (?, ?, ?)`, "2028-01-10", projectID, 4); err != nil {
		t.Fatalf("failed to insert existing project member for recommendation: %v", err)
	}

	return projectExitReadinessFixture{ProjectID: projectID, ProjectCode: "PRJ-RECOMMEND-001"}
}

func prepareEvaluationDueAlertFixture(t *testing.T, db *sql.Tx) {
	t.Helper()

	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 1 WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to reset employee 1 status for due alert: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id = ? AND year = ?`, 1, 2024); err != nil {
		t.Fatalf("failed to cleanup due alert evaluations: %v", err)
	}
	insertEvaluation(t, db, 1, 2024, 1, "due alert q1", 6)
	insertEvaluation(t, db, 1, 2024, 3, "due alert q3", 7)
}

func prepareEmployeeAssignmentConflictFixture(t *testing.T, db *sql.Tx) assignmentConflictFixture {
	t.Helper()

	bpID := getOrCreateBusinessPartnerID(t, db)
	projectMultiA := insertProjectFixture(t, db, bpID, "PRJ-CONFLICT-A", "Conflict Project A", "2028-01-01")
	projectMultiB := insertProjectFixture(t, db, bpID, "PRJ-CONFLICT-B", "Conflict Project B", "2028-01-01")
	projectWithoutHistoryID := insertProjectFixture(t, db, bpID, "PRJ-CONFLICT-C", "Conflict Project C", "2028-01-01")
	projectWithoutCurrentID := insertProjectFixture(t, db, bpID, "PRJ-CONFLICT-D", "Conflict Project D", "2028-01-01")

	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 1 WHERE employee_id IN (1,2,3)`); err != nil {
		t.Fatalf("failed to reset statuses for assignment conflict fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.assignment_project WHERE employee_id IN (1,2,3) AND project_id IN (?, ?, ?, ?)`, projectMultiA, projectMultiB, projectWithoutHistoryID, projectWithoutCurrentID); err != nil {
		t.Fatalf("failed to cleanup assignment history for conflict fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE employee_id IN (1,2,3) AND project_id IN (?, ?, ?, ?)`, projectMultiA, projectMultiB, projectWithoutHistoryID, projectWithoutCurrentID); err != nil {
		t.Fatalf("failed to cleanup current belonging for conflict fixture: %v", err)
	}

	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, project_id, employee_id) VALUES (?, ?, ?), (?, ?, ?)`,
		"2028-02-01", projectMultiA, 1,
		"2028-02-02", projectMultiB, 1,
	); err != nil {
		t.Fatalf("failed to insert multi active project history: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.belonging_project(project_id, employee_id) VALUES (?, ?), (?, ?)`,
		projectMultiA, 1,
		projectMultiB, 1,
	); err != nil {
		t.Fatalf("failed to insert multi active current belonging: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.belonging_project(project_id, employee_id) VALUES (?, ?)`, projectWithoutHistoryID, 2); err != nil {
		t.Fatalf("failed to insert current without history fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, project_id, employee_id) VALUES (?, ?, ?)`, "2028-03-01", projectWithoutCurrentID, 3); err != nil {
		t.Fatalf("failed to insert open history without current fixture: %v", err)
	}

	return assignmentConflictFixture{
		ProjectWithoutHistoryID: projectWithoutHistoryID,
		ProjectWithoutCurrentID: projectWithoutCurrentID,
	}
}

func prepareProjectExitReadinessFixture(t *testing.T, db *sql.Tx) projectExitReadinessFixture {
	t.Helper()

	bpID := getOrCreateBusinessPartnerID(t, db)
	projectID := insertProjectFixture(t, db, bpID, "PRJ-EXIT-001", "Exit Readiness Project", "2028-01-01")
	if _, err := db.Exec(`DELETE FROM employee.project_completion_report WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup completion report for exit readiness fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.assignment_project WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup assignment project for exit readiness fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup belonging project for exit readiness fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_project_record WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup project records for exit readiness fixture: %v", err)
	}

	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, assignment_project_end_date, project_id, employee_id) VALUES (?, ?, ?, ?), (?, ?, ?, ?)`,
		"2028-02-01", "2028-06-30", projectID, 1,
		"2028-02-10", "2028-06-30", projectID, 2,
	); err != nil {
		t.Fatalf("failed to insert ended assignments for exit readiness fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.belonging_project(project_id, employee_id) VALUES (?, ?)`, projectID, 1); err != nil {
		t.Fatalf("failed to insert current belonging for exit readiness fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.employee_project_record(project_leaving_date, project_id, employee_id, evaluation_point, reflection_point, record_type, recorded_by_employee_id, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		"2028-06-30", projectID, 1, "recorded", "reflection", "RETROSPECTIVE", 1, "2028-07-01 10:00:00",
	); err != nil {
		t.Fatalf("failed to insert project record for exit readiness fixture: %v", err)
	}

	return projectExitReadinessFixture{ProjectID: projectID, ProjectCode: "PRJ-EXIT-001"}
}

func prepareManagerSpanFixture(t *testing.T, db *sql.Tx) managerSpanFixture {
	t.Helper()

	teamID := insertTeamFixture(t, db, getOrCreateDivisionID(t, db), "TEAM-MGR-001", "Manager Span Team")
	teamName := "Manager Span Team"
	positionID := insertPositionFixture(t, db, "POS-MGR-001", "Engineering Manager")

	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 1 WHERE employee_id IN (1,2,3)`); err != nil {
		t.Fatalf("failed to reset statuses for manager span fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_team WHERE employee_id IN (1,2,3)`); err != nil {
		t.Fatalf("failed to cleanup belonging_team for manager span fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.current_position WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup current_position for manager span fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.assumption_of_position WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup assumption_of_position for manager span fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE employee_id IN (?, ?)` , 2, 3); err != nil {
		t.Fatalf("failed to cleanup projects for manager span fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id IN (?, ?) AND year = ?`, 2, 3, 2028); err != nil {
		t.Fatalf("failed to cleanup evaluations for manager span fixture: %v", err)
	}

	if _, err := db.Exec(`INSERT INTO employee.belonging_team(team_id, employee_id) VALUES (?, ?), (?, ?), (?, ?)`, teamID, 1, teamID, 2, teamID, 3); err != nil {
		t.Fatalf("failed to insert team members for manager span fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.current_position(position_id, employee_id) VALUES (?, ?)`, positionID, 1); err != nil {
		t.Fatalf("failed to insert current position for manager span fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assumption_of_position(position_id, employee_id, assumption_of_position_date, assumption_of_position_end_date) VALUES (?, ?, ?, NULL)`, positionID, 1, "2028-01-01"); err != nil {
		t.Fatalf("failed to insert position history for manager span fixture: %v", err)
	}
	insertEvaluation(t, db, 2, 2028, 1, "member risk", 4)
	if _, err := db.Exec(`INSERT INTO employee.belonging_project(project_id, employee_id) VALUES (?, ?)`, getOrCreateProjectID(t, db), 3); err != nil {
		t.Fatalf("failed to insert current project for manager span fixture: %v", err)
	}

	return managerSpanFixture{
		TeamID:       teamID,
		TeamName:     teamName,
		PositionName: "Engineering Manager",
	}
}

func prepareSkillMarketabilityFixture(t *testing.T, db *sql.Tx) {
	t.Helper()
	prepareSkillGrowthSnapshotFixture(t, db)
	if _, err := db.Exec(`DELETE FROM employee.employee_database_skill WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup employee 1 database skills for marketability fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_framework_skill WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup employee 1 framework skills for marketability fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_infrastructure_skill WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup employee 1 infrastructure skills for marketability fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_programming_skill WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup employee 1 programming skills for marketability fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.employee_database_skill(database_skill_id, skill_level, employee_id) VALUES (?, ?, ?), (?, ?, ?)`,
		3, 9, 1,
		4, 5, 1,
	); err != nil {
		t.Fatalf("failed to insert employee 1 database skills for marketability fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.employee_framework_skill(framework_skill_id, skill_level, employee_id) VALUES (?, ?, ?), (?, ?, ?)`,
		4, 5, 1,
		3, 5, 1,
	); err != nil {
		t.Fatalf("failed to insert employee 1 framework skills for marketability fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.employee_infrastructure_skill(infrastructure_skill_id, skill_level, employee_id) VALUES (?, ?, ?), (?, ?, ?)`,
		4, 8, 1,
		3, 6, 1,
	); err != nil {
		t.Fatalf("failed to insert employee 1 infrastructure skills for marketability fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.employee_programming_skill(programming_skill_id, skill_level, employee_id) VALUES (?, ?, ?), (?, ?, ?)`,
		4, 8, 1,
		3, 5, 1,
	); err != nil {
		t.Fatalf("failed to insert employee 1 programming skills for marketability fixture: %v", err)
	}
}

func assertProjectStaffingRecommendationRow(t *testing.T, actual []projectStaffingRecommendationRow, projectID int, projectCode string, employeeID int, employeeCode, employeeName, assignmentStatus string, missingCategoryCount, coveredMissingCategoryCount, score, rank int) {
	t.Helper()
	for _, row := range actual {
		if row.ProjectID == projectID &&
			row.ProjectCode == projectCode &&
			row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.AssignmentStatus == assignmentStatus &&
			row.ProjectMissingSkillCategoryCount == missingCategoryCount &&
			row.CandidateCoveredMissingCategoryCount == coveredMissingCategoryCount &&
			row.RecommendationScore == score &&
			row.RecommendationRank == rank {
			return
		}
	}
	t.Fatalf("expected project staffing recommendation row not found: project_id=%d employee_id=%d", projectID, employeeID)
}

func assertEvaluationDueAlertRow(t *testing.T, actual []evaluationDueAlertRow, employeeID int, employeeCode, employeeName string, year, quarter int, dueDate, dueStatus, issueCode string) {
	t.Helper()
	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.TargetYear == year &&
			row.TargetQuarter == quarter &&
			row.DueDate.Format("2006-01-02") == dueDate &&
			row.DueStatus == dueStatus &&
			row.AlertIssueCode == issueCode &&
			row.OverdueDays > 0 {
			return
		}
	}
	t.Fatalf("expected evaluation due alert row not found: employee_id=%d year=%d quarter=%d", employeeID, year, quarter)
}

func assertAssignmentConflictRow(t *testing.T, actual []assignmentConflictRow, employeeID int, employeeCode, employeeName string, projectID sql.NullInt64, count int, issueCode string) {
	t.Helper()
	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.ConflictProjectID == projectID &&
			row.ConflictCount == count &&
			row.IssueCode == issueCode {
			return
		}
	}
	t.Fatalf("expected assignment conflict row not found: employee_id=%d issue=%s", employeeID, issueCode)
}

func assertProjectExitReadinessRow(t *testing.T, actual []projectExitReadinessRow, projectID int, projectCode, plannedExitDate string, endedAssignmentCount, currentBelongingCount, projectRecordCount, pendingExitMemberCount int, readinessStatus string) {
	t.Helper()
	for _, row := range actual {
		if row.ProjectID == projectID &&
			row.ProjectCode == projectCode &&
			row.PlannedExitDate.Format("2006-01-02") == plannedExitDate &&
			row.EndedAssignmentCount == endedAssignmentCount &&
			row.CurrentBelongingCount == currentBelongingCount &&
			row.ProjectRecordCount == projectRecordCount &&
			row.PendingExitMemberCount == pendingExitMemberCount &&
			row.ReadinessStatus == readinessStatus {
			return
		}
	}
	t.Fatalf("expected project exit readiness row not found: project_id=%d", projectID)
}

func assertManagerSpanRow(t *testing.T, actual []managerSpanRow, managerID int, managerCode, managerName, positionName string, teamID int, teamName string, managedCount, highRiskCount, evaluationMissingCount int) {
	t.Helper()
	for _, row := range actual {
		if row.ManagerEmployeeID == managerID &&
			row.ManagerEmployeeCode == managerCode &&
			row.ManagerEmployeeName == managerName &&
			row.PositionName == positionName &&
			row.TeamID == teamID &&
			row.TeamName == teamName &&
			row.ManagedMemberCount == managedCount &&
			row.HighRiskMemberCount == highRiskCount &&
			row.EvaluationMissingMemberCount == evaluationMissingCount {
			return
		}
	}
	t.Fatalf("expected manager span row not found: manager_id=%d", managerID)
}

func assertSkillMarketabilityRow(t *testing.T, actual []skillMarketabilityRow, employeeID int, employeeCode, employeeName string, categoryCount, highSkillCategoryCount, totalSkillCount int, latestEvaluation sql.NullInt64, tier string) {
	t.Helper()
	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.SkillCategoryCount == categoryCount &&
			row.HighSkillCategoryCount == highSkillCategoryCount &&
			row.TotalSkillCount == totalSkillCount &&
			row.LatestEvaluation == latestEvaluation &&
			row.MarketabilityTier == tier {
			return
		}
	}
	t.Fatalf("expected skill marketability row not found: employee_id=%d", employeeID)
}
