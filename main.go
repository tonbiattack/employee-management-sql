package main

import (
	"fmt"
	"os"

	"employee-management-sql/cmd"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func main() {
	dsn := os.Getenv("MYSQL_BATCH_DSN")
	if dsn == "" {
		dsn = "root:mysql@tcp(127.0.0.1:3306)/employee?charset=utf8mb4&parseTime=true"
	}

	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		fmt.Fprintln(os.Stderr, "failed to open mysql:", err)
		os.Exit(1)
	}
	sqlDB, err := db.DB()
	if err != nil {
		fmt.Fprintln(os.Stderr, "failed to get sql db:", err)
		os.Exit(1)
	}
	defer sqlDB.Close()
	if err := sqlDB.Ping(); err != nil {
		fmt.Fprintln(os.Stderr, "failed to connect mysql:", err)
		os.Exit(1)
	}

	root := cmd.NewRootCommand(db)
	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
