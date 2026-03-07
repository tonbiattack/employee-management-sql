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
	EmployeeID        int
	ReinstatementDate string
}

func NewEmployeeStatusTransitionUsecase(db *gorm.DB) *EmployeeStatusTransitionUsecase {
	return &EmployeeStatusTransitionUsecase{db: db}
}

// TransitionActiveToRetired は「現役 -> 退職」への状態遷移を1トランザクションで実行する。
// 退職履歴(retirement)と退職社員情報(retired_employee)を同時に記録してイベントを紐づける。
func (u *EmployeeStatusTransitionUsecase) TransitionActiveToRetired(ctx context.Context, in TransitionActiveToRetiredInput) error {
	return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := ensureJoiningEventExists(tx, in.EmployeeID); err != nil {
			return err
		}

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

		reason := in.RetirementReason
		if reason == "" {
			reason = "batch transition"
		}
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

		return nil
	})
}

// TransitionActiveToLeave は「現役 -> 休職」への状態遷移を1トランザクションで実行する。
// 社員状態の更新、休職イベントの記録、休職中連絡先の補完までを同時に確定させる。
func (u *EmployeeStatusTransitionUsecase) TransitionActiveToLeave(ctx context.Context, in TransitionActiveToLeaveInput) error {
	return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := ensureJoiningEventExists(tx, in.EmployeeID); err != nil {
			return err
		}

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
			email := in.LeaveCompanyEmail
			if email == "" {
				email = contact.CompanyEmail
			}
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

		return nil
	})
}

// TransitionRetiredToActive は「退職 -> 現役」への復職遷移を1トランザクションで実行する。
// 復職可否を確認したうえで状態更新し、復職イベントを履歴として残す。
func (u *EmployeeStatusTransitionUsecase) TransitionRetiredToActive(ctx context.Context, in TransitionRetiredToActiveInput) error {
	return u.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		status, err := lockAndGetEmployeeStatus(tx, in.EmployeeID)
		if err != nil {
			return err
		}
		if status != 3 {
			return fmt.Errorf("employee is not retired: employee_id=%d status=%d", in.EmployeeID, status)
		}

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

		if err := tx.Exec(
			`UPDATE employee.employee
			    SET employee_status_id = 1
			  WHERE employee_id = ?`,
			in.EmployeeID,
		).Error; err != nil {
			return fmt.Errorf("update employee status to active: %w", err)
		}

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

		return nil
	})
}

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
