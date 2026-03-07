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
