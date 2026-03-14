package integration_test

import "testing"

func TestOpenPeriodConstraint(t *testing.T) {
	t.Run("継続中会社配属は社員ごとに1件まで", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)
		companyID := getOrCreateCompanyID(t, db.SQL)

		if _, err := db.SQL.Exec(`DELETE FROM employee.company_assignment WHERE employee_id = ?`, 1); err != nil {
			t.Fatalf("failed to cleanup company assignment fixture: %v", err)
		}
		if _, err := db.SQL.Exec(
			`INSERT INTO employee.company_assignment(company_id, employee_id, company_assignment_date, company_assignment_end_date) VALUES (?, ?, ?, NULL)`,
			companyID, 1, "2028-01-01",
		); err != nil {
			t.Fatalf("failed to insert first open company assignment: %v", err)
		}

		_, err := db.SQL.Exec(
			`INSERT INTO employee.company_assignment(company_id, employee_id, company_assignment_date, company_assignment_end_date) VALUES (?, ?, ?, NULL)`,
			companyID, 1, "2028-02-01",
		)
		if err == nil {
			t.Fatal("expected duplicate open company assignment to fail")
		}
	})
}

func TestSchemaColumnsExist(t *testing.T) {
	t.Run("現在値監査向けの更新列と拡張列が存在する", func(t *testing.T) {
		db := openMySQLForTransitionTest(t)

		checks := []struct {
			table  string
			column string
		}{
			{table: "belonging_company", column: "updated_at"},
			{table: "belonging_department", column: "updated_at"},
			{table: "belonging_division", column: "updated_at"},
			{table: "belonging_team", column: "updated_at"},
			{table: "belonging_project", column: "updated_at"},
			{table: "current_position", column: "updated_at"},
			{table: "employee_project_record", column: "record_type"},
			{table: "employee_project_record", column: "recorded_by_employee_id"},
			{table: "employee_project_record", column: "recorded_at"},
			{table: "evaluation", column: "evaluation_year_type"},
		}

		for _, check := range checks {
			var cnt int
			if err := db.SQL.QueryRow(
				`SELECT COUNT(*)
				   FROM information_schema.columns
				  WHERE table_schema = 'employee'
				    AND table_name = ?
				    AND column_name = ?`,
				check.table, check.column,
			).Scan(&cnt); err != nil {
				t.Fatalf("failed to query information_schema for %s.%s: %v", check.table, check.column, err)
			}
			if cnt != 1 {
				t.Fatalf("column not found: %s.%s", check.table, check.column)
			}
		}
	})
}
