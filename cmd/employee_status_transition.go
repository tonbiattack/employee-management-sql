package cmd

import (
	"context"
	"fmt"

	"employee-management-sql/internal/usecase"

	"github.com/spf13/cobra"
)

// employee-status-transition 配下に状態遷移バッチをぶら下げる。
// コマンド層は引数解釈とユースケース呼び出しに責務を限定する。
func newEmployeeStatusTransitionCommand(uc *usecase.EmployeeStatusTransitionUsecase) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "employee-status-transition",
		Short: "Batch commands for employee status transition",
	}
	cmd.AddCommand(newAssignProjectCommand(uc))
	cmd.AddCommand(newChangePositionCommand(uc))
	cmd.AddCommand(newRegisterEvaluationCommand(uc))
	cmd.AddCommand(newTransferOrganizationBelongingCommand(uc))
	cmd.AddCommand(newActiveToRetiredCommand(uc))
	cmd.AddCommand(newActiveToLeaveCommand(uc))
	cmd.AddCommand(newRetiredToActiveCommand(uc))
	return cmd
}

func newAssignProjectCommand(uc *usecase.EmployeeStatusTransitionUsecase) *cobra.Command {
	var employeeID int
	var projectID int
	var assignmentDate string

	cmd := &cobra.Command{
		Use:   "assign-project",
		Short: "Assign an active employee to a project",
		RunE: func(cmd *cobra.Command, args []string) error {
			in := usecase.AssignEmployeeToProjectInput{
				EmployeeID:     employeeID,
				ProjectID:      projectID,
				AssignmentDate: assignmentDate,
			}
			if err := uc.AssignEmployeeToProject(context.Background(), in); err != nil {
				return err
			}
			_, _ = fmt.Fprintf(cmd.OutOrStdout(), "done: assign-project employee_id=%d project_id=%d date=%s\n", employeeID, projectID, assignmentDate)
			return nil
		},
	}

	cmd.Flags().IntVar(&employeeID, "employee-id", 0, "Target employee ID")
	cmd.Flags().IntVar(&projectID, "project-id", 0, "Project ID")
	cmd.Flags().StringVar(&assignmentDate, "assignment-date", "", "Assignment date (YYYY-MM-DD)")
	_ = cmd.MarkFlagRequired("employee-id")
	_ = cmd.MarkFlagRequired("project-id")
	_ = cmd.MarkFlagRequired("assignment-date")
	return cmd
}

func newChangePositionCommand(uc *usecase.EmployeeStatusTransitionUsecase) *cobra.Command {
	var employeeID int
	var positionID int
	var assumptionDate string

	cmd := &cobra.Command{
		Use:   "change-position",
		Short: "Change current position and add assumption history",
		RunE: func(cmd *cobra.Command, args []string) error {
			in := usecase.ChangeCurrentPositionInput{
				EmployeeID:     employeeID,
				PositionID:     positionID,
				AssumptionDate: assumptionDate,
			}
			if err := uc.ChangeCurrentPosition(context.Background(), in); err != nil {
				return err
			}
			_, _ = fmt.Fprintf(cmd.OutOrStdout(), "done: change-position employee_id=%d position_id=%d date=%s\n", employeeID, positionID, assumptionDate)
			return nil
		},
	}

	cmd.Flags().IntVar(&employeeID, "employee-id", 0, "Target employee ID")
	cmd.Flags().IntVar(&positionID, "position-id", 0, "Position ID")
	cmd.Flags().StringVar(&assumptionDate, "assumption-date", "", "Assumption date (YYYY-MM-DD)")
	_ = cmd.MarkFlagRequired("employee-id")
	_ = cmd.MarkFlagRequired("position-id")
	_ = cmd.MarkFlagRequired("assumption-date")
	return cmd
}

func newRegisterEvaluationCommand(uc *usecase.EmployeeStatusTransitionUsecase) *cobra.Command {
	var employeeID int
	var year int
	var quarter int
	var comment string
	var evaluation int

	cmd := &cobra.Command{
		Use:   "register-evaluation",
		Short: "Register evaluation for an active employee",
		RunE: func(cmd *cobra.Command, args []string) error {
			in := usecase.RegisterEvaluationInput{
				EmployeeID: employeeID,
				Year:       year,
				Quarter:    quarter,
				Comment:    comment,
				Evaluation: evaluation,
			}
			if err := uc.RegisterEvaluation(context.Background(), in); err != nil {
				return err
			}
			_, _ = fmt.Fprintf(cmd.OutOrStdout(), "done: register-evaluation employee_id=%d year=%d quarter=%d\n", employeeID, year, quarter)
			return nil
		},
	}

	cmd.Flags().IntVar(&employeeID, "employee-id", 0, "Target employee ID")
	cmd.Flags().IntVar(&year, "year", 0, "Evaluation year")
	cmd.Flags().IntVar(&quarter, "quarter", 0, "Evaluation quarter (1-4)")
	cmd.Flags().StringVar(&comment, "comment", "batch evaluation", "Evaluation comment")
	cmd.Flags().IntVar(&evaluation, "evaluation", 3, "Evaluation score")
	_ = cmd.MarkFlagRequired("employee-id")
	_ = cmd.MarkFlagRequired("year")
	_ = cmd.MarkFlagRequired("quarter")
	return cmd
}

func newTransferOrganizationBelongingCommand(uc *usecase.EmployeeStatusTransitionUsecase) *cobra.Command {
	var targetType string
	var sourceID int
	var destinationID int

	cmd := &cobra.Command{
		Use:   "transfer-belonging",
		Short: "Transfer organization belonging from source to destination",
		RunE: func(cmd *cobra.Command, args []string) error {
			in := usecase.TransferOrganizationBelongingInput{
				TargetType:    targetType,
				SourceID:      sourceID,
				DestinationID: destinationID,
			}
			if err := uc.TransferOrganizationBelonging(context.Background(), in); err != nil {
				return err
			}
			_, _ = fmt.Fprintf(cmd.OutOrStdout(), "done: transfer-belonging target_type=%s source_id=%d destination_id=%d\n", targetType, sourceID, destinationID)
			return nil
		},
	}

	cmd.Flags().StringVar(&targetType, "target-type", "", "Belonging target (department|division|team)")
	cmd.Flags().IntVar(&sourceID, "source-id", 0, "Source organization ID")
	cmd.Flags().IntVar(&destinationID, "destination-id", 0, "Destination organization ID")
	_ = cmd.MarkFlagRequired("target-type")
	_ = cmd.MarkFlagRequired("source-id")
	_ = cmd.MarkFlagRequired("destination-id")
	return cmd
}

// active-to-retired は現役社員を退職へ遷移させる。
// 退職日を必須入力とし、退職理由・復職可否は任意指定できる。
func newActiveToRetiredCommand(uc *usecase.EmployeeStatusTransitionUsecase) *cobra.Command {
	var employeeID int
	var retirementDate string
	var retirementReason string
	var returningPermission bool

	cmd := &cobra.Command{
		Use:   "active-to-retired",
		Short: "Transition an active employee to retired",
		RunE: func(cmd *cobra.Command, args []string) error {
			in := usecase.TransitionActiveToRetiredInput{
				EmployeeID:          employeeID,
				RetirementDate:      retirementDate,
				RetirementReason:    retirementReason,
				ReturningPermission: returningPermission,
			}
			if err := uc.TransitionActiveToRetired(context.Background(), in); err != nil {
				return err
			}
			_, _ = fmt.Fprintf(cmd.OutOrStdout(), "done: active-to-retired employee_id=%d retirement_date=%s\n", employeeID, retirementDate)
			return nil
		},
	}

	cmd.Flags().IntVar(&employeeID, "employee-id", 0, "Target employee ID")
	cmd.Flags().StringVar(&retirementDate, "retirement-date", "", "Retirement date (YYYY-MM-DD)")
	cmd.Flags().StringVar(&retirementReason, "retirement-reason", "", "Retirement reason")
	cmd.Flags().BoolVar(&returningPermission, "returning-permission", true, "Whether re-employment is permitted")
	_ = cmd.MarkFlagRequired("employee-id")
	_ = cmd.MarkFlagRequired("retirement-date")

	return cmd
}

// active-to-leave は現役社員を休職へ遷移する。
// 休職日と対象社員IDは必須、休職用メールは任意指定。
func newActiveToLeaveCommand(uc *usecase.EmployeeStatusTransitionUsecase) *cobra.Command {
	var employeeID int
	var leaveDate string
	var leaveCompanyEmail string

	cmd := &cobra.Command{
		Use:   "active-to-leave",
		Short: "Transition an active employee to leave-of-absence",
		RunE: func(cmd *cobra.Command, args []string) error {
			// CLI引数をユースケース入力へ詰め替えて実行する。
			in := usecase.TransitionActiveToLeaveInput{
				EmployeeID:        employeeID,
				LeaveDate:         leaveDate,
				LeaveCompanyEmail: leaveCompanyEmail,
			}
			if err := uc.TransitionActiveToLeave(context.Background(), in); err != nil {
				return err
			}
			_, _ = fmt.Fprintf(cmd.OutOrStdout(), "done: active-to-leave employee_id=%d leave_date=%s\n", employeeID, leaveDate)
			return nil
		},
	}

	cmd.Flags().IntVar(&employeeID, "employee-id", 0, "Target employee ID")
	cmd.Flags().StringVar(&leaveDate, "leave-date", "", "Leave date (YYYY-MM-DD)")
	cmd.Flags().StringVar(&leaveCompanyEmail, "leave-company-email", "", "Optional leave contact company email")
	_ = cmd.MarkFlagRequired("employee-id")
	_ = cmd.MarkFlagRequired("leave-date")

	return cmd
}

// retired-to-active は退職社員を現役へ復職させる。
// 復職日は履歴登録に使うため必須入力にしている。
func newRetiredToActiveCommand(uc *usecase.EmployeeStatusTransitionUsecase) *cobra.Command {
	var employeeID int
	var reinstatementDate string
	var reinstatedCompanyID int
	var reinstatedCompanyEmail string
	var reinstatedCompanyPhone string

	cmd := &cobra.Command{
		Use:   "retired-to-active",
		Short: "Transition a retired employee to active",
		RunE: func(cmd *cobra.Command, args []string) error {
			// CLI引数をユースケース入力へ詰め替えて実行する。
			in := usecase.TransitionRetiredToActiveInput{
				EmployeeID:             employeeID,
				ReinstatementDate:      reinstatementDate,
				ReinstatedCompanyID:    reinstatedCompanyID,
				ReinstatedCompanyEmail: reinstatedCompanyEmail,
				ReinstatedCompanyPhone: reinstatedCompanyPhone,
			}
			if err := uc.TransitionRetiredToActive(context.Background(), in); err != nil {
				return err
			}
			_, _ = fmt.Fprintf(cmd.OutOrStdout(), "done: retired-to-active employee_id=%d reinstatement_date=%s\n", employeeID, reinstatementDate)
			return nil
		},
	}

	cmd.Flags().IntVar(&employeeID, "employee-id", 0, "Target employee ID")
	cmd.Flags().StringVar(&reinstatementDate, "reinstatement-date", "", "Reinstatement date (YYYY-MM-DD)")
	cmd.Flags().IntVar(&reinstatedCompanyID, "company-id", 0, "Company ID to re-assign on reinstatement")
	cmd.Flags().StringVar(&reinstatedCompanyEmail, "company-email", "", "Company email for reinstated active contact")
	cmd.Flags().StringVar(&reinstatedCompanyPhone, "company-phone", "", "Company phone for reinstated active contact")
	_ = cmd.MarkFlagRequired("employee-id")
	_ = cmd.MarkFlagRequired("reinstatement-date")

	return cmd
}
