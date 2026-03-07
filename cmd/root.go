package cmd

import (
	"private-employee-management-sql/internal/usecase"

	"github.com/spf13/cobra"
	"gorm.io/gorm"
)

func NewRootCommand(db *gorm.DB) *cobra.Command {
	root := &cobra.Command{
		Use:          "employee-batch",
		SilenceUsage: true,
	}

	uc := usecase.NewEmployeeStatusTransitionUsecase(db)
	root.AddCommand(newEmployeeStatusTransitionCommand(uc))
	return root
}
