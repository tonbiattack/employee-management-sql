package usecase

import (
	"context"
	"fmt"

	"gorm.io/gorm"
)

type EmployeeStatusTransitionUsecase struct {
	db *gorm.DB
}

type TransitionActiveToLeaveInput struct {
	EmployeeID        int
	LeaveDate         string
	LeaveCompanyEmail string
}

type TransitionActiveToRetiredInput struct {
	EmployeeID          int
	RetirementDate      string
	RetirementReason    string
	ReturningPermission bool
}

type TransitionRetiredToActiveInput struct {
	EmployeeID             int
	ReinstatementDate      string
	ReinstatedCompanyID    int
	ReinstatedCompanyEmail string
	ReinstatedCompanyPhone string
}

type AssignEmployeeToProjectInput struct {
	EmployeeID     int
	ProjectID      int
	AssignmentDate string
}

type ChangeCurrentPositionInput struct {
	EmployeeID     int
	PositionID     int
	AssumptionDate string
}

type RegisterEvaluationInput struct {
	EmployeeID int
	Year       int
	Quarter    int
	Comment    string
	Evaluation int
}

type TransferOrganizationBelongingInput struct {
	TargetType    string
	SourceID      int
	DestinationID int
}

func NewEmployeeStatusTransitionUsecase(db *gorm.DB) *EmployeeStatusTransitionUsecase {
	return &EmployeeStatusTransitionUsecase{db: db}
}

// TransitionActiveToRetired は「現役 -> 退職」への状態遷移を1トランザクションで実行する。
// 退職履歴(retirement)と退職社員情報(retired_employee)を同時に記録してイベントを紐づける。
func (u *EmployeeStatusTransitionUsecase) TransitionActiveToRetired(ctx context.Context, in TransitionActiveToRetiredInput) error {
	// 状態更新と履歴記録を分離せず、1トランザクションで原子的に扱う。
	return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 入社イベントがある社員のみを遷移対象にする。
		if err := ensureJoiningEventExists(tx, in.EmployeeID); err != nil {
			return err
		}

		// FOR UPDATE で対象社員行をロックし、同時遷移競合を防ぐ。
		status, err := lockAndGetEmployeeStatus(tx, in.EmployeeID)
		if err != nil {
			return err
		}
		if status != 1 {
			return fmt.Errorf("employee is not active: employee_id=%d status=%d", in.EmployeeID, status)
		}

		if err := tx.Exec(
			`UPDATE employee.employee
			    SET employee_status_id = 3
			  WHERE employee_id = ?`,
			in.EmployeeID,
		).Error; err != nil {
			return fmt.Errorf("update employee status to retired: %w", err)
		}

		// 退職理由が未指定でも履歴の必須列を満たすために既定値を補完する。
		reason := in.RetirementReason
		if reason == "" {
			reason = "batch transition"
		}
		// 同日の退職イベントを重複作成しないように冪等INSERTする。
		if err := tx.Exec(
			`INSERT INTO employee.retirement (
			     employee_id,
			     retirement_reason,
			     retirement_date
			 )
			 SELECT ?, ?, ?
			 WHERE NOT EXISTS (
			     SELECT 1
			       FROM employee.retirement
			      WHERE employee_id = ?
			        AND retirement_date = ?
			 )`,
			in.EmployeeID, reason, in.RetirementDate, in.EmployeeID, in.RetirementDate,
		).Error; err != nil {
			return fmt.Errorf("insert retirement event: %w", err)
		}

		// 退職社員マスタも同様に冪等化し、再実行時の重複を回避する。
		if err := tx.Exec(
			`INSERT INTO employee.retired_employee (
			     employee_id,
			     returning_permission
			 )
			 SELECT ?, ?
			 WHERE NOT EXISTS (
			     SELECT 1
			       FROM employee.retired_employee
			      WHERE employee_id = ?
			 )`,
			in.EmployeeID, in.ReturningPermission, in.EmployeeID,
		).Error; err != nil {
			return fmt.Errorf("insert retired employee: %w", err)
		}

		// 退職時は社員連絡先を退職連絡先へ寄せ、現役/休職連絡先からは外す。
		if err := tx.Exec(
			`INSERT INTO employee.retired_employee_contact_information (employee_contact_information_id)
			 SELECT eci.employee_contact_information_id
			   FROM employee.employee_contact_information eci
			  WHERE eci.employee_id = ?
			    AND NOT EXISTS (
			        SELECT 1
			          FROM employee.retired_employee_contact_information reci
			         WHERE reci.employee_contact_information_id = eci.employee_contact_information_id
			    )`,
			in.EmployeeID,
		).Error; err != nil {
			return fmt.Errorf("insert retired contact info: %w", err)
		}
		if err := clearActiveContactAndPassword(tx, in.EmployeeID); err != nil {
			return err
		}
		if err := tx.Exec(
			`DELETE l
			   FROM employee.contact_information_for_staff_on_leave l
			   INNER JOIN employee.employee_contact_information eci
			     ON eci.employee_contact_information_id = l.employee_contact_information_id
			  WHERE eci.employee_id = ?`,
			in.EmployeeID,
		).Error; err != nil {
			return fmt.Errorf("remove leave contact info: %w", err)
		}

		// 退職遷移後は所属組織（会社/部署/課/チーム等）から外す。
		// 期間管理のため、未クローズの配属/就任履歴に end_date を設定してから所属を解除する。
		if err := closeOpenPeriodRecordsOnUnassignment(tx, in.EmployeeID, in.RetirementDate); err != nil {
			return err
		}
		if err := clearOrganizationBelongings(tx, in.EmployeeID); err != nil {
			return err
		}

		return nil
	})
}

// TransitionActiveToLeave は「現役 -> 休職」への状態遷移を1トランザクションで実行する。
// 社員状態の更新、休職イベントの記録、休職中連絡先の補完までを同時に確定させる。
func (u *EmployeeStatusTransitionUsecase) TransitionActiveToLeave(ctx context.Context, in TransitionActiveToLeaveInput) error {
	// 休職遷移に関わる更新をひとまとまりで確定させる。
	return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 入社履歴がない不整合データを遷移対象外にする。
		if err := ensureJoiningEventExists(tx, in.EmployeeID); err != nil {
			return err
		}

		// 対象行をロックして現ステータスを判定する。
		status, err := lockAndGetEmployeeStatus(tx, in.EmployeeID)
		if err != nil {
			return err
		}
		if status != 1 {
			return fmt.Errorf("employee is not active: employee_id=%d status=%d", in.EmployeeID, status)
		}

		if err := tx.Exec(
			`UPDATE employee.employee
			    SET employee_status_id = 2
			  WHERE employee_id = ?`,
			in.EmployeeID,
		).Error; err != nil {
			return fmt.Errorf("update employee status to leave: %w", err)
		}

		// 休職イベントは employee_id + leave_date 単位で重複防止する。
		if err := tx.Exec(
			`INSERT INTO employee.leave_of_absence (
			     employee_id,
			     leave_of_absence_date
			 )
			 SELECT ?, ?
			 WHERE NOT EXISTS (
			     SELECT 1
			       FROM employee.leave_of_absence
			      WHERE employee_id = ?
			        AND leave_of_absence_date = ?
			 )`,
			in.EmployeeID, in.LeaveDate, in.EmployeeID, in.LeaveDate,
		).Error; err != nil {
			return fmt.Errorf("insert leave event: %w", err)
		}

		// 現役時点の連絡先を1件拾って、休職連絡先へ引き継ぐ。
		var contact struct {
			EmployeeContactInformationID int    `gorm:"column:employee_contact_information_id"`
			CompanyEmail                 string `gorm:"column:company_email"`
		}
		err = tx.Raw(
			`SELECT aeci.employee_contact_information_id, aeci.company_email
			   FROM employee.active_employee_contact_information aeci
			   INNER JOIN employee.employee_contact_information eci
			     ON eci.employee_contact_information_id = aeci.employee_contact_information_id
			  WHERE eci.employee_id = ?
			  ORDER BY aeci.active_employee_contact_information_id
			  LIMIT 1`,
			in.EmployeeID,
		).Scan(&contact).Error
		if err != nil {
			return fmt.Errorf("select leave contact info: %w", err)
		}

		if contact.EmployeeContactInformationID != 0 {
			// 明示指定がなければ現役メールをそのまま休職連絡先として使う。
			email := in.LeaveCompanyEmail
			if email == "" {
				email = contact.CompanyEmail
			}
			// 休職連絡先も冪等INSERTで重複行を避ける。
			if err := tx.Exec(
				`INSERT INTO employee.contact_information_for_staff_on_leave (
				     employee_contact_information_id,
				     company_email
				 )
				 SELECT ?, ?
				 WHERE NOT EXISTS (
				     SELECT 1
				       FROM employee.contact_information_for_staff_on_leave
				      WHERE employee_contact_information_id = ?
				 )`,
				contact.EmployeeContactInformationID, email, contact.EmployeeContactInformationID,
			).Error; err != nil {
				return fmt.Errorf("insert leave contact info: %w", err)
			}
		}

		// 休職遷移後は現役連絡先を外す（連絡先は休職テーブル側で管理）。
		if err := clearActiveContactAndPassword(tx, in.EmployeeID); err != nil {
			return err
		}

		// 休職遷移後は所属組織（会社/部署/課/チーム等）から外す。
		// 期間管理のため、未クローズの配属/就任履歴に end_date を設定してから所属を解除する。
		if err := closeOpenPeriodRecordsOnUnassignment(tx, in.EmployeeID, in.LeaveDate); err != nil {
			return err
		}
		if err := clearOrganizationBelongings(tx, in.EmployeeID); err != nil {
			return err
		}

		return nil
	})
}

// TransitionRetiredToActive は「退職 -> 現役」への復職遷移を1トランザクションで実行する。
// 復職可否を確認したうえで状態更新し、復職イベントを履歴として残す。
func (u *EmployeeStatusTransitionUsecase) TransitionRetiredToActive(ctx context.Context, in TransitionRetiredToActiveInput) error {
	// 復職可否判定・状態更新・履歴記録を同一トランザクションで実行する。
	return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 退職社員のみ復職対象とする。
		status, err := lockAndGetEmployeeStatus(tx, in.EmployeeID)
		if err != nil {
			return err
		}
		if status != 3 {
			return fmt.Errorf("employee is not retired: employee_id=%d status=%d", in.EmployeeID, status)
		}

		// 退職履歴が存在しない場合は業務的に復職不可とする。
		var hasRetirement int
		if err := tx.Raw(
			`SELECT EXISTS (
			     SELECT 1
			       FROM employee.retirement
			      WHERE employee_id = ?
			 )`,
			in.EmployeeID,
		).Scan(&hasRetirement).Error; err != nil {
			return fmt.Errorf("check retirement event existence: %w", err)
		}
		if hasRetirement == 0 {
			return fmt.Errorf("retirement event not found: employee_id=%d", in.EmployeeID)
		}

		// 最新の退職社員レコードで復職許可フラグを確認する。
		var retired struct {
			ReturningPermission *bool `gorm:"column:returning_permission"`
		}
		err = tx.Raw(
			`SELECT returning_permission
			   FROM employee.retired_employee
			  WHERE employee_id = ?
			  ORDER BY retired_employee_id DESC
			  LIMIT 1`,
			in.EmployeeID,
		).Scan(&retired).Error
		if err != nil {
			return fmt.Errorf("select returning permission: %w", err)
		}
		if retired.ReturningPermission != nil && !*retired.ReturningPermission {
			return fmt.Errorf("returning is not permitted: employee_id=%d", in.EmployeeID)
		}

		// 社員状態を現役へ戻す。
		if err := tx.Exec(
			`UPDATE employee.employee
			    SET employee_status_id = 1
			  WHERE employee_id = ?`,
			in.EmployeeID,
		).Error; err != nil {
			return fmt.Errorf("update employee status to active: %w", err)
		}

		// 復職履歴は同日重複を防ぎつつ記録する。
		if err := tx.Exec(
			`INSERT INTO employee.reinstatement (
			     employee_id,
			     reinstatement_date
			 )
			 SELECT ?, ?
			 WHERE NOT EXISTS (
			     SELECT 1
			       FROM employee.reinstatement
			      WHERE employee_id = ?
			        AND reinstatement_date = ?
			 )`,
			in.EmployeeID, in.ReinstatementDate, in.EmployeeID, in.ReinstatementDate,
		).Error; err != nil {
			return fmt.Errorf("insert reinstatement event: %w", err)
		}

		// 復職時は必要に応じて所属会社を再設定する。
		if in.ReinstatedCompanyID > 0 {
			if err := tx.Exec(
				`INSERT INTO employee.belonging_company (company_id, employee_id)
				 SELECT ?, ?
				 WHERE NOT EXISTS (
				     SELECT 1
				       FROM employee.belonging_company
				      WHERE employee_id = ?
				 )`,
				in.ReinstatedCompanyID, in.EmployeeID, in.EmployeeID,
			).Error; err != nil {
				return fmt.Errorf("restore belonging company: %w", err)
			}
			if err := tx.Exec(
				`INSERT INTO employee.company_assignment (company_id, employee_id, company_assignment_date, company_assignment_end_date)
				 SELECT ?, ?, ?, NULL
				 WHERE NOT EXISTS (
				     SELECT 1
				       FROM employee.company_assignment
				      WHERE employee_id = ?
				        AND company_id = ?
				        AND company_assignment_date = ?
				 )`,
				in.ReinstatedCompanyID, in.EmployeeID, in.ReinstatementDate,
				in.EmployeeID, in.ReinstatedCompanyID, in.ReinstatementDate,
			).Error; err != nil {
				return fmt.Errorf("insert company assignment: %w", err)
			}
		}

		// 復職時は現役連絡先を再作成し、休職/退職連絡先を解除する。
		var contact struct {
			EmployeeContactInformationID int    `gorm:"column:employee_contact_information_id"`
			PrivateEmail                 string `gorm:"column:private_email"`
		}
		if err := tx.Raw(
			`SELECT employee_contact_information_id, private_email
			   FROM employee.employee_contact_information
			  WHERE employee_id = ?
			  ORDER BY employee_contact_information_id
			  LIMIT 1`,
			in.EmployeeID,
		).Scan(&contact).Error; err != nil {
			return fmt.Errorf("select employee contact: %w", err)
		}
		if contact.EmployeeContactInformationID != 0 {
			companyPhone := in.ReinstatedCompanyPhone
			if companyPhone == "" {
				companyPhone = "000-0000-0000"
			}
			companyEmail := in.ReinstatedCompanyEmail
			if companyEmail == "" {
				companyEmail = contact.PrivateEmail
			}
			if err := tx.Exec(
				`INSERT INTO employee.active_employee_contact_information (employee_contact_information_id, company_phone_number, company_email)
				 SELECT ?, ?, ?
				 WHERE NOT EXISTS (
				     SELECT 1
				       FROM employee.active_employee_contact_information
				      WHERE employee_contact_information_id = ?
				 )`,
				contact.EmployeeContactInformationID, companyPhone, companyEmail, contact.EmployeeContactInformationID,
			).Error; err != nil {
				return fmt.Errorf("restore active contact info: %w", err)
			}
			if err := tx.Exec(
				`DELETE l
				   FROM employee.contact_information_for_staff_on_leave l
				  WHERE l.employee_contact_information_id = ?`,
				contact.EmployeeContactInformationID,
			).Error; err != nil {
				return fmt.Errorf("remove leave contact info on reinstatement: %w", err)
			}
			if err := tx.Exec(
				`DELETE r
				   FROM employee.retired_employee_contact_information r
				  WHERE r.employee_contact_information_id = ?`,
				contact.EmployeeContactInformationID,
			).Error; err != nil {
				return fmt.Errorf("remove retired contact info on reinstatement: %w", err)
			}
		}

		return nil
	})
}

func (u *EmployeeStatusTransitionUsecase) AssignEmployeeToProject(ctx context.Context, in AssignEmployeeToProjectInput) error {
	return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		status, err := lockAndGetEmployeeStatus(tx, in.EmployeeID)
		if err != nil {
			return err
		}
		if status != 1 {
			return fmt.Errorf("employee is not active: employee_id=%d status=%d", in.EmployeeID, status)
		}
		if exists, err := existsByQuery(tx, `SELECT EXISTS (SELECT 1 FROM employee.belonging_project WHERE employee_id = ?)`, in.EmployeeID); err != nil {
			return err
		} else if exists {
			return fmt.Errorf("employee is already assigned to project: employee_id=%d", in.EmployeeID)
		}
		if err := tx.Exec(
			`INSERT INTO employee.assignment_project (assignment_project_date, assignment_project_end_date, project_id, employee_id)
			 SELECT ?, NULL, ?, ?
			 WHERE NOT EXISTS (
			     SELECT 1
			       FROM employee.assignment_project
			      WHERE employee_id = ?
			        AND project_id = ?
			        AND assignment_project_date = ?
			 )`,
			in.AssignmentDate, in.ProjectID, in.EmployeeID,
			in.EmployeeID, in.ProjectID, in.AssignmentDate,
		).Error; err != nil {
			return fmt.Errorf("insert assignment project event: %w", err)
		}
		if err := tx.Exec(
			`INSERT INTO employee.belonging_project (project_id, employee_id)
			 VALUES (?, ?)`,
			in.ProjectID, in.EmployeeID,
		).Error; err != nil {
			return fmt.Errorf("insert belonging project: %w", err)
		}
		return nil
	})
}

func (u *EmployeeStatusTransitionUsecase) ChangeCurrentPosition(ctx context.Context, in ChangeCurrentPositionInput) error {
	return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		status, err := lockAndGetEmployeeStatus(tx, in.EmployeeID)
		if err != nil {
			return err
		}
		if status != 1 {
			return fmt.Errorf("employee is not active: employee_id=%d status=%d", in.EmployeeID, status)
		}
		if exists, err := existsByQuery(tx, `SELECT EXISTS (SELECT 1 FROM employee.position WHERE position_id = ?)`, in.PositionID); err != nil {
			return err
		} else if !exists {
			return fmt.Errorf("position not found: position_id=%d", in.PositionID)
		}
		if err := tx.Exec(`DELETE FROM employee.current_position WHERE employee_id = ?`, in.EmployeeID).Error; err != nil {
			return fmt.Errorf("delete current position: %w", err)
		}
		if err := closeOpenAssumptionOfPositionPeriods(tx, in.EmployeeID, in.AssumptionDate); err != nil {
			return err
		}
		if err := tx.Exec(
			`INSERT INTO employee.current_position (position_id, employee_id)
			 VALUES (?, ?)`,
			in.PositionID, in.EmployeeID,
		).Error; err != nil {
			return fmt.Errorf("insert current position: %w", err)
		}
		if err := tx.Exec(
			`INSERT INTO employee.assumption_of_position (
			     position_id,
			     employee_id,
			     assumption_of_position_date,
			     assumption_of_position_end_date
			 )
			 SELECT ?, ?, ?, NULL
			 WHERE NOT EXISTS (
			     SELECT 1
			       FROM employee.assumption_of_position
			      WHERE employee_id = ?
			        AND position_id = ?
			        AND assumption_of_position_date = ?
			 )`,
			in.PositionID, in.EmployeeID, in.AssumptionDate,
			in.EmployeeID, in.PositionID, in.AssumptionDate,
		).Error; err != nil {
			return fmt.Errorf("insert assumption of position event: %w", err)
		}
		return nil
	})
}

func (u *EmployeeStatusTransitionUsecase) RegisterEvaluation(ctx context.Context, in RegisterEvaluationInput) error {
	if in.Quarter < 1 || in.Quarter > 4 {
		return fmt.Errorf("invalid quarter: %d", in.Quarter)
	}
	return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		status, err := lockAndGetEmployeeStatus(tx, in.EmployeeID)
		if err != nil {
			return err
		}
		if status != 1 {
			return fmt.Errorf("employee is not active: employee_id=%d status=%d", in.EmployeeID, status)
		}
		if exists, err := existsByQuery(
			tx,
			`SELECT EXISTS (
			     SELECT 1
			       FROM employee.evaluation
			      WHERE employee_id = ?
			        AND year = ?
			        AND quarter = ?
			 )`,
			in.EmployeeID, in.Year, in.Quarter,
		); err != nil {
			return err
		} else if exists {
			return fmt.Errorf("evaluation already exists: employee_id=%d year=%d quarter=%d", in.EmployeeID, in.Year, in.Quarter)
		}
		if err := tx.Exec(
			`INSERT INTO employee.evaluation (year, quarter, comment, evaluation, employee_id)
			 VALUES (?, ?, ?, ?, ?)`,
			in.Year, in.Quarter, in.Comment, in.Evaluation, in.EmployeeID,
		).Error; err != nil {
			return fmt.Errorf("insert evaluation: %w", err)
		}
		return nil
	})
}

func (u *EmployeeStatusTransitionUsecase) TransferOrganizationBelonging(ctx context.Context, in TransferOrganizationBelongingInput) error {
	if in.SourceID <= 0 || in.DestinationID <= 0 {
		return fmt.Errorf("source/destination id must be positive")
	}
	if in.SourceID == in.DestinationID {
		return nil
	}
	return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		switch in.TargetType {
		case "team":
			if err := tx.Exec(`UPDATE employee.belonging_team SET team_id = ? WHERE team_id = ?`, in.DestinationID, in.SourceID).Error; err != nil {
				return fmt.Errorf("transfer team belonging: %w", err)
			}
		case "division":
			if err := tx.Exec(`UPDATE employee.belonging_division SET division_id = ? WHERE division_id = ?`, in.DestinationID, in.SourceID).Error; err != nil {
				return fmt.Errorf("transfer division belonging: %w", err)
			}
		case "department":
			if err := tx.Exec(`UPDATE employee.belonging_department SET department_id = ? WHERE department_id = ?`, in.DestinationID, in.SourceID).Error; err != nil {
				return fmt.Errorf("transfer department belonging: %w", err)
			}
		default:
			return fmt.Errorf("invalid target type: %s", in.TargetType)
		}
		return nil
	})
}

// ensureJoiningEventExists は、入社イベントの存在を前提条件として検証する。
func ensureJoiningEventExists(tx *gorm.DB, employeeID int) error {
	var exists int
	if err := tx.Raw(
		`SELECT EXISTS (
		     SELECT 1
		       FROM employee.joining_the_company
		      WHERE employee_id = ?
		 )`,
		employeeID,
	).Scan(&exists).Error; err != nil {
		return fmt.Errorf("check joining event existence: %w", err)
	}
	if exists == 0 {
		return fmt.Errorf("joining event not found: employee_id=%d", employeeID)
	}
	return nil
}

// lockAndGetEmployeeStatus は対象社員を FOR UPDATE でロックし、現在ステータスを返す。
// 状態遷移処理の先頭で呼び、同時実行時の不整合を防止する。
func lockAndGetEmployeeStatus(tx *gorm.DB, employeeID int) (int, error) {
	var row struct {
		EmployeeStatusID int `gorm:"column:employee_status_id"`
	}
	if err := tx.Raw(
		`SELECT employee_status_id
		   FROM employee.employee
		  WHERE employee_id = ?
		  FOR UPDATE`,
		employeeID,
	).Scan(&row).Error; err != nil {
		return 0, fmt.Errorf("select current status: %w", err)
	}
	if row.EmployeeStatusID == 0 {
		return 0, fmt.Errorf("employee not found: employee_id=%d", employeeID)
	}
	return row.EmployeeStatusID, nil
}

// clearOrganizationBelongings は、社員に紐づく所属情報をまとめて解除する。
// 組織離脱時は会社・部署・課・チーム・案件の所属を一貫して外す。
func clearOrganizationBelongings(tx *gorm.DB, employeeID int) error {
	deleteQueries := []string{
		`DELETE FROM employee.belonging_team WHERE employee_id = ?`,
		`DELETE FROM employee.belonging_division WHERE employee_id = ?`,
		`DELETE FROM employee.belonging_department WHERE employee_id = ?`,
		`DELETE FROM employee.belonging_company WHERE employee_id = ?`,
		`DELETE FROM employee.belonging_project WHERE employee_id = ?`,
	}
	for _, query := range deleteQueries {
		if err := tx.Exec(query, employeeID).Error; err != nil {
			return fmt.Errorf("clear organization belongings: %w", err)
		}
	}
	return nil
}

// closeOpenPeriodRecordsOnUnassignment は、離任時に未終了の期間系履歴へ end_date を付与する。
// 休職/退職で現所属を解除する前に履歴をクローズし、監査可能な期間データを残す。
func closeOpenPeriodRecordsOnUnassignment(tx *gorm.DB, employeeID int, endDate string) error {
	updateQueries := []struct {
		query    string
		errorMsg string
	}{
		{
			query: `UPDATE employee.company_assignment
			           SET company_assignment_end_date = ?
			         WHERE employee_id = ?
			           AND company_assignment_end_date IS NULL
			           AND company_assignment_date <= ?`,
			errorMsg: "close company assignment period",
		},
		{
			query: `UPDATE employee.assignment_project
			           SET assignment_project_end_date = ?
			         WHERE employee_id = ?
			           AND assignment_project_end_date IS NULL
			           AND assignment_project_date <= ?`,
			errorMsg: "close assignment project period",
		},
		{
			query: `UPDATE employee.assigned_department
			           SET assigned_department_end_date = ?
			         WHERE employee_id = ?
			           AND assigned_department_end_date IS NULL
			           AND assigned_department_date <= ?`,
			errorMsg: "close assigned department period",
		},
		{
			query: `UPDATE employee.assigned_division
			           SET assigned_division_end_date = ?
			         WHERE employee_id = ?
			           AND assigned_division_end_date IS NULL
			           AND assigned_division_date <= ?`,
			errorMsg: "close assigned division period",
		},
		{
			query: `UPDATE employee.assigned_team
			           SET assigned_team_end_date = ?
			         WHERE employee_id = ?
			           AND assigned_team_end_date IS NULL
			           AND assigned_team_date <= ?`,
			errorMsg: "close assigned team period",
		},
	}

	for _, q := range updateQueries {
		if err := tx.Exec(q.query, endDate, employeeID, endDate).Error; err != nil {
			return fmt.Errorf("%s: %w", q.errorMsg, err)
		}
	}

	if err := closeOpenAssumptionOfPositionPeriods(tx, employeeID, endDate); err != nil {
		return err
	}
	return nil
}

// closeOpenAssumptionOfPositionPeriods は、役職就任履歴の未終了レコードに終了日を付与する。
func closeOpenAssumptionOfPositionPeriods(tx *gorm.DB, employeeID int, endDate string) error {
	if err := tx.Exec(
		`UPDATE employee.assumption_of_position
		    SET assumption_of_position_end_date = ?
		  WHERE employee_id = ?
		    AND assumption_of_position_end_date IS NULL
		    AND assumption_of_position_date <= ?`,
		endDate, employeeID, endDate,
	).Error; err != nil {
		return fmt.Errorf("close assumption of position period: %w", err)
	}
	return nil
}

// clearActiveContactAndPassword は、現役連絡先にぶら下がる認証系データをFK順で削除する。
// 依存順は ownership -> password -> active_employee_contact_information。
// この順にしないと外部キー制約により削除エラーになる。
func clearActiveContactAndPassword(tx *gorm.DB, employeeID int) error {
	// password を参照している ownership を先に削除する。
	if err := tx.Exec(
		`DELETE o
		   FROM employee.ownership o
		   INNER JOIN employee.password p
		     ON p.password_id = o.password_id
		   INNER JOIN employee.active_employee_contact_information a
		     ON a.active_employee_contact_information_id = p.active_employee_contact_information_id
		   INNER JOIN employee.employee_contact_information eci
		     ON eci.employee_contact_information_id = a.employee_contact_information_id
		  WHERE eci.employee_id = ?`,
		employeeID,
	).Error; err != nil {
		return fmt.Errorf("remove ownership: %w", err)
	}

	// 次に active_employee_contact_information を参照している password を削除する。
	if err := tx.Exec(
		`DELETE p
		   FROM employee.password p
		   INNER JOIN employee.active_employee_contact_information a
		     ON a.active_employee_contact_information_id = p.active_employee_contact_information_id
		   INNER JOIN employee.employee_contact_information eci
		     ON eci.employee_contact_information_id = a.employee_contact_information_id
		  WHERE eci.employee_id = ?`,
		employeeID,
	).Error; err != nil {
		return fmt.Errorf("remove active password: %w", err)
	}

	// 最後に現役連絡先本体を削除する。
	if err := tx.Exec(
		`DELETE a
		   FROM employee.active_employee_contact_information a
		   INNER JOIN employee.employee_contact_information eci
		     ON eci.employee_contact_information_id = a.employee_contact_information_id
		  WHERE eci.employee_id = ?`,
		employeeID,
	).Error; err != nil {
		return fmt.Errorf("remove active contact info: %w", err)
	}

	return nil
}

func existsByQuery(tx *gorm.DB, query string, args ...any) (bool, error) {
	var exists int
	if err := tx.Raw(query, args...).Scan(&exists).Error; err != nil {
		return false, fmt.Errorf("exists query failed: %w", err)
	}
	return exists == 1, nil
}
