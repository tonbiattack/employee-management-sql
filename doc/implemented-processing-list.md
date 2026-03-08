# 実装済み処理一覧

このファイルは、現在の Go バッチ実装で扱っている主な業務処理を一覧化したものです。  
対象実装: `internal/usecase/employee_status_transition.go` / `cmd/employee_status_transition.go`

## 社員ステータス遷移

- `TransitionActiveToRetired`
  - 現役社員を退職社員へ遷移
  - 退職イベント（`retirement`）記録
  - 退職社員情報（`retired_employee`）記録
  - 連絡先を退職向けへ移行（現役/休職連絡先を解除）
  - 所属（会社・部署・課・チーム・案件）を解除

- `TransitionActiveToLeave`
  - 現役社員を休職社員へ遷移
  - 休職イベント（`leave_of_absence`）記録
  - 休職連絡先（`contact_information_for_staff_on_leave`）を設定
  - 現役連絡先/認証情報（`ownership`/`password`/`active_employee_contact_information`）を解除
  - 所属（会社・部署・課・チーム・案件）を解除

- `TransitionRetiredToActive`
  - 退職社員を現役社員へ復職
  - 復職イベント（`reinstatement`）記録
  - 復職可否（`retired_employee.returning_permission`）確認
  - 必要に応じて会社所属を再設定（`belonging_company` / `company_assignment`）
  - 現役連絡先を復元し、休職/退職連絡先を解除

## 基礎ビジネス処理

- `AssignEmployeeToProject`
  - 現役社員のみ案件アサイン可能
  - 既存所属（`belonging_project`）がある場合はエラー
  - 案件配属イベント（`assignment_project`）記録 + 所属案件（`belonging_project`）作成

- `ChangeCurrentPosition`
  - 現役社員のみ役職変更可能
  - 現役職（`current_position`）更新
  - 役職就任履歴（`assumption_of_position`）記録

- `RegisterEvaluation`
  - 現役社員のみ評価登録可能
  - 四半期（1-4）バリデーション
  - 同一社員・年・四半期の重複登録を禁止

- `TransferOrganizationBelonging`
  - 所属移管（`department` / `division` / `team`）
  - 旧組織IDから新組織IDへ所属レコードを一括更新

## 組織解体時の所属解除（別ユースケース）

- `ResetBelongingsByOrganizationDismantle`
  - 解体対象配下の社員を抽出（`department` / `division` / `team`）
  - 対象社員の所属（部署・課・チーム）を一括解除
  - MySQL 制約回避のため、一時テーブルに対象社員を固定して削除

## CLI コマンド（Cobra）

- `employee-status-transition active-to-retired`
- `employee-status-transition active-to-leave`
- `employee-status-transition retired-to-active`
- `employee-status-transition assign-project`
- `employee-status-transition change-position`
- `employee-status-transition register-evaluation`
- `employee-status-transition transfer-belonging`
