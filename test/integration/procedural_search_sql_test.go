package integration_test

import (
	"bufio"
	"database/sql"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestEmployeeRedeploymentPriorityProceduralSQL(t *testing.T) {
	t.Run("再配置優先度_手続き版でも同じ候補を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareRedeploymentFixture(t, db.SQL)

		rows := querySearchScript(t, db.SQL, "employee_redeployment_priority_procedural.sql")
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
				t.Fatalf("failed to scan procedural redeployment priority row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating procedural redeployment priority rows: %v", err)
		}

		assertRedeploymentPriorityRow(t, actual, 1, "56001", "田嶋研人", "PROJECT_UNASSIGNED", "HIGH")
		assertRedeploymentPriorityRow(t, actual, 2, "11000", "中田あやか", "TEAM_UNASSIGNED", "MEDIUM")
	})
}

func TestInactiveEmployeeFollowupQueueProceduralSQL(t *testing.T) {
	t.Run("休職退職者フォローアップ_手続き版でも課題を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareInactiveEmployeeFollowupFixture(t, db.SQL)

		rows := querySearchScript(t, db.SQL, "inactive_employee_followup_queue_procedural.sql")
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
				t.Fatalf("failed to scan procedural inactive employee row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating procedural inactive employee rows: %v", err)
		}

		assertInactiveEmployeeFollowupRow(t, actual, 3, "33000", "橘まゆみ", "休職社員", "INACTIVE_HAS_LOGIN")
		assertInactiveEmployeeFollowupRow(t, actual, 3, "33000", "橘まゆみ", "休職社員", "INACTIVE_STILL_HAS_BELONGING")
		assertInactiveEmployeeFollowupRow(t, actual, 5, "57003", "河合陽子", "退職社員", "RETIRED_ELIGIBLE_FOR_REHIRE_REVIEW")
	})
}

func TestOrgDismantleImpactSummaryProceduralSQL(t *testing.T) {
	t.Run("組織解体影響_手続き版でも同じ要約を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareOrgDismantleImpactFixture(t, db.SQL)

		rows := querySearchScript(t, db.SQL, "org_dismantle_impact_summary_procedural.sql")
		defer rows.Close()

		var actual []orgDismantleImpactRow
		for rows.Next() {
			var row orgDismantleImpactRow
			if err := rows.Scan(&row.OrganizationType, &row.OrganizationID, &row.OrganizationName, &row.AffectedEmployeeCount, &row.ActiveProjectMemberCount, &row.HighSkillEmployeeCount, &row.ImpactRiskLevel); err != nil {
				t.Fatalf("failed to scan procedural org impact row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating procedural org impact rows: %v", err)
		}

		assertOrgDismantleImpactRow(t, actual, "TEAM", fixture.TeamID, fixture.TeamName, 2, 1, 2, "HIGH")
	})
}

func TestPositionStagnationAlertProceduralSQL(t *testing.T) {
	t.Run("役職停滞アラート_手続き版でも同じ社員を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := preparePositionStagnationFixture(t, db.SQL)

		rows := querySearchScript(t, db.SQL, "position_stagnation_alert_procedural.sql")
		defer rows.Close()

		var actual []positionStagnationRow
		for rows.Next() {
			var row positionStagnationRow
			if err := rows.Scan(&row.EmployeeID, &row.EmployeeCode, &row.EmployeeName, &row.PositionName, &row.StartDate, &row.MonthsInPosition, &row.LatestEvaluation, &row.AlertLevel); err != nil {
				t.Fatalf("failed to scan procedural position stagnation row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating procedural position stagnation rows: %v", err)
		}

		assertPositionStagnationRow(t, actual, 1, "56001", "田嶋研人", fixture.PositionName, "2023-01-01", 24, sql.NullInt64{Int64: 4, Valid: true}, "HIGH")
	})
}

func TestLeaveReturnFollowupSummaryProceduralSQL(t *testing.T) {
	t.Run("復職後フォローアップ_手続き版でも同じ課題を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareLeaveReturnFollowupFixture(t, db.SQL)

		rows := querySearchScript(t, db.SQL, "leave_return_followup_summary_procedural.sql")
		defer rows.Close()

		var actual []leaveReturnFollowupRow
		for rows.Next() {
			var row leaveReturnFollowupRow
			if err := rows.Scan(&row.EmployeeID, &row.EmployeeCode, &row.EmployeeName, &row.ReinstatementDate, &row.CurrentOrganizationCount, &row.CurrentProjectCount, &row.PostReturnEvaluationCount, &row.IssueCode); err != nil {
				t.Fatalf("failed to scan procedural leave return row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating procedural leave return rows: %v", err)
		}

		assertLeaveReturnFollowupRow(t, actual, 5, "57003", "河合陽子", "2028-01-15", 1, 0, 0, "POST_RETURN_PROJECT_MISSING")
		assertLeaveReturnFollowupRow(t, actual, 5, "57003", "河合陽子", "2028-01-15", 1, 0, 0, "POST_RETURN_EVALUATION_MISSING")
	})
}

func TestProjectSkillCoverageGapProceduralSQL(t *testing.T) {
	t.Run("案件スキル充足ギャップ_手続き版でも同じ結果を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		fixture := prepareProjectSkillCoverageFixture(t, db.SQL)

		rows := querySearchScript(t, db.SQL, "project_skill_coverage_gap_procedural.sql")
		defer rows.Close()

		var actual []projectSkillCoverageRow
		for rows.Next() {
			var row projectSkillCoverageRow
			if err := rows.Scan(&row.ProjectID, &row.ProjectCode, &row.AssignedMemberCount, &row.HighSkillMemberCount, &row.HighSkillCoverageRatio, &row.MissingSkillCategoryCount, &row.StaffingRiskLevel); err != nil {
				t.Fatalf("failed to scan procedural project skill coverage row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating procedural project skill coverage rows: %v", err)
		}

		assertProjectSkillCoverageRow(t, actual, fixture.ProjectID, fixture.ProjectCode, 2, 1, "0.50", 0, "MEDIUM")
	})
}

func TestRehireCandidatePoolProceduralSQL(t *testing.T) {
	t.Run("再雇用候補_手続き版でも同じ候補を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareRehireCandidateFixture(t, db.SQL)

		rows := querySearchScript(t, db.SQL, "rehire_candidate_pool_procedural.sql")
		defer rows.Close()

		var actual []rehireCandidateRow
		for rows.Next() {
			var row rehireCandidateRow
			if err := rows.Scan(&row.EmployeeID, &row.EmployeeCode, &row.EmployeeName, &row.RetirementDate, &row.ReturningPermission, &row.LatestEvaluation, &row.HighSkillCount, &row.ContactBucket, &row.RehirePriority); err != nil {
				t.Fatalf("failed to scan procedural rehire candidate row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating procedural rehire candidate rows: %v", err)
		}

		assertRehireCandidateRow(t, actual, 5, "57003", "河合陽子", "2027-03-31", true, sql.NullInt64{Int64: 8, Valid: true}, 2, "RETIRED_CONTACT", "HIGH")
	})
}

func TestEvaluationCoverageAuditProceduralSQL(t *testing.T) {
	t.Run("評価登録漏れ_手続き版でも同じ欠番を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareEvaluationCoverageFixture(t, db.SQL)

		rows := querySearchScript(t, db.SQL, "evaluation_coverage_audit_procedural.sql")
		defer rows.Close()

		var actual []evaluationCoverageRow
		for rows.Next() {
			var row evaluationCoverageRow
			if err := rows.Scan(&row.EmployeeID, &row.EmployeeCode, &row.EmployeeName, &row.ExpectedQuarterCount, &row.RegisteredQuarterCount, &row.MissingQuarterList, &row.CoverageIssueCode); err != nil {
				t.Fatalf("failed to scan procedural evaluation coverage row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating procedural evaluation coverage rows: %v", err)
		}

		assertEvaluationCoverageRow(t, actual, 1, "56001", "田嶋研人", 4, 2, "2027-Q2,2027-Q4", "EVALUATION_QUARTER_MISSING")
	})
}

func TestSkillGrowthSnapshotProceduralSQL(t *testing.T) {
	t.Run("スキル成長シグナル_手続き版でも同じ結果を返す", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareSkillGrowthSnapshotFixture(t, db.SQL)

		rows := querySearchScript(t, db.SQL, "skill_growth_snapshot_procedural.sql")
		defer rows.Close()

		var actual []skillGrowthSnapshotRow
		for rows.Next() {
			var row skillGrowthSnapshotRow
			if err := rows.Scan(&row.EmployeeID, &row.EmployeeCode, &row.EmployeeName, &row.TotalSkillCount, &row.HighSkillCount, &row.LatestEvaluation, &row.EvaluationDiff, &row.GrowthSignal); err != nil {
				t.Fatalf("failed to scan procedural skill growth row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating procedural skill growth rows: %v", err)
		}

		assertSkillGrowthSnapshotRow(t, actual, 1, "56001", "田嶋研人", 8, 3, sql.NullInt64{Int64: 8, Valid: true}, sql.NullInt64{Int64: 2, Valid: true}, "GROWING")
	})
}

func querySearchScript(t *testing.T, db *sql.Tx, fileName string) *sql.Rows {
	t.Helper()

	statements := loadSearchScriptStatements(t, fileName)
	if len(statements) == 0 {
		t.Fatalf("no executable statements found in %s", fileName)
	}

	for _, statement := range statements[:len(statements)-1] {
		if _, err := db.Exec(statement); err != nil {
			t.Fatalf("failed to execute search script statement in %s: %v\nstatement:\n%s", fileName, err, statement)
		}
	}

	rows, err := db.Query(statements[len(statements)-1])
	if err != nil {
		t.Fatalf("failed to execute final query in %s: %v", fileName, err)
	}
	return rows
}

func loadSearchScriptStatements(t *testing.T, fileName string) []string {
	t.Helper()

	_, testFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("failed to detect test file path")
	}

	queryPath := filepath.Join(filepath.Dir(testFile), "..", "..", "sql", "search", fileName)
	file, err := os.Open(queryPath)
	if err != nil {
		t.Fatalf("failed to open search script %s: %v", fileName, err)
	}
	defer file.Close()

	var (
		statements []string
		builder    strings.Builder
	)

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		builder.WriteString(line)
		builder.WriteString("\n")
		if strings.HasSuffix(strings.TrimSpace(line), ";") {
			statement := strings.TrimSpace(builder.String())
			statement = strings.TrimSuffix(statement, ";")
			if statement != "" {
				statements = append(statements, statement)
			}
			builder.Reset()
		}
	}
	if err := scanner.Err(); err != nil {
		t.Fatalf("failed to read search script %s: %v", fileName, err)
	}

	if trailing := strings.TrimSpace(builder.String()); trailing != "" {
		statements = append(statements, trailing)
	}

	return statements
}
