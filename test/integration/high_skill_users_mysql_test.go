package integration_test

import (
	"database/sql"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	_ "github.com/go-sql-driver/mysql"
)

type highSkillRow struct {
	EmployeeID   int
	EmployeeCode string
	EmployeeName string
	SkillType    string
	SkillName    string
	SkillLevel   int
}

func TestListHighSkillUsersMySQL(t *testing.T) {
	t.Run("ハイスキルユーザー取得_スキル種別とレベルを返す", func(t *testing.T) {
		db := openMySQLForTest(t)
		query := loadHighSkillQuery(t)

		rows, err := db.Query(query)
		if err != nil {
			t.Fatalf("failed to query high skill users: %v", err)
		}
		defer rows.Close()

		var actual []highSkillRow
		for rows.Next() {
			var row highSkillRow
			if err := rows.Scan(
				&row.EmployeeID,
				&row.EmployeeCode,
				&row.EmployeeName,
				&row.SkillType,
				&row.SkillName,
				&row.SkillLevel,
			); err != nil {
				t.Fatalf("failed to scan row: %v", err)
			}
			actual = append(actual, row)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("failed while iterating rows: %v", err)
		}

		expected := []highSkillRow{
			{EmployeeID: 1, EmployeeCode: "56001", EmployeeName: "田嶋研人", SkillType: "DATABASE", SkillName: "DynamoDB", SkillLevel: 10},
			{EmployeeID: 1, EmployeeCode: "56001", EmployeeName: "田嶋研人", SkillType: "PROGRAMMING", SkillName: "C言語", SkillLevel: 9},
			{EmployeeID: 1, EmployeeCode: "56001", EmployeeName: "田嶋研人", SkillType: "PROGRAMMING", SkillName: "C#", SkillLevel: 8},
			{EmployeeID: 2, EmployeeCode: "11000", EmployeeName: "中田あやか", SkillType: "FRAMEWORK", SkillName: "Spring Boot", SkillLevel: 8},
		}

		if len(actual) != len(expected) {
			t.Fatalf("unexpected row count: got %d, want %d", len(actual), len(expected))
		}

		for i := range expected {
			if actual[i] != expected[i] {
				t.Fatalf("unexpected row at index %d: got %+v, want %+v", i, actual[i], expected[i])
			}
		}
	})
}

func openMySQLForTest(t *testing.T) *sql.DB {
	t.Helper()

	dsn := os.Getenv("MYSQL_TEST_DSN")
	if dsn == "" {
		dsn = "root:mysql@tcp(127.0.0.1:3306)/employee?charset=utf8mb4&parseTime=true"
	}

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		t.Fatalf("failed to open mysql connection: %v", err)
	}
	t.Cleanup(func() {
		_ = db.Close()
	})

	if err := db.Ping(); err != nil {
		t.Fatalf("failed to connect mysql: %v", err)
	}

	return db
}

func loadHighSkillQuery(t *testing.T) string {
	t.Helper()

	_, testFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("failed to detect test file path")
	}

	queryPath := filepath.Join(filepath.Dir(testFile), "..", "..", "sql", "search", "high_skill_users_search.sql")
	queryBytes, err := os.ReadFile(queryPath)
	if err != nil {
		t.Fatalf("failed to read query file: %v", err)
	}

	return string(queryBytes)
}
