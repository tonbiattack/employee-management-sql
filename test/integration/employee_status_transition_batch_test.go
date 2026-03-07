package integration_test

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	batchcmd "private-employee-management-sql/cmd"
	"private-employee-management-sql/internal/usecase"

	_ "github.com/go-sql-driver/mysql"
	gormmysql "gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// ユースケースを直接呼び出し、状態遷移の結果をDB状態で検証する統合テスト。
func TestEmployeeStatusTransitionUsecase(t *testing.T) {
	t.Run("現役社員を退職へ遷移できる", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareTransitionFixtures(t, db.SQL)

		uc := usecase.NewEmployeeStatusTransitionUsecase(db.GORM)
		err := uc.TransitionActiveToRetired(context.Background(), usecase.TransitionActiveToRetiredInput{
			EmployeeID:          1,
			RetirementDate:      "2026-03-31",
			RetirementReason:    "integration test",
			ReturningPermission: true,
		})
		if err != nil {
			t.Fatalf("TransitionActiveToRetired() error: %v", err)
		}

		assertEmployeeStatus(t, db.SQL, 1, 3)
		assertRetirementEvent(t, db.SQL, 1, "2026-03-31")
		assertRetiredEmployee(t, db.SQL, 1, true)
		assertNoBelongingOrg(t, db.SQL, 1)
		assertContactState(t, db.SQL, 1, 0, 0, 1)
	})

	t.Run("現役社員を休職へ遷移できる", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareTransitionFixtures(t, db.SQL)

		uc := usecase.NewEmployeeStatusTransitionUsecase(db.GORM)
		err := uc.TransitionActiveToLeave(context.Background(), usecase.TransitionActiveToLeaveInput{
			EmployeeID:        1,
			LeaveDate:         "2026-04-01",
			LeaveCompanyEmail: "",
		})
		if err != nil {
			t.Fatalf("TransitionActiveToLeave() error: %v", err)
		}

		assertEmployeeStatus(t, db.SQL, 1, 2)
		assertLeaveEvent(t, db.SQL, 1, "2026-04-01")
		assertNoBelongingOrg(t, db.SQL, 1)
		assertContactState(t, db.SQL, 1, 0, 1, 0)
	})

	t.Run("退職社員を現役へ遷移できる", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareTransitionFixtures(t, db.SQL)

		uc := usecase.NewEmployeeStatusTransitionUsecase(db.GORM)
		err := uc.TransitionRetiredToActive(context.Background(), usecase.TransitionRetiredToActiveInput{
			EmployeeID:        5,
			ReinstatementDate: "2026-05-01",
		})
		if err != nil {
			t.Fatalf("TransitionRetiredToActive() error: %v", err)
		}

		assertEmployeeStatus(t, db.SQL, 5, 1)
		assertReinstatementEvent(t, db.SQL, 5, "2026-05-01")
	})
}

// Cobraコマンド経由で実行しても、同じ状態遷移が成立することを検証する。
func TestEmployeeStatusTransitionBatchCommand(t *testing.T) {
	t.Run("cobraバッチで現役から退職へ遷移できる", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareTransitionFixtures(t, db.SQL)

		root := batchcmd.NewRootCommand(db.GORM)
		root.SetArgs([]string{
			"employee-status-transition",
			"active-to-retired",
			"--employee-id", "1",
			"--retirement-date", "2026-03-31",
			"--retirement-reason", "batch test",
		})

		if err := root.Execute(); err != nil {
			t.Fatalf("batch command execute error: %v", err)
		}

		assertEmployeeStatus(t, db.SQL, 1, 3)
		assertRetirementEvent(t, db.SQL, 1, "2026-03-31")
		assertRetiredEmployee(t, db.SQL, 1, true)
		assertNoBelongingOrg(t, db.SQL, 1)
		assertContactState(t, db.SQL, 1, 0, 0, 1)
	})

	t.Run("cobraバッチで現役から休職へ遷移できる", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareTransitionFixtures(t, db.SQL)

		root := batchcmd.NewRootCommand(db.GORM)
		root.SetArgs([]string{
			"employee-status-transition",
			"active-to-leave",
			"--employee-id", "1",
			"--leave-date", "2026-06-01",
		})

		if err := root.Execute(); err != nil {
			t.Fatalf("batch command execute error: %v", err)
		}

		assertEmployeeStatus(t, db.SQL, 1, 2)
		assertLeaveEvent(t, db.SQL, 1, "2026-06-01")
		assertNoBelongingOrg(t, db.SQL, 1)
		assertContactState(t, db.SQL, 1, 0, 1, 0)
	})
}

func TestBasicBusinessUsecases(t *testing.T) {
	t.Run("現役社員へ案件アサインできる", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareTransitionFixtures(t, db.SQL)
		projectID := getOrCreateProjectID(t, db.SQL)
		if _, err := db.SQL.Exec(`DELETE FROM employee.belonging_project WHERE employee_id = ?`, 1); err != nil {
			t.Fatalf("failed to cleanup belonging project: %v", err)
		}

		uc := usecase.NewEmployeeStatusTransitionUsecase(db.GORM)
		err := uc.AssignEmployeeToProject(context.Background(), usecase.AssignEmployeeToProjectInput{
			EmployeeID:     1,
			ProjectID:      projectID,
			AssignmentDate: "2026-07-01",
		})
		if err != nil {
			t.Fatalf("AssignEmployeeToProject() error: %v", err)
		}

		assertCountByQuery(t, db.SQL, `SELECT COUNT(*) FROM employee.belonging_project WHERE employee_id = ? AND project_id = ?`, 1, projectID)
		assertCountByQuery(t, db.SQL, `SELECT COUNT(*) FROM employee.assignment_project WHERE employee_id = ? AND project_id = ? AND assignment_project_date = ?`, 1, projectID, "2026-07-01")
	})

	t.Run("現役社員の現在役職を変更できる", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareTransitionFixtures(t, db.SQL)
		positionID := getOrCreatePositionID(t, db.SQL)

		uc := usecase.NewEmployeeStatusTransitionUsecase(db.GORM)
		err := uc.ChangeCurrentPosition(context.Background(), usecase.ChangeCurrentPositionInput{
			EmployeeID:     1,
			PositionID:     positionID,
			AssumptionDate: "2026-07-15",
		})
		if err != nil {
			t.Fatalf("ChangeCurrentPosition() error: %v", err)
		}

		assertCountByQuery(t, db.SQL, `SELECT COUNT(*) FROM employee.current_position WHERE employee_id = ? AND position_id = ?`, 1, positionID)
		assertCountByQuery(t, db.SQL, `SELECT COUNT(*) FROM employee.assumption_of_position WHERE employee_id = ? AND position_id = ? AND assumption_of_position_date = ?`, 1, positionID, "2026-07-15")
	})

	t.Run("現役社員の評価を四半期単位で登録できる", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareTransitionFixtures(t, db.SQL)
		if _, err := db.SQL.Exec(`DELETE FROM employee.evaluation WHERE employee_id = ? AND year = ? AND quarter = ?`, 1, 2026, 2); err != nil {
			t.Fatalf("failed to cleanup evaluation fixture: %v", err)
		}

		uc := usecase.NewEmployeeStatusTransitionUsecase(db.GORM)
		err := uc.RegisterEvaluation(context.Background(), usecase.RegisterEvaluationInput{
			EmployeeID: 1,
			Year:       2026,
			Quarter:    2,
			Comment:    "integration",
			Evaluation: 4,
		})
		if err != nil {
			t.Fatalf("RegisterEvaluation() error: %v", err)
		}

		assertCountByQuery(t, db.SQL, `SELECT COUNT(*) FROM employee.evaluation WHERE employee_id = ? AND year = ? AND quarter = ?`, 1, 2026, 2)
	})

	t.Run("所属チームを移管できる", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		prepareTransitionFixtures(t, db.SQL)
		sourceTeamID, destinationTeamID := getOrCreateTwoTeamIDs(t, db.SQL)
		if _, err := db.SQL.Exec(`DELETE FROM employee.belonging_team WHERE employee_id = ?`, 1); err != nil {
			t.Fatalf("failed to cleanup team belonging: %v", err)
		}
		if _, err := db.SQL.Exec(`INSERT INTO employee.belonging_team(team_id, employee_id) VALUES (?, ?)`, sourceTeamID, 1); err != nil {
			t.Fatalf("failed to setup source team belonging: %v", err)
		}

		uc := usecase.NewEmployeeStatusTransitionUsecase(db.GORM)
		err := uc.TransferOrganizationBelonging(context.Background(), usecase.TransferOrganizationBelongingInput{
			TargetType:    "team",
			SourceID:      sourceTeamID,
			DestinationID: destinationTeamID,
		})
		if err != nil {
			t.Fatalf("TransferOrganizationBelonging() error: %v", err)
		}

		assertCountByQuery(t, db.SQL, `SELECT COUNT(*) FROM employee.belonging_team WHERE employee_id = ? AND team_id = ?`, 1, destinationTeamID)
	})
}

// テストでSQL検証とGORMユースケース呼び出しを両立するため、両接続を保持する。
type transitionTestDB struct {
	SQL  *sql.DB
	GORM *gorm.DB
}

func openMySQLForTransitionTest(t *testing.T) *transitionTestDB {
	t.Helper()

	dsn := os.Getenv("MYSQL_TEST_DSN")
	if dsn == "" {
		dsn = "root:mysql@tcp(127.0.0.1:3306)/employee?charset=utf8mb4&parseTime=true"
	}

	// 生SQLアサーション用に database/sql を開く。
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		t.Fatalf("failed to open mysql: %v", err)
	}
	t.Cleanup(func() {
		_ = db.Close()
	})

	if err := db.Ping(); err != nil {
		t.Fatalf("failed to ping mysql: %v", err)
	}

	// 同一接続を使って GORM ハンドルを作成し、ユースケース実行に利用する。
	gdb, err := gorm.Open(gormmysql.New(gormmysql.Config{
		Conn:                      db,
		SkipInitializeWithVersion: true,
	}), &gorm.Config{})
	if err != nil {
		t.Fatalf("failed to open gorm mysql: %v", err)
	}

	return &transitionTestDB{
		SQL:  db,
		GORM: gdb,
	}
}

func prepareTransitionFixtures(t *testing.T, db *sql.DB) {
	t.Helper()

	// 毎回同じ初期データから始めるため、DBを再投入する。
	bootstrapMySQL(t)

	// テスト前提の社員状態に揃える。
	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 1 WHERE employee_id = 1`); err != nil {
		t.Fatalf("failed to reset employee 1: %v", err)
	}
	if _, err := db.Exec(`UPDATE employee.employee SET employee_status_id = 3 WHERE employee_id = 5`); err != nil {
		t.Fatalf("failed to reset employee 5: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.leave_of_absence WHERE employee_id IN (1, 5)`); err != nil {
		t.Fatalf("failed to cleanup leave events: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.reinstatement WHERE employee_id IN (1, 5)`); err != nil {
		t.Fatalf("failed to cleanup reinstatement events: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.retirement WHERE employee_id IN (1, 5)`); err != nil {
		t.Fatalf("failed to cleanup retirement events: %v", err)
	}
	if _, err := db.Exec(`DELETE FROM employee.retired_employee WHERE employee_id IN (1, 5)`); err != nil {
		t.Fatalf("failed to cleanup retired employee records: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.retirement(employee_id, retirement_reason, retirement_date) VALUES (5, 'fixture retired', '2026-03-01')`); err != nil {
		t.Fatalf("failed to setup retirement fixture for employee 5: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO employee.retired_employee(employee_id, returning_permission) VALUES (5, true)`); err != nil {
		t.Fatalf("failed to setup retired employee fixture for employee 5: %v", err)
	}
}

func bootstrapMySQL(t *testing.T) {
	t.Helper()

	_, testFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("failed to detect test file path")
	}

	repoRoot := filepath.Join(filepath.Dir(testFile), "..", "..")
	// Docker上のMySQLを起動して、マウント済み初期化SQLを直接再投入する。
	if _, err := runCommand(repoRoot, "docker", "compose", "up", "-d", "mysql"); err != nil {
		t.Fatalf("failed to start mysql service: %v", err)
	}
	waitForMySQLReady(t, repoRoot)
	if _, err := runCommand(
		repoRoot,
		"docker", "compose", "exec", "-T", "mysql", "sh", "-lc",
		"MYSQL_PWD=mysql mysql --default-character-set=utf8mb4 -u root < /docker-entrypoint-initdb.d/01-schema.sql && MYSQL_PWD=mysql mysql --default-character-set=utf8mb4 -u root < /docker-entrypoint-initdb.d/02-data.sql",
	); err != nil {
		t.Fatalf("failed to bootstrap mysql by docker init sql: %v", err)
	}
	if _, err := runCommand(
		repoRoot,
		"docker", "compose", "exec", "-T", "mysql", "sh", "-lc",
		"MYSQL_PWD=mysql mysql -u root -D employee -e \"select 1\"",
	); err != nil {
		t.Fatalf("failed to verify mysql readiness: %v", err)
	}
}

func runCommand(workdir, command string, args ...string) (string, error) {
	cmd := exec.Command(command, args...)
	cmd.Dir = workdir
	out, err := cmd.CombinedOutput()
	if err != nil {
		return string(out), fmt.Errorf("%w, output: %s", err, out)
	}
	return string(out), err
}

func waitForMySQLReady(t *testing.T, workdir string) {
	t.Helper()

	deadline := time.Now().Add(90 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := runCommand(
			workdir,
			"docker", "compose", "exec", "-T", "mysql", "sh", "-lc",
			"MYSQL_PWD=mysql mysqladmin ping -h 127.0.0.1 -u root --silent",
		); err == nil {
			return
		}
		time.Sleep(2 * time.Second)
	}

	t.Fatal("mysql did not become ready in time")
}

func assertEmployeeStatus(t *testing.T, db *sql.DB, employeeID, expectedStatus int) {
	t.Helper()

	// 状態遷移の主結果(社員ステータス)を検証する。
	var status int
	if err := db.QueryRow(`SELECT employee_status_id FROM employee.employee WHERE employee_id = ?`, employeeID).Scan(&status); err != nil {
		t.Fatalf("failed to fetch employee status: %v", err)
	}
	if status != expectedStatus {
		t.Fatalf("unexpected status. got=%d want=%d", status, expectedStatus)
	}
}

func assertLeaveEvent(t *testing.T, db *sql.DB, employeeID int, leaveDate string) {
	t.Helper()

	// 休職イベント履歴が1件だけ作成されることを検証する。
	var cnt int
	if err := db.QueryRow(`SELECT COUNT(*) FROM employee.leave_of_absence WHERE employee_id = ? AND leave_of_absence_date = ?`, employeeID, leaveDate).Scan(&cnt); err != nil {
		t.Fatalf("failed to check leave event: %v", err)
	}
	if cnt != 1 {
		t.Fatalf("leave event not found. employee_id=%d leave_date=%s", employeeID, leaveDate)
	}
}

func assertReinstatementEvent(t *testing.T, db *sql.DB, employeeID int, reinstatementDate string) {
	t.Helper()

	// 復職イベント履歴が1件だけ作成されることを検証する。
	var cnt int
	if err := db.QueryRow(`SELECT COUNT(*) FROM employee.reinstatement WHERE employee_id = ? AND reinstatement_date = ?`, employeeID, reinstatementDate).Scan(&cnt); err != nil {
		t.Fatalf("failed to check reinstatement event: %v", err)
	}
	if cnt != 1 {
		t.Fatalf("reinstatement event not found. employee_id=%d reinstatement_date=%s", employeeID, reinstatementDate)
	}
}

func assertRetirementEvent(t *testing.T, db *sql.DB, employeeID int, retirementDate string) {
	t.Helper()

	var cnt int
	if err := db.QueryRow(`SELECT COUNT(*) FROM employee.retirement WHERE employee_id = ? AND retirement_date = ?`, employeeID, retirementDate).Scan(&cnt); err != nil {
		t.Fatalf("failed to check retirement event: %v", err)
	}
	if cnt != 1 {
		t.Fatalf("retirement event not found. employee_id=%d retirement_date=%s", employeeID, retirementDate)
	}
}

func assertRetiredEmployee(t *testing.T, db *sql.DB, employeeID int, expectedReturningPermission bool) {
	t.Helper()

	var returningPermission bool
	if err := db.QueryRow(`SELECT returning_permission FROM employee.retired_employee WHERE employee_id = ? ORDER BY retired_employee_id DESC LIMIT 1`, employeeID).Scan(&returningPermission); err != nil {
		t.Fatalf("failed to check retired employee: %v", err)
	}
	if returningPermission != expectedReturningPermission {
		t.Fatalf("unexpected returning permission. got=%t want=%t", returningPermission, expectedReturningPermission)
	}
}

func assertCountByQuery(t *testing.T, db *sql.DB, query string, args ...any) {
	t.Helper()

	var cnt int
	if err := db.QueryRow(query, args...).Scan(&cnt); err != nil {
		t.Fatalf("failed to query count: %v", err)
	}
	if cnt != 1 {
		t.Fatalf("unexpected count. got=%d want=1 query=%s", cnt, query)
	}
}

func getOrCreateProjectID(t *testing.T, db *sql.DB) int {
	t.Helper()

	var projectID int
	if err := db.QueryRow(`SELECT project_id FROM employee.project ORDER BY project_id LIMIT 1`).Scan(&projectID); err == nil {
		return projectID
	}

	bpID := getOrCreateBusinessPartnerID(t, db)
	res, err := db.Exec(`INSERT INTO employee.project(project_code, project_start_date, project_content, business_partner_id) VALUES (?, ?, ?, ?)`,
		"PRJ-TEST-001", "2026-01-01", "test project", bpID)
	if err != nil {
		t.Fatalf("failed to insert project fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch project id: %v", err)
	}
	return int(id)
}

func getOrCreatePositionID(t *testing.T, db *sql.DB) int {
	t.Helper()

	var positionID int
	if err := db.QueryRow(`SELECT position_id FROM employee.position ORDER BY position_id LIMIT 1`).Scan(&positionID); err == nil {
		return positionID
	}
	res, err := db.Exec(`INSERT INTO employee.position(position_code, position_name) VALUES (?, ?)`, "POS-TEST-001", "Test Position")
	if err != nil {
		t.Fatalf("failed to insert position fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch position id: %v", err)
	}
	return int(id)
}

func getOrCreateTwoTeamIDs(t *testing.T, db *sql.DB) (int, int) {
	t.Helper()

	rows, err := db.Query(`SELECT team_id FROM employee.team ORDER BY team_id LIMIT 2`)
	if err != nil {
		t.Fatalf("failed to select teams: %v", err)
	}
	defer rows.Close()
	ids := make([]int, 0, 2)
	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err != nil {
			t.Fatalf("failed to scan team id: %v", err)
		}
		ids = append(ids, id)
	}
	if len(ids) >= 2 {
		return ids[0], ids[1]
	}

	divisionID := getOrCreateDivisionID(t, db)
	for len(ids) < 2 {
		res, err := db.Exec(`INSERT INTO employee.team(division_id, team_code, team_name) VALUES (?, ?, ?)`,
			divisionID, fmt.Sprintf("TEAM-TEST-%03d", len(ids)+1), fmt.Sprintf("Test Team %d", len(ids)+1))
		if err != nil {
			t.Fatalf("failed to insert team fixture: %v", err)
		}
		id, err := res.LastInsertId()
		if err != nil {
			t.Fatalf("failed to fetch team id: %v", err)
		}
		ids = append(ids, int(id))
	}
	return ids[0], ids[1]
}

func getOrCreateDivisionID(t *testing.T, db *sql.DB) int {
	t.Helper()

	var divisionID int
	if err := db.QueryRow(`SELECT division_id FROM employee.division ORDER BY division_id LIMIT 1`).Scan(&divisionID); err == nil {
		return divisionID
	}

	companyID := getOrCreateCompanyID(t, db)
	departmentID := getOrCreateDepartmentID(t, db, companyID)
	businessPartnerID := getOrCreateBusinessPartnerID(t, db)
	res, err := db.Exec(`INSERT INTO employee.division(department_id, division_code, division_name, business_partner_id) VALUES (?, ?, ?, ?)`,
		departmentID, "DIV-TEST-001", "Test Division", businessPartnerID)
	if err != nil {
		t.Fatalf("failed to insert division fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch division id: %v", err)
	}
	return int(id)
}

func getOrCreateDepartmentID(t *testing.T, db *sql.DB, companyID int) int {
	t.Helper()

	var departmentID int
	if err := db.QueryRow(`SELECT department_id FROM employee.department ORDER BY department_id LIMIT 1`).Scan(&departmentID); err == nil {
		return departmentID
	}
	res, err := db.Exec(`INSERT INTO employee.department(company_id, department_code, department_name) VALUES (?, ?, ?)`,
		companyID, "DEP-TEST-001", "Test Department")
	if err != nil {
		t.Fatalf("failed to insert department fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch department id: %v", err)
	}
	return int(id)
}

func getOrCreateCompanyID(t *testing.T, db *sql.DB) int {
	t.Helper()

	var companyID int
	if err := db.QueryRow(`SELECT company_id FROM employee.company ORDER BY company_id LIMIT 1`).Scan(&companyID); err == nil {
		return companyID
	}
	res, err := db.Exec(`INSERT INTO employee.company(company_code, company_name, company_business_content) VALUES (?, ?, ?)`,
		"COMP-TEST-001", "Test Company", "Test Content")
	if err != nil {
		t.Fatalf("failed to insert company fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch company id: %v", err)
	}
	return int(id)
}

func getOrCreateBusinessPartnerID(t *testing.T, db *sql.DB) int {
	t.Helper()

	var bpID int
	if err := db.QueryRow(`SELECT business_partner_id FROM employee.business_partner ORDER BY business_partner_id LIMIT 1`).Scan(&bpID); err == nil {
		return bpID
	}
	res, err := db.Exec(`INSERT INTO employee.business_partner(business_partner_code, business_partner_name) VALUES (?, ?)`,
		"BP-TEST-001", "Test Business Partner")
	if err != nil {
		t.Fatalf("failed to insert business partner fixture: %v", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		t.Fatalf("failed to fetch business partner id: %v", err)
	}
	return int(id)
}

func assertNoBelongingOrg(t *testing.T, db *sql.DB, employeeID int) {
	t.Helper()

	checks := []string{
		`SELECT COUNT(*) FROM employee.belonging_company WHERE employee_id = ?`,
		`SELECT COUNT(*) FROM employee.belonging_department WHERE employee_id = ?`,
		`SELECT COUNT(*) FROM employee.belonging_division WHERE employee_id = ?`,
		`SELECT COUNT(*) FROM employee.belonging_team WHERE employee_id = ?`,
	}
	for _, q := range checks {
		var cnt int
		if err := db.QueryRow(q, employeeID).Scan(&cnt); err != nil {
			t.Fatalf("failed to check belonging cleanup: %v", err)
		}
		if cnt != 0 {
			t.Fatalf("belonging records should be removed. query=%s employee_id=%d count=%d", q, employeeID, cnt)
		}
	}
}

func assertContactState(t *testing.T, db *sql.DB, employeeID, expectedActive, expectedLeave, expectedRetired int) {
	t.Helper()

	var activeCnt int
	if err := db.QueryRow(`
SELECT COUNT(*)
  FROM employee.active_employee_contact_information a
  INNER JOIN employee.employee_contact_information eci
    ON eci.employee_contact_information_id = a.employee_contact_information_id
 WHERE eci.employee_id = ?`, employeeID).Scan(&activeCnt); err != nil {
		t.Fatalf("failed to check active contact count: %v", err)
	}
	if activeCnt != expectedActive {
		t.Fatalf("unexpected active contact count. got=%d want=%d", activeCnt, expectedActive)
	}

	var leaveCnt int
	if err := db.QueryRow(`
SELECT COUNT(*)
  FROM employee.contact_information_for_staff_on_leave l
  INNER JOIN employee.employee_contact_information eci
    ON eci.employee_contact_information_id = l.employee_contact_information_id
 WHERE eci.employee_id = ?`, employeeID).Scan(&leaveCnt); err != nil {
		t.Fatalf("failed to check leave contact count: %v", err)
	}
	if leaveCnt != expectedLeave {
		t.Fatalf("unexpected leave contact count. got=%d want=%d", leaveCnt, expectedLeave)
	}

	var retiredCnt int
	if err := db.QueryRow(`
SELECT COUNT(*)
  FROM employee.retired_employee_contact_information r
  INNER JOIN employee.employee_contact_information eci
    ON eci.employee_contact_information_id = r.employee_contact_information_id
 WHERE eci.employee_id = ?`, employeeID).Scan(&retiredCnt); err != nil {
		t.Fatalf("failed to check retired contact count: %v", err)
	}
	if retiredCnt != expectedRetired {
		t.Fatalf("unexpected retired contact count. got=%d want=%d", retiredCnt, expectedRetired)
	}
}
