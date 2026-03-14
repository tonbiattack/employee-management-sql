package integration_test

import (
	"database/sql"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"
)

type evaluationTrendRow struct {
	EmployeeID         int
	EmployeeCode       string
	EmployeeName       string
	Year               int
	Quarter            int
	Evaluation         int
	PreviousEvaluation sql.NullInt64
	EvaluationDiff     sql.NullInt64
	IsLatest           int
}

type assignmentHistoryRow struct {
	EmployeeID   int
	EmployeeCode string
	EmployeeName string
	HistoryType  string
	HistoryName  string
	StartDate    time.Time
	EndDate      sql.NullTime
}

type benchRow struct {
	EmployeeID      int
	EmployeeCode    string
	EmployeeName    string
	CompanyName     sql.NullString
	DepartmentName  sql.NullString
	DivisionName    sql.NullString
	TeamName        sql.NullString
	ProjectCode     sql.NullString
	BenchReasonCode string
}

type projectRetroRow struct {
	ProjectID                   int
	ProjectCode                 string
	ProjectContent              string
	ProjectCompletionDate       time.Time
	AssignedMemberCount         int
	ProjectRecordCount          int
	ReflectionPointRecordCount  int
	EvaluationPointRecordCount  int
}

type accountAuditRow struct {
	EmployeeID         int
	EmployeeCode       string
	EmployeeName       string
	EmployeeStatusName string
	CompanyEmail       sql.NullString
	RoleNames          sql.NullString
	AuditIssueCode     string
}

type organizationStateAuditRow struct {
	EmployeeID            int
	EmployeeCode          string
	EmployeeName          string
	AuditScope            string
	CurrentValueName      sql.NullString
	OpenHistoryValueName  sql.NullString
	AuditIssueCode        string
}

type redeploymentPriorityRow struct {
	EmployeeID                int
	EmployeeCode              string
	EmployeeName              string
	CompanyName               sql.NullString
	TeamName                  sql.NullString
	CurrentPositionName       sql.NullString
	LatestEvaluation          sql.NullInt64
	HighSkillCount            int
	MissingSkillCategoryCount int
	AssignmentStatus          string
	RedeploymentPriority      string
}

type projectClosureAuditRow struct {
	ProjectID                  int
	ProjectCode                string
	ProjectCompletionDate      time.Time
	AssignedMemberCount        int
	ProjectRecordCount         int
	CurrentBelongingMemberCount int
	MissingProjectRecordCount  int
	AuditIssueCode             string
}

type inactiveEmployeeFollowupRow struct {
	EmployeeID            int
	EmployeeCode          string
	EmployeeName          string
	EmployeeStatusName    string
	LatestStatusEventDate time.Time
	ReturningPermission   sql.NullBool
	HasLoginAccount       int
	ContactBucket         string
	CurrentBelongingCount int
	FollowupIssueCode     string
}

type evaluationCoverageRow struct {
	EmployeeID               int
	EmployeeCode             string
	EmployeeName             string
	ExpectedQuarterCount     int
	RegisteredQuarterCount   int
	MissingQuarterList       string
	CoverageIssueCode        string
}

type projectSkillCoverageRow struct {
	ProjectID                     int
	ProjectCode                   string
	AssignedMemberCount           int
	HighSkillMemberCount          int
	HighSkillCoverageRatio        string
	MissingSkillCategoryCount     int
	StaffingRiskLevel             string
}

type rehireCandidateRow struct {
	EmployeeID            int
	EmployeeCode          string
	EmployeeName          string
	RetirementDate        time.Time
	ReturningPermission   bool
	LatestEvaluation      sql.NullInt64
	HighSkillCount        int
	ContactBucket         string
	RehirePriority        string
}

func TestEmployeeEvaluationTrendSQL(t *testing.T) {
	t.Run("評価推移_前回差分と最新判定を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareEvaluationTrendFixture(t, db.SQL)
		query := loadSearchQuery(t, "employee_evaluation_trend.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query evaluation trend: %v", err)
		}
		defer rows.Close()

		var actual []evaluationTrendRow
		for rows.Next() {
			var row evaluationTrendRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.Year,
				&row.Quarter,
				&row.Evaluation,
				&row.PreviousEvaluation,
				&row.EvaluationDiff,
				&row.IsLatest,
			); err != nil {
				t.Fatalf("failed to scan evaluation trend row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating evaluation trend rows: %v", err)
		}

		assertEvaluationTrendRow(t, actual, evaluationTrendRow{
			EmployeeID:         1,
			EmployeeCode:       "56001",
			EmployeeName:       "田嶋研人",
			Year:               2026,
			Quarter:            2,
			Evaluation:         9,
			PreviousEvaluation: sql.NullInt64{Int64: 6, Valid: true},
			EvaluationDiff:     sql.NullInt64{Int64: 3, Valid: true},
			IsLatest:           0,
		})
		assertEvaluationTrendRow(t, actual, evaluationTrendRow{
			EmployeeID:         1,
			EmployeeCode:       "56001",
			EmployeeName:       "田嶋研人",
			Year:               2026,
			Quarter:            3,
			Evaluation:         7,
			PreviousEvaluation: sql.NullInt64{Int64: 9, Valid: true},
			EvaluationDiff:     sql.NullInt64{Int64: -2, Valid: true},
			IsLatest:           1,
		})
	})
}

func TestOrganizationAssignmentHistorySQL(t *testing.T) {
	t.Run("所属履歴_組織と役職を時系列で返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareOrganizationHistoryFixture(t, db.SQL)
		query := loadSearchQuery(t, "organization_assignment_history.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query organization assignment history: %v", err)
		}
		defer rows.Close()

		var actual []assignmentHistoryRow
		for rows.Next() {
			var row assignmentHistoryRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.HistoryType,
				&row.HistoryName,
				&row.StartDate,
				&row.EndDate,
			); err != nil {
				t.Fatalf("failed to scan assignment history row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating assignment history rows: %v", err)
		}

		assertAssignmentHistoryRow(t, actual, 1, "56001", "田嶋研人", "COMPANY", fixture.CompanyName, "2026-01-01", "2026-12-31")
		assertAssignmentHistoryRow(t, actual, 1, "56001", "田嶋研人", "DEPARTMENT", fixture.DepartmentName, "2026-01-05", "2026-12-31")
		assertAssignmentHistoryRow(t, actual, 1, "56001", "田嶋研人", "DIVISION", fixture.DivisionName, "2026-01-10", "2026-12-31")
		assertAssignmentHistoryRow(t, actual, 1, "56001", "田嶋研人", "TEAM", fixture.TeamName, "2026-01-15", "2026-12-31")
		assertAssignmentHistoryRow(t, actual, 1, "56001", "田嶋研人", "POSITION", fixture.PositionName, "2026-02-01", "")
	})
}

func TestBenchActiveEmployeesSQL(t *testing.T) {
	t.Run("ベンチ社員_未所属理由を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareBenchFixture(t, db.SQL)
		query := loadSearchQuery(t, "bench_active_employees.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query bench active employees: %v", err)
		}
		defer rows.Close()

		var actual []benchRow
		for rows.Next() {
			var row benchRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.CompanyName,
				&row.DepartmentName,
				&row.DivisionName,
				&row.TeamName,
				&row.ProjectCode,
				&row.BenchReasonCode,
			); err != nil {
				t.Fatalf("failed to scan bench row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating bench rows: %v", err)
		}

		assertBenchRow(t, actual, 1, "56001", "田嶋研人", "PROJECT_UNASSIGNED")
		assertBenchRow(t, actual, 2, "11000", "中田あやか", "TEAM_UNASSIGNED")
	})
}

func TestProjectCompletionRetrospectiveSummarySQL(t *testing.T) {
	t.Run("案件完了サマリ_完了日と実績件数を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareProjectRetrospectiveFixture(t, db.SQL)
		query := loadSearchQuery(t, "project_completion_retrospective_summary.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query project retrospective summary: %v", err)
		}
		defer rows.Close()

		var actual []projectRetroRow
		for rows.Next() {
			var row projectRetroRow
			if err := rows.Scan(
				&row.ProjectID,
				&row.ProjectCode,
				&row.ProjectContent,
				&row.ProjectCompletionDate,
				&row.AssignedMemberCount,
				&row.ProjectRecordCount,
				&row.ReflectionPointRecordCount,
				&row.EvaluationPointRecordCount,
			); err != nil {
				t.Fatalf("failed to scan project retrospective row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating project retrospective rows: %v", err)
		}

		assertProjectRetroRow(t, actual, fixture.ProjectID, fixture.ProjectCode, "2026-09-30", 2, 2, 2, 2)
	})
}

func TestAccountAccessAuditSQL(t *testing.T) {
	t.Run("認証監査_状態不整合を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareAccountAuditFixture(t, db.SQL)
		query := loadSearchQuery(t, "account_access_audit.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query account access audit: %v", err)
		}
		defer rows.Close()

		var actual []accountAuditRow
		for rows.Next() {
			var row accountAuditRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.EmployeeStatusName,
				&row.CompanyEmail,
				&row.RoleNames,
				&row.AuditIssueCode,
			); err != nil {
				t.Fatalf("failed to scan account audit row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating account audit rows: %v", err)
		}

		assertAccountAuditRow(t, actual, 3, "33000", "橘まゆみ", "休職社員", "INACTIVE_HAS_LOGIN")
		assertAccountAuditRow(t, actual, 4, "56002", "川嶋美由紀", "現役社員", "ACTIVE_NO_LOGIN")
	})
}

func TestOrganizationStateConsistencyAuditSQL(t *testing.T) {
	t.Run("現在値と履歴の不整合を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareOrganizationStateAuditFixture(t, db.SQL)
		query := loadSearchQuery(t, "organization_state_consistency_audit.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query organization state audit: %v", err)
		}
		defer rows.Close()

		var actual []organizationStateAuditRow
		for rows.Next() {
			var row organizationStateAuditRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.AuditScope,
				&row.CurrentValueName,
				&row.OpenHistoryValueName,
				&row.AuditIssueCode,
			); err != nil {
				t.Fatalf("failed to scan organization state audit row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating organization state audit rows: %v", err)
		}

		assertOrganizationStateAuditRow(t, actual, 1, "56001", "田嶋研人", "COMPANY", fixture.CurrentCompanyName, fixture.HistoryCompanyName, "CURRENT_HISTORY_MISMATCH")
		assertOrganizationStateAuditRow(t, actual, 2, "11000", "中田あやか", "TEAM", "", fixture.TeamName, "OPEN_HISTORY_WITHOUT_CURRENT")
	})
}

func TestEmployeeRedeploymentPrioritySQL(t *testing.T) {
	t.Run("再配置優先度を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareRedeploymentFixture(t, db.SQL)
		query := loadSearchQuery(t, "employee_redeployment_priority.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query redeployment priority: %v", err)
		}
		defer rows.Close()

		var actual []redeploymentPriorityRow
		for rows.Next() {
			var row redeploymentPriorityRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.CompanyName,
				&row.TeamName,
				&row.CurrentPositionName,
				&row.LatestEvaluation,
				&row.HighSkillCount,
				&row.MissingSkillCategoryCount,
				&row.AssignmentStatus,
				&row.RedeploymentPriority,
			); err != nil {
				t.Fatalf("failed to scan redeployment priority row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating redeployment priority rows: %v", err)
		}

		assertRedeploymentPriorityRow(t, actual, 1, "56001", "田嶋研人", "PROJECT_UNASSIGNED", "HIGH")
		assertRedeploymentPriorityRow(t, actual, 2, "11000", "中田あやか", "TEAM_UNASSIGNED", "MEDIUM")
	})
}

func TestProjectClosureFollowupAuditSQL(t *testing.T) {
	t.Run("完了案件のフォローアップ課題を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareProjectClosureAuditFixture(t, db.SQL)
		query := loadSearchQuery(t, "project_closure_followup_audit.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query project closure audit: %v", err)
		}
		defer rows.Close()

		var actual []projectClosureAuditRow
		for rows.Next() {
			var row projectClosureAuditRow
			if err := rows.Scan(
				&row.ProjectID,
				&row.ProjectCode,
				&row.ProjectCompletionDate,
				&row.AssignedMemberCount,
				&row.ProjectRecordCount,
				&row.CurrentBelongingMemberCount,
				&row.MissingProjectRecordCount,
				&row.AuditIssueCode,
			); err != nil {
				t.Fatalf("failed to scan project closure audit row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating project closure audit rows: %v", err)
		}

		assertProjectClosureAuditRow(t, actual, fixture.ProjectID, fixture.ProjectCode, "2026-11-30", 2, 1, 1, 1, "COMPLETED_PROJECT_HAS_ACTIVE_BELONGING")
		assertProjectClosureAuditRow(t, actual, fixture.ProjectID, fixture.ProjectCode, "2026-11-30", 2, 1, 1, 1, "COMPLETED_PROJECT_MISSING_RECORDS")
	})
}

func TestInactiveEmployeeFollowupQueueSQL(t *testing.T) {
	t.Run("休職退職者のフォローアップ課題を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareInactiveEmployeeFollowupFixture(t, db.SQL)
		query := loadSearchQuery(t, "inactive_employee_followup_queue.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query inactive employee followup queue: %v", err)
		}
		defer rows.Close()

		var actual []inactiveEmployeeFollowupRow
		for rows.Next() {
			var row inactiveEmployeeFollowupRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.EmployeeStatusName,
				&row.LatestStatusEventDate,
				&row.ReturningPermission,
				&row.HasLoginAccount,
				&row.ContactBucket,
				&row.CurrentBelongingCount,
				&row.FollowupIssueCode,
			); err != nil {
				t.Fatalf("failed to scan inactive employee followup row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating inactive employee followup rows: %v", err)
		}

		assertInactiveEmployeeFollowupRow(t, actual, 3, "33000", "橘まゆみ", "休職社員", "INACTIVE_HAS_LOGIN")
		assertInactiveEmployeeFollowupRow(t, actual, 3, "33000", "橘まゆみ", "休職社員", "INACTIVE_STILL_HAS_BELONGING")
		assertInactiveEmployeeFollowupRow(t, actual, 5, "57003", "河合陽子", "退職社員", "RETIRED_ELIGIBLE_FOR_REHIRE_REVIEW")
	})
}

func TestEvaluationCoverageAuditSQL(t *testing.T) {
	t.Run("評価登録漏れを返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareEvaluationCoverageFixture(t, db.SQL)
		query := loadSearchQuery(t, "evaluation_coverage_audit.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query evaluation coverage audit: %v", err)
		}
		defer rows.Close()

		var actual []evaluationCoverageRow
		for rows.Next() {
			var row evaluationCoverageRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.ExpectedQuarterCount,
				&row.RegisteredQuarterCount,
				&row.MissingQuarterList,
				&row.CoverageIssueCode,
			); err != nil {
				t.Fatalf("failed to scan evaluation coverage row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating evaluation coverage rows: %v", err)
		}

		assertEvaluationCoverageRow(t, actual, 1, "56001", "田嶋研人", 4, 2, "2027-Q2,2027-Q4", "EVALUATION_QUARTER_MISSING")
	})
}

func TestProjectSkillCoverageGapSQL(t *testing.T) {
	t.Run("案件のスキル充足ギャップを返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareProjectSkillCoverageFixture(t, db.SQL)
		query := loadSearchQuery(t, "project_skill_coverage_gap.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query project skill coverage gap: %v", err)
		}
		defer rows.Close()

		var actual []projectSkillCoverageRow
		for rows.Next() {
			var row projectSkillCoverageRow
			if err := rows.Scan(
				&row.ProjectID,
				&row.ProjectCode,
				&row.AssignedMemberCount,
				&row.HighSkillMemberCount,
				&row.HighSkillCoverageRatio,
				&row.MissingSkillCategoryCount,
				&row.StaffingRiskLevel,
			); err != nil {
				t.Fatalf("failed to scan project skill coverage row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating project skill coverage rows: %v", err)
		}

		assertProjectSkillCoverageRow(t, actual, fixture.ProjectID, fixture.ProjectCode, 2, 1, "0.50", 0, "MEDIUM")
	})
}

func TestRehireCandidatePoolSQL(t *testing.T) {
	t.Run("再雇用候補を優先度付きで返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareRehireCandidateFixture(t, db.SQL)
		query := loadSearchQuery(t, "rehire_candidate_pool.sql")

		rows, err := db.SQL.Query(query)
		if err != nil {
			t.Fatalf("failed to query rehire candidate pool: %v", err)
		}
		defer rows.Close()

		var actual []rehireCandidateRow
		for rows.Next() {
			var row rehireCandidateRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.RetirementDate,
				&row.ReturningPermission,
				&row.LatestEvaluation,
				&row.HighSkillCount,
				&row.ContactBucket,
				&row.RehirePriority,
			); err != nil {
				t.Fatalf("failed to scan rehire candidate row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating rehire candidate rows: %v", err)
		}

		assertRehireCandidateRow(t, actual, 5, "57003", "河合陽子", "2027-03-31", true, sql.NullInt64{Int64: 8, Valid: true}, 2, "RETIRED_CONTACT", "HIGH")
	})
}

func loadSearchQuery(t *testing.T, fileName string) string {
	t.Helper()

	_, testFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("failed to detect test file path")
	}

	queryPath := filepath.Join(filepath.Dir(testFile), "..", "..", "sql", "search", fileName)
	queryBytes, err := os.ReadFile(queryPath)
	if err != nil {
		t.Fatalf("failed to read query file %s: %v", fileName, err)
	}

	return string(queryBytes)
}

func prepareEvaluationTrendFixture(t *testing.T, db *sql.Tx) {
	t.Helper()

	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id = ? AND year = ?`, 1, 2026); err != nil {
		t.Fatalf("failed to cleanup evaluation trend fixture: %v", err)
	}
	insertEvaluation(t, db, 1, 2026, 1, "trend fixture q1", 6)
	insertEvaluation(t, db, 1, 2026, 2, "trend fixture q2", 9)
	insertEvaluation(t, db, 1, 2026, 3, "trend fixture q3", 7)
}

type organizationHistoryFixture struct {
	CompanyName    string
	DepartmentName string
	DivisionName   string
	TeamName       string
	PositionName   string
}

func prepareOrganizationHistoryFixture(t *testing.T, db *sql.Tx) organizationHistoryFixture {
	t.Helper()

	businessPartnerID := getOrCreateBusinessPartnerID(t, db)

	companyID := insertCompanyFixture(t, db, "COMP-HIS-001", "History Test Company")
	departmentID := insertDepartmentFixture(t, db, companyID, "DEP-HIS-001", "History Test Department")
	divisionID := insertDivisionFixture(t, db, departmentID, businessPartnerID, "DIV-HIS-001", "History Test Division")
	teamID := insertTeamFixture(t, db, divisionID, "TEAM-HIS-001", "History Test Team")
	positionID := insertPositionFixture(t, db, "POS-HIS-001", "History Test Position")

	if _, err := db.Exec(`DELETE FROM employee.company_assignment WHERE employee_id = ? AND company_assignment_date >= ?`, 1, "2026-01-01"); err != nil {
		t.Fatalf("failed to cleanup company assignment fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.assigned_department WHERE employee_id = ? AND assigned_department_date >= ?`, 1, "2026-01-01"); err != nil {
		t.Fatalf("failed to cleanup assigned department fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.assigned_division WHERE employee_id = ? AND assigned_division_date >= ?`, 1, "2026-01-01"); err != nil {
		t.Fatalf("failed to cleanup assigned division fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.assigned_team WHERE employee_id = ? AND assigned_team_date >= ?`, 1, "2026-01-01"); err != nil {
		t.Fatalf("failed to cleanup assigned team fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.assumption_of_position WHERE employee_id = ? AND assumption_of_position_date >= ?`, 1, "2026-01-01"); err != nil {
		t.Fatalf("failed to cleanup position history fixture: %v", err)
	}

	if _, err := db.Exec(`INSERT INTO employee.company_assignment(company_id, employee_id, company_assignment_date, company_assignment_end_date) VALUES (?, ?, ?, ?)`,
		companyID, 1, "2026-01-01", "2026-12-31"); err != nil {
		t.Fatalf("failed to insert company assignment fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assigned_department(department_id, employee_id, assigned_department_date, assigned_department_end_date) VALUES (?, ?, ?, ?)`,
		departmentID, 1, "2026-01-05", "2026-12-31"); err != nil {
		t.Fatalf("failed to insert department assignment fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assigned_division(division_id, employee_id, assigned_division_date, assigned_division_end_date) VALUES (?, ?, ?, ?)`,
		divisionID, 1, "2026-01-10", "2026-12-31"); err != nil {
		t.Fatalf("failed to insert division assignment fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assigned_team(team_id, employee_id, assigned_team_date, assigned_team_end_date) VALUES (?, ?, ?, ?)`,
		teamID, 1, "2026-01-15", "2026-12-31"); err != nil {
		t.Fatalf("failed to insert team assignment fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assumption_of_position(position_id, employee_id, assumption_of_position_date, assumption_of_position_end_date) VALUES (?, ?, ?, ?)`,
		positionID, 1, "2026-02-01", nil); err != nil {
		t.Fatalf("failed to insert position history fixture: %v", err)
	}

	return organizationHistoryFixture{
		CompanyName:    "History Test Company",
		DepartmentName: "History Test Department",
		DivisionName:   "History Test Division",
		TeamName:       "History Test Team",
		PositionName:   "History Test Position",
	}
}

func prepareBenchFixture(t *testing.T, db *sql.Tx) {
	t.Helper()

	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 1 WHERE employee_id IN (1, 2)`); err != nil {
		t.Fatalf("failed to reset bench fixture statuses: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup belonging project fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_team WHERE employee_id = ?`, 2); err != nil {
		t.Fatalf("failed to cleanup belonging team fixture: %v", err)
	}
}

type projectRetrospectiveFixture struct {
	ProjectID   int
	ProjectCode string
}

func prepareProjectRetrospectiveFixture(t *testing.T, db *sql.Tx) projectRetrospectiveFixture {
	t.Helper()

	businessPartnerID := getOrCreateBusinessPartnerID(t, db)
	projectID := insertProjectFixture(t, db, businessPartnerID, "PRJ-RETRO-001", "Retrospective Test Project", "2026-04-01")

	if _, err := db.Exec(`DELETE FROM employee.assignment_project WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup assignment project fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_project_record WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup employee project record fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.project_completion_report WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup project completion fixture: %v", err)
	}

	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, project_id, employee_id) VALUES (?, ?, ?)`, "2026-04-01", projectID, 1); err != nil {
		t.Fatalf("failed to insert assignment project fixture 1: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, project_id, employee_id) VALUES (?, ?, ?)`, "2026-04-15", projectID, 2); err != nil {
		t.Fatalf("failed to insert assignment project fixture 2: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.employee_project_record(project_leaving_date, evaluation_point, reflection_point, project_id, employee_id) VALUES (?, ?, ?, ?, ?)`,
		"2026-09-30", "Retrospective fixture evaluation 1", "Retrospective fixture reflection 1", projectID, 1); err != nil {
		t.Fatalf("failed to insert employee project record fixture 1: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.employee_project_record(project_leaving_date, evaluation_point, reflection_point, project_id, employee_id) VALUES (?, ?, ?, ?, ?)`,
		"2026-09-30", "Retrospective fixture evaluation 2", "Retrospective fixture reflection 2", projectID, 2); err != nil {
		t.Fatalf("failed to insert employee project record fixture 2: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.project_completion_report(project_completion_date, project_id) VALUES (?, ?)`, "2026-09-30", projectID); err != nil {
		t.Fatalf("failed to insert project completion report fixture: %v", err)
	}

	return projectRetrospectiveFixture{
		ProjectID:   projectID,
		ProjectCode: "PRJ-RETRO-001",
	}
}

func prepareAccountAuditFixture(t *testing.T, db *sql.Tx) {
	t.Helper()

	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 2 WHERE employee_id = ?`, 3); err != nil {
		t.Fatalf("failed to set leave status fixture: %v", err)
	}
	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 1 WHERE employee_id = ?`, 4); err != nil {
		t.Fatalf("failed to set active status fixture: %v", err)
	}

	var passwordID int
	err := db.QueryRow(`
SELECT p.password_id
  FROM employee.password p
  INNER JOIN employee.active_employee_contact_information a
    ON a.active_employee_contact_information_id = p.active_employee_contact_information_id
  INNER JOIN employee.employee_contact_information eci
    ON eci.employee_contact_information_id = a.employee_contact_information_id
 WHERE eci.employee_id = ?`, 4).Scan(&passwordID)
	if err == nil {
		if _, err := db.Exec(`DELETE FROM employee.ownership WHERE password_id = ?`, passwordID); err != nil {
			t.Fatalf("failed to delete ownership fixture for employee 4: %v", err)
		}
		if _, err := db.Exec(`DELETE FROM employee.password WHERE password_id = ?`, passwordID); err != nil {
			t.Fatalf("failed to delete password fixture for employee 4: %v", err)
		}
	} else if err != sql.ErrNoRows {
		t.Fatalf("failed to query password fixture for employee 4: %v", err)
	}

	if _, err := db.Exec(`
DELETE a
  FROM employee.active_employee_contact_information a
  INNER JOIN employee.employee_contact_information eci
    ON eci.employee_contact_information_id = a.employee_contact_information_id
 WHERE eci.employee_id = ?`, 4); err != nil {
		t.Fatalf("failed to delete active contact fixture for employee 4: %v", err)
	}
}

type organizationStateAuditFixture struct {
	CurrentCompanyName string
	HistoryCompanyName string
	TeamName           string
}

func prepareOrganizationStateAuditFixture(t *testing.T, db *sql.Tx) organizationStateAuditFixture {
	t.Helper()

	businessPartnerID := getOrCreateBusinessPartnerID(t, db)
	currentCompanyID := insertCompanyFixture(t, db, "COMP-AUD-001", "Audit Current Company")
	historyCompanyID := insertCompanyFixture(t, db, "COMP-AUD-002", "Audit History Company")
	departmentID := insertDepartmentFixture(t, db, currentCompanyID, "DEP-AUD-001", "Audit Department")
	divisionID := insertDivisionFixture(t, db, departmentID, businessPartnerID, "DIV-AUD-001", "Audit Division")
	teamID := insertTeamFixture(t, db, divisionID, "TEAM-AUD-001", "Audit Team")

	if _, err := db.Exec(`DELETE FROM employee.belonging_company WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to cleanup employee 1 company belonging: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.company_assignment WHERE employee_id = ? AND company_assignment_end_date IS NULL`, 1); err != nil {
		t.Fatalf("failed to cleanup employee 1 company history: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.belonging_company(company_id, employee_id) VALUES (?, ?)`, currentCompanyID, 1); err != nil {
		t.Fatalf("failed to insert employee 1 current company: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.company_assignment(company_id, employee_id, company_assignment_date, company_assignment_end_date) VALUES (?, ?, ?, NULL)`,
		historyCompanyID, 1, "2026-01-01"); err != nil {
		t.Fatalf("failed to insert employee 1 open company history: %v", err)
	}

	if _, err := db.Exec(`DELETE FROM employee.belonging_team WHERE employee_id = ?`, 2); err != nil {
		t.Fatalf("failed to cleanup employee 2 team belonging: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.assigned_team WHERE employee_id = ? AND assigned_team_end_date IS NULL`, 2); err != nil {
		t.Fatalf("failed to cleanup employee 2 team history: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assigned_team(team_id, employee_id, assigned_team_date, assigned_team_end_date) VALUES (?, ?, ?, NULL)`,
		teamID, 2, "2026-02-01"); err != nil {
		t.Fatalf("failed to insert employee 2 open team history: %v", err)
	}

	return organizationStateAuditFixture{
		CurrentCompanyName: "Audit Current Company",
		HistoryCompanyName: "Audit History Company",
		TeamName:           "Audit Team",
	}
}

func prepareRedeploymentFixture(t *testing.T, db *sql.Tx) {
	t.Helper()

	prepareBenchFixture(t, db)
	projectID := getOrCreateProjectID(t, db)
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE employee_id = ?`, 2); err != nil {
		t.Fatalf("failed to cleanup employee 2 project belonging for redeployment fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.belonging_project(project_id, employee_id) VALUES (?, ?)`, projectID, 2); err != nil {
		t.Fatalf("failed to insert employee 2 project belonging for redeployment fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id = ? AND year = ?`, 1, 2027); err != nil {
		t.Fatalf("failed to cleanup employee 1 redeployment evaluations: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id = ? AND year = ?`, 2, 2027); err != nil {
		t.Fatalf("failed to cleanup employee 2 redeployment evaluations: %v", err)
	}
	insertEvaluation(t, db, 1, 2027, 1, "redeploy high", 8)
	insertEvaluation(t, db, 2, 2027, 1, "redeploy medium", 5)
}

type projectClosureAuditFixture struct {
	ProjectID   int
	ProjectCode string
}

func prepareProjectClosureAuditFixture(t *testing.T, db *sql.Tx) projectClosureAuditFixture {
	t.Helper()

	businessPartnerID := getOrCreateBusinessPartnerID(t, db)
	projectID := insertProjectFixture(t, db, businessPartnerID, "PRJ-CLOSE-001", "Closure Audit Project", "2026-08-01")

	if _, err := db.Exec(`DELETE FROM employee.assignment_project WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup closure assignment fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.belonging_project WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup closure belonging fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_project_record WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup closure record fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.project_completion_report WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup closure report fixture: %v", err)
	}

	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, project_id, employee_id) VALUES (?, ?, ?)`, "2026-08-01", projectID, 1); err != nil {
		t.Fatalf("failed to insert closure assignment 1: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, project_id, employee_id) VALUES (?, ?, ?)`, "2026-08-10", projectID, 2); err != nil {
		t.Fatalf("failed to insert closure assignment 2: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.belonging_project(project_id, employee_id) VALUES (?, ?)`, projectID, 1); err != nil {
		t.Fatalf("failed to insert closure current belonging: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.employee_project_record(project_leaving_date, evaluation_point, reflection_point, project_id, employee_id) VALUES (?, ?, ?, ?, ?)`,
		"2026-11-30", "closure eval", "closure reflection", projectID, 1); err != nil {
		t.Fatalf("failed to insert closure project record: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.project_completion_report(project_completion_date, project_id) VALUES (?, ?)`, "2026-11-30", projectID); err != nil {
		t.Fatalf("failed to insert closure completion report: %v", err)
	}

	return projectClosureAuditFixture{
		ProjectID:   projectID,
		ProjectCode: "PRJ-CLOSE-001",
	}
}

func prepareInactiveEmployeeFollowupFixture(t *testing.T, db *sql.Tx) {
	t.Helper()

	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 2 WHERE employee_id = ?`, 3); err != nil {
		t.Fatalf("failed to set employee 3 leave status: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.leave_of_absence WHERE employee_id = ? AND leave_of_absence_date = ?`, 3, "2026-10-01"); err != nil {
		t.Fatalf("failed to cleanup employee 3 leave event: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.leave_of_absence(employee_id, leave_of_absence_date) VALUES (?, ?)`, 3, "2026-10-01"); err != nil {
		t.Fatalf("failed to insert employee 3 leave event: %v", err)
	}

	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 3 WHERE employee_id = ?`, 5); err != nil {
		t.Fatalf("failed to set employee 5 retired status: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.retired_employee WHERE employee_id = ?`, 5); err != nil {
		t.Fatalf("failed to cleanup employee 5 retired employee row: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.retirement WHERE employee_id = ? AND retirement_date = ?`, 5, "2026-12-31"); err != nil {
		t.Fatalf("failed to cleanup employee 5 retirement event: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.retired_employee(employee_id, returning_permission) VALUES (?, ?)`, 5, true); err != nil {
		t.Fatalf("failed to insert employee 5 retired employee row: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.retirement(employee_id, retirement_reason, retirement_date) VALUES (?, ?, ?)`, 5, "followup fixture", "2026-12-31"); err != nil {
		t.Fatalf("failed to insert employee 5 retirement event: %v", err)
	}
}

func prepareEvaluationCoverageFixture(t *testing.T, db *sql.Tx) {
	t.Helper()

	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 1 WHERE employee_id = ?`, 1); err != nil {
		t.Fatalf("failed to reset employee 1 status for evaluation coverage: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id = ? AND year = ?`, 1, 2027); err != nil {
		t.Fatalf("failed to cleanup evaluation coverage fixture: %v", err)
	}
	insertEvaluation(t, db, 1, 2027, 1, "coverage q1", 7)
	insertEvaluation(t, db, 1, 2027, 3, "coverage q3", 8)
}

type projectSkillCoverageFixture struct {
	ProjectID   int
	ProjectCode string
}

func prepareProjectSkillCoverageFixture(t *testing.T, db *sql.Tx) projectSkillCoverageFixture {
	t.Helper()

	businessPartnerID := getOrCreateBusinessPartnerID(t, db)
	projectID := insertProjectFixture(t, db, businessPartnerID, "PRJ-SKILL-001", "Skill Coverage Project", "2027-01-01")

	if _, err := db.Exec(`DELETE FROM employee.assignment_project WHERE project_id = ?`, projectID); err != nil {
		t.Fatalf("failed to cleanup skill coverage assignments: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_database_skill WHERE employee_id = ? AND database_skill_id = ?`, 2, 3); err != nil {
		t.Fatalf("failed to cleanup employee 2 database skill fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.employee_framework_skill WHERE employee_id = ? AND framework_skill_id = ?`, 2, 4); err != nil {
		t.Fatalf("failed to cleanup employee 2 framework skill fixture: %v", err)
	}

	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, project_id, employee_id) VALUES (?, ?, ?)`, "2027-01-10", projectID, 1); err != nil {
		t.Fatalf("failed to insert skill coverage assignment 1: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.assignment_project(assignment_project_date, project_id, employee_id) VALUES (?, ?, ?)`, "2027-01-15", projectID, 2); err != nil {
		t.Fatalf("failed to insert skill coverage assignment 2: %v", err)
	}

	return projectSkillCoverageFixture{
		ProjectID:   projectID,
		ProjectCode: "PRJ-SKILL-001",
	}
}

func prepareRehireCandidateFixture(t *testing.T, db *sql.Tx) {
	t.Helper()

	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 3 WHERE employee_id = ?`, 5); err != nil {
		t.Fatalf("failed to reset employee 5 retired status for rehire fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.retired_employee WHERE employee_id = ?`, 5); err != nil {
		t.Fatalf("failed to cleanup retired employee for rehire fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.retirement WHERE employee_id = ? AND retirement_date = ?`, 5, "2027-03-31"); err != nil {
		t.Fatalf("failed to cleanup retirement row for rehire fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.evaluation WHERE employee_id = ? AND year = ?`, 5, 2026); err != nil {
		t.Fatalf("failed to cleanup rehire evaluation fixture: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.retired_employee_contact_information WHERE employee_contact_information_id = (SELECT employee_contact_information_id FROM employee.employee_contact_information WHERE employee_id = ? LIMIT 1)`, 5); err != nil {
		t.Fatalf("failed to cleanup retired contact fixture: %v", err)
	}

	var contactID int
	if err := db.QueryRow(`SELECT employee_contact_information_id FROM employee.employee_contact_information WHERE employee_id = ? LIMIT 1`, 5).Scan(&contactID); err != nil {
		res, err := db.Exec(`INSERT INTO employee.employee_contact_information(employee_id, private_phone_number, private_email) VALUES (?, ?, ?)`,
			5, "090-0000-0005", "rehire5@example.org")
		if err != nil {
			t.Fatalf("failed to insert employee 5 contact for rehire fixture: %v", err)
		}
		id, err := res.LastInsertId()
		if err != nil {
			t.Fatalf("failed to fetch employee 5 contact id: %v", err)
		}
		contactID = int(id)
	}
	if _, err := db.Exec(`INSERT INTO employee.retired_employee(employee_id, returning_permission) VALUES (?, ?)`, 5, true); err != nil {
		t.Fatalf("failed to insert retired employee for rehire fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.retirement(employee_id, retirement_reason, retirement_date) VALUES (?, ?, ?)`, 5, "rehire candidate", "2027-03-31"); err != nil {
		t.Fatalf("failed to insert retirement for rehire fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.retired_employee_contact_information(employee_contact_information_id) VALUES (?)`, contactID); err != nil {
		t.Fatalf("failed to insert retired contact for rehire fixture: %v", err)
	}
	insertEvaluation(t, db, 5, 2026, 4, "rehire eval", 8)
	if _, err := db.Exec(`INSERT INTO employee.employee_programming_skill(programming_skill_id, skill_level, employee_id) VALUES (?, ?, ?)`, 10, 8, 5); err != nil {
		t.Fatalf("failed to insert employee 5 programming skill for rehire fixture: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.employee_database_skill(database_skill_id, skill_level, employee_id) VALUES (?, ?, ?)`, 1, 8, 5); err != nil {
		t.Fatalf("failed to insert employee 5 database skill for rehire fixture: %v", err)
	}
}

func insertEvaluation(t *testing.T, db *sql.Tx, employeeID, year, quarter int, comment string, score int) {
	t.Helper()

	if _, err := db.Exec(`INSERT INTO employee.evaluation(year, quarter, comment, evaluation, employee_id) VALUES (?, ?, ?, ?, ?)`,
		year, quarter, comment, score, employeeID); err != nil {
		t.Fatalf("failed to insert evaluation fixture: %v", err)
	}
}

func insertCompanyFixture(t *testing.T, db *sql.Tx, code, name string) int {
	t.Helper()

	if _, err := db.Exec(`DELETE FROM employee.company WHERE company_code = ?`, code); err != nil {
		t.Fatalf("failed to cleanup company fixture: %v", err)
	}
	res, err := db.Exec(`INSERT INTO employee.company(company_code, company_name, company_business_content) VALUES (?, ?, ?)`,
		code, name, "fixture company")
	if err != nil {
		t.Fatalf("failed to insert company fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch company fixture id: %v", err)
	}
	return int(id)
}

func insertDepartmentFixture(t *testing.T, db *sql.Tx, companyID int, code, name string) int {
	t.Helper()

	if _, err := db.Exec(`DELETE FROM employee.department WHERE department_code = ?`, code); err != nil {
		t.Fatalf("failed to cleanup department fixture: %v", err)
	}
	res, err := db.Exec(`INSERT INTO employee.department(company_id, department_code, department_name) VALUES (?, ?, ?)`,
		companyID, code, name)
	if err != nil {
		t.Fatalf("failed to insert department fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch department fixture id: %v", err)
	}
	return int(id)
}

func insertDivisionFixture(t *testing.T, db *sql.Tx, departmentID, businessPartnerID int, code, name string) int {
	t.Helper()

	if _, err := db.Exec(`DELETE FROM employee.division WHERE division_code = ?`, code); err != nil {
		t.Fatalf("failed to cleanup division fixture: %v", err)
	}
	res, err := db.Exec(`INSERT INTO employee.division(department_id, division_code, division_name, business_partner_id) VALUES (?, ?, ?, ?)`,
		departmentID, code, name, businessPartnerID)
	if err != nil {
		t.Fatalf("failed to insert division fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch division fixture id: %v", err)
	}
	return int(id)
}

func insertTeamFixture(t *testing.T, db *sql.Tx, divisionID int, code, name string) int {
	t.Helper()

	if _, err := db.Exec(`DELETE FROM employee.team WHERE team_code = ?`, code); err != nil {
		t.Fatalf("failed to cleanup team fixture: %v", err)
	}
	res, err := db.Exec(`INSERT INTO employee.team(division_id, team_code, team_name) VALUES (?, ?, ?)`,
		divisionID, code, name)
	if err != nil {
		t.Fatalf("failed to insert team fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch team fixture id: %v", err)
	}
	return int(id)
}

func insertPositionFixture(t *testing.T, db *sql.Tx, code, name string) int {
	t.Helper()

	if _, err := db.Exec(`DELETE FROM employee.position WHERE position_code = ?`, code); err != nil {
		t.Fatalf("failed to cleanup position fixture: %v", err)
	}
	res, err := db.Exec(`INSERT INTO employee.position(position_code, position_name) VALUES (?, ?)`, code, name)
	if err != nil {
		t.Fatalf("failed to insert position fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch position fixture id: %v", err)
	}
	return int(id)
}

func insertProjectFixture(t *testing.T, db *sql.Tx, businessPartnerID int, code, content, startDate string) int {
	t.Helper()

	if _, err := db.Exec(`DELETE FROM employee.project WHERE project_code = ?`, code); err != nil {
		t.Fatalf("failed to cleanup project fixture: %v", err)
	}
	res, err := db.Exec(`INSERT INTO employee.project(project_code, project_start_date, project_content, business_partner_id) VALUES (?, ?, ?, ?)`,
		code, startDate, content, businessPartnerID)
	if err != nil {
		t.Fatalf("failed to insert project fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch project fixture id: %v", err)
	}
	return int(id)
}

func assertEvaluationTrendRow(t *testing.T, actual []evaluationTrendRow, expected evaluationTrendRow) {
	t.Helper()

	for _, row := range actual {
		if row.EmployeeID == expected.EmployeeID &&
			row.Year == expected.Year &&
			row.Quarter == expected.Quarter &&
			row.EmployeeCode == expected.EmployeeCode &&
			row.EmployeeName == expected.EmployeeName &&
			row.Evaluation == expected.Evaluation &&
			row.PreviousEvaluation == expected.PreviousEvaluation &&
			row.EvaluationDiff == expected.EvaluationDiff &&
			row.IsLatest == expected.IsLatest {
			return
		}
	}

	t.Fatalf("expected evaluation trend row not found: %+v", expected)
}

func assertAssignmentHistoryRow(t *testing.T, actual []assignmentHistoryRow, employeeID int, employeeCode, employeeName, historyType, historyName, startDate, endDate string) {
	t.Helper()

	for _, row := range actual {
		if row.EmployeeID != employeeID || row.EmployeeCode != employeeCode || row.EmployeeName != employeeName || row.HistoryType != historyType || row.HistoryName != historyName {
			continue
		}
		if row.StartDate.Format("2006-01-02") != startDate {
			continue
		}
		if endDate == "" && row.EndDate.Valid {
			continue
		}
		if endDate != "" && (!row.EndDate.Valid || row.EndDate.Time.Format("2006-01-02") != endDate) {
			continue
		}
		return
	}

	t.Fatalf("expected assignment history row not found: employee_id=%d history_type=%s history_name=%s", employeeID, historyType, historyName)
}

func assertBenchRow(t *testing.T, actual []benchRow, employeeID int, employeeCode, employeeName, reason string) {
	t.Helper()

	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.BenchReasonCode == reason {
			return
		}
	}

	t.Fatalf("expected bench row not found: employee_id=%d reason=%s", employeeID, reason)
}

func assertProjectRetroRow(t *testing.T, actual []projectRetroRow, projectID int, projectCode, completionDate string, assignedMemberCount, projectRecordCount, reflectionCount, evaluationCount int) {
	t.Helper()

	for _, row := range actual {
		if row.ProjectID == projectID &&
			row.ProjectCode == projectCode &&
			row.ProjectCompletionDate.Format("2006-01-02") == completionDate &&
			row.AssignedMemberCount == assignedMemberCount &&
			row.ProjectRecordCount == projectRecordCount &&
			row.ReflectionPointRecordCount == reflectionCount &&
			row.EvaluationPointRecordCount == evaluationCount {
			return
		}
	}

	t.Fatalf("expected project retrospective row not found: project_id=%d project_code=%s", projectID, projectCode)
}

func assertAccountAuditRow(t *testing.T, actual []accountAuditRow, employeeID int, employeeCode, employeeName, employeeStatusName, issueCode string) {
	t.Helper()

	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.EmployeeStatusName == employeeStatusName &&
			row.AuditIssueCode == issueCode {
			return
		}
	}

	t.Fatalf("expected account audit row not found: employee_id=%d issue_code=%s", employeeID, issueCode)
}

func assertOrganizationStateAuditRow(t *testing.T, actual []organizationStateAuditRow, employeeID int, employeeCode, employeeName, auditScope, currentValueName, openHistoryValueName, issueCode string) {
	t.Helper()

	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.AuditScope == auditScope &&
			row.AuditIssueCode == issueCode &&
			nullStringValue(row.CurrentValueName) == currentValueName &&
			nullStringValue(row.OpenHistoryValueName) == openHistoryValueName {
			return
		}
	}

	t.Fatalf("expected organization state audit row not found: employee_id=%d scope=%s issue=%s", employeeID, auditScope, issueCode)
}

func assertRedeploymentPriorityRow(t *testing.T, actual []redeploymentPriorityRow, employeeID int, employeeCode, employeeName, assignmentStatus, redeploymentPriority string) {
	t.Helper()

	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.AssignmentStatus == assignmentStatus &&
			row.RedeploymentPriority == redeploymentPriority {
			return
		}
	}

	t.Fatalf("expected redeployment priority row not found: employee_id=%d status=%s priority=%s", employeeID, assignmentStatus, redeploymentPriority)
}

func assertProjectClosureAuditRow(t *testing.T, actual []projectClosureAuditRow, projectID int, projectCode, completionDate string, assignedMemberCount, projectRecordCount, currentBelongingCount, missingRecordCount int, issueCode string) {
	t.Helper()

	for _, row := range actual {
		if row.ProjectID == projectID &&
			row.ProjectCode == projectCode &&
			row.ProjectCompletionDate.Format("2006-01-02") == completionDate &&
			row.AssignedMemberCount == assignedMemberCount &&
			row.ProjectRecordCount == projectRecordCount &&
			row.CurrentBelongingMemberCount == currentBelongingCount &&
			row.MissingProjectRecordCount == missingRecordCount &&
			row.AuditIssueCode == issueCode {
			return
		}
	}

	t.Fatalf("expected project closure audit row not found: project_id=%d issue=%s", projectID, issueCode)
}

func assertInactiveEmployeeFollowupRow(t *testing.T, actual []inactiveEmployeeFollowupRow, employeeID int, employeeCode, employeeName, employeeStatusName, issueCode string) {
	t.Helper()

	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.EmployeeStatusName == employeeStatusName &&
			row.FollowupIssueCode == issueCode {
			return
		}
	}

	t.Fatalf("expected inactive employee followup row not found: employee_id=%d issue=%s", employeeID, issueCode)
}

func assertEvaluationCoverageRow(t *testing.T, actual []evaluationCoverageRow, employeeID int, employeeCode, employeeName string, expectedQuarterCount, registeredQuarterCount int, missingQuarterList, issueCode string) {
	t.Helper()

	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.ExpectedQuarterCount == expectedQuarterCount &&
			row.RegisteredQuarterCount == registeredQuarterCount &&
			row.MissingQuarterList == missingQuarterList &&
			row.CoverageIssueCode == issueCode {
			return
		}
	}
	t.Fatalf("expected evaluation coverage row not found: employee_id=%d issue=%s", employeeID, issueCode)
}

func assertProjectSkillCoverageRow(t *testing.T, actual []projectSkillCoverageRow, projectID int, projectCode string, assignedMemberCount, highSkillMemberCount int, ratio string, missingSkillCategoryCount int, riskLevel string) {
	t.Helper()

	for _, row := range actual {
		if row.ProjectID == projectID &&
			row.ProjectCode == projectCode &&
			row.AssignedMemberCount == assignedMemberCount &&
			row.HighSkillMemberCount == highSkillMemberCount &&
			row.HighSkillCoverageRatio == ratio &&
			row.MissingSkillCategoryCount == missingSkillCategoryCount &&
			row.StaffingRiskLevel == riskLevel {
			return
		}
	}
	t.Fatalf("expected project skill coverage row not found: project_id=%d", projectID)
}

func assertRehireCandidateRow(t *testing.T, actual []rehireCandidateRow, employeeID int, employeeCode, employeeName, retirementDate string, returningPermission bool, latestEvaluation sql.NullInt64, highSkillCount int, contactBucket, priority string) {
	t.Helper()

	for _, row := range actual {
		if row.EmployeeID == employeeID &&
			row.EmployeeCode == employeeCode &&
			row.EmployeeName == employeeName &&
			row.RetirementDate.Format("2006-01-02") == retirementDate &&
			row.ReturningPermission == returningPermission &&
			row.LatestEvaluation == latestEvaluation &&
			row.HighSkillCount == highSkillCount &&
			row.ContactBucket == contactBucket &&
			row.RehirePriority == priority {
			return
		}
	}
	t.Fatalf("expected rehire candidate row not found: employee_id=%d", employeeID)
}

func nullStringValue(v sql.NullString) string {
	if !v.Valid {
		return ""
	}
	return v.String
}
