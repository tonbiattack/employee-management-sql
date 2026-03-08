# employee-management-sql

https://github.com/tonbiattack/employee-management

の SQL 一式を取り込み、PostgreSQL / MySQL で動かして検証するためのプロジェクトです。

## 取り込んだSQL

- `sql/*.sql`
  - Spring プロジェクト直下 `sql/` の検索系SQLなど
- `sql/spring_boot_resources/*.sql`
  - Spring プロジェクト `src/main/resources/*.sql` のSQL
  - `schema.sql` / `data.sql` / テーブル別SQL

## データ投入の流れ（ER図の代替）

このプロジェクトは、`docker/*-init/01-schema.sql` でテーブルを作成し、
`docker/*-init/02-data.sql` でデータを投入します。  
投入は、外部キーで参照される側から順に入るようにしています。

1. マスタ系（参照される土台）
- `employee_status`, `gender`, `position`, `role`
- `database_skill`, `framework_skill`, `infrastructure_skill`, `programming_skill`
- `business_partner`, `company`, `department`, `division`, `team`, `project`

2. 社員の基本情報
- `employee`
- `employee_address`
- `employee_contact_information`

3. 認証・連絡先の業務利用情報
- `active_employee_contact_information`
- `password`
- `ownership`

4. 所属・配属の現在値
- `belonging_company`, `belonging_department`, `belonging_division`, `belonging_team`, `belonging_project`
- `current_position`

5. スキル情報
- `employee_database_skill`
- `employee_framework_skill`
- `employee_infrastructure_skill`
- `employee_programming_skill`

6. イベント・履歴系
- `joining_the_company`
- `company_assignment`（`company_assignment_date` / `company_assignment_end_date`）
- `assigned_department`（`assigned_department_date` / `assigned_department_end_date`）
- `assigned_division`（`assigned_division_date` / `assigned_division_end_date`）
- `assigned_team`（`assigned_team_date` / `assigned_team_end_date`）
- `assignment_project`（`assignment_project_date` / `assignment_project_end_date`）
- `assumption_of_position`（`assumption_of_position_date` / `assumption_of_position_end_date`）
- `assumption_of_position`
- `assignment_project`, `assigned_department`, `assigned_division`, `assigned_team`
- `leave_of_absence`, `reinstatement`, `retirement`, `retired_employee`
- `contact_information_for_staff_on_leave`, `retired_employee_contact_information`
- `evaluation`, `employee_project_record`, `project_completion_report`

ポイント:
- 「現在値テーブル」と「履歴/イベントテーブル」は役割を分けて運用します。
- ER図を固定で維持する代わりに、投入順と状態遷移（どのイベントでどのテーブルが更新されるか）を基準に読むと、実装とズレにくくなります。

## 既知の設計課題（正直ベース）

このリポジトリは学習・検証用途として改善を続けています。現時点での課題を明記します。

### 1. 会社所属履歴は `end_date NULL` 許容で管理する

`company_assignment` を含む期間系テーブルに `*_end_date` を追加し、  
`NULL` は「現在も所属中」を表す運用に変更しました。

背景:
- 全領域をイミュータブルイベントで統一すると、学習・検証コストが上がりすぎる
- 一方で「いつ抜けたか」が不明だと監査性が下がる
- そのため、期間系の `end_date NULL` は必要悪として採用する

問題になりやすいケース:
- 次の配属まで未所属期間がある
- 配属解除だけ先に起きる
- 同じ会社に再配属される
- 未来日のデータを先に登録する

### 2. 現在値 + 履歴の併用方針

「現在値テーブル」と「イベント履歴テーブル」を分ける設計にする場合、  
`配属` だけでなく `離職/解除` イベントも持つ方が自然です。

例（イベント方式）:
- `company_assignment`（配属）
- `company_unassignment`（離職/解除）

### 3. このリポジトリの当面方針

配属/解除を別イベントで管理する方法も可能ですが、当面は次を採用します。

- 会社/部署/課/チーム/案件/役職の履歴を期間列で管理する
- `*_end_date IS NULL` を現行所属（継続中）とみなす
- 休職/退職時に `end_date` を埋めて未クローズ期間を一括クローズする

例（期間方式）:
- `company_assignment(employee_id, company_id, company_assignment_date, company_assignment_end_date NULL)`
- `assignment_project(employee_id, project_id, assignment_project_date, assignment_project_end_date NULL)`
- `assumption_of_position(employee_id, position_id, assumption_of_position_date, assumption_of_position_end_date NULL)`

補足:
- 配属通知・解除通知・承認履歴・操作主体（誰が実行したか）を重視する場合はイベント方式が有効です。
- 所属期間の正確な再現と検索容易性を重視する場合は期間方式を優先する方針が現実的です。
- `NULL` を含む検索は複雑化しやすいため、`IS NULL` 条件を共通化した検索SQLを用意して運用します。

## 実装処理一覧
- 実装済みの業務処理・バッチコマンド一覧: [doc/implemented-processing-list.md](doc/implemented-processing-list.md)

## すぐ動かす

### Docker Compose で起動して投入する

前提:
- Docker Desktop / Docker Engine が使えること

`compose.yml` で `docker/*-init/*.sql` を `docker-entrypoint-initdb.d` にマウントしているため、
**初回起動時は `docker compose up -d` だけでスキーマ + 初期データ投入まで完了**します。

#### PostgreSQL

```bash
docker compose up -d postgres
```

接続確認:

```bash
docker compose exec postgres psql -U postgres -d postgres -c "select count(*) from employee.employee;"
```

接続URL:

```text
postgresql://postgres:postgres@localhost:15433/postgres
```

#### MySQL

```bash
docker compose up -d mysql
```

接続確認:

```bash
docker compose exec mysql mysql -u root -pmysql -e "select count(*) as employee_count from employee.employee;"
```

接続先:

```text
host=localhost port=3306 user=root password=mysql database=employee
```

#### 初期データを入れ直す（再初期化）

```bash
docker compose down -v
docker compose up -d
```

## 補足

- PostgreSQL 初期化SQL: `docker/postgres-init/01-schema.sql` → `02-data.sql`
- MySQL 初期化SQL: `docker/mysql-init/01-schema.sql` → `02-data.sql`
- MySQL 初期化SQLは、元の `sql/spring_boot_resources/schema.sql` / `data.sql` を投入可能な形へ変換した内容です。
- `scripts/bootstrap-db.ps1` は手動投入・検証用として残しています（Dockerだけでの初期化には不要）。

## 追加SQL（MySQL）

ハイスキル（`skill_level >= 8`）の社員とスキル種別・スキル名・レベルを取得:

```bash
docker compose exec mysql mysql -u root -pmysql -D employee < sql/search/high_skill_users_search.sql
```

Go統合テスト（実DBの MySQL を使う）:

```powershell
go test -v ./test/integration
```

## おすすめSQL（分析用）

社員ごとのスキル概要（総スキル数 / ハイスキル数 / 最高レベル）:

```bash
docker compose exec mysql mysql -u root -pmysql -D employee < sql/search/employee_skill_overview.sql
```

ハイスキル分布（スキル別の人数・平均レベル）:

```bash
docker compose exec mysql mysql -u root -pmysql -D employee < sql/search/high_skill_distribution_by_skill.sql
```

未登録カテゴリ検出（社員ごとの不足カテゴリ）:

```bash
docker compose exec mysql mysql -u root -pmysql -D employee < sql/search/employee_missing_skill_category.sql
```

## ビジネスアプリ向けSQL（横断系）

先に不足データを補完（初回のみ）:

```bash
docker compose exec mysql mysql -u root -pmysql -D employee < sql/sample_business_data_for_queries.sql
```

組織 + 役職 + 案件参画数のスナップショット:

```bash
docker compose exec mysql mysql -u root -pmysql -D employee < sql/search/employee_org_project_snapshot.sql
```

案件ごとの要員・ハイスキル比率・最新評価平均:

```bash
docker compose exec mysql mysql -u root -pmysql -D employee < sql/search/project_staffing_quality_summary.sql
```

社員イベント時系列（入社・配属・休職・復職・退職）:

```bash
docker compose exec mysql mysql -u root -pmysql -D employee < sql/search/employee_event_timeline.sql
```

チームのキャパシティ/リスク要約:

```bash
docker compose exec mysql mysql -u root -pmysql -D employee < sql/search/team_capacity_risk_summary.sql
```

## Cobraバッチ（社員ステータス遷移）

現役社員を休職へ遷移:

```bash
go run . employee-status-transition active-to-leave --employee-id 1 --leave-date 2026-04-01
```

退職社員を現役へ復帰:

```bash
go run . employee-status-transition retired-to-active --employee-id 5 --reinstatement-date 2026-05-01
```

環境変数 `MYSQL_BATCH_DSN` を設定すると接続先を変更できます。
