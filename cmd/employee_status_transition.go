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
	cmd.AddCommand(newActiveToRetiredCommand(uc))
	cmd.AddCommand(newActiveToLeaveCommand(uc))
	cmd.AddCommand(newRetiredToActiveCommand(uc))
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

	cmd := &cobra.Command{
		Use:   "retired-to-active",
		Short: "Transition a retired employee to active",
		RunE: func(cmd *cobra.Command, args []string) error {
			// CLI引数をユースケース入力へ詰め替えて実行する。
			in := usecase.TransitionRetiredToActiveInput{
				EmployeeID:        employeeID,
				ReinstatementDate: reinstatementDate,
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
	_ = cmd.MarkFlagRequired("employee-id")
	_ = cmd.MarkFlagRequired("reinstatement-date")

	return cmd
}
