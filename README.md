# employee-management-sql

`employee-management` https://github.com/tonbiattack/employee-management の SQL 一式を取り込み、PostgreSQL で動かして検証するためのプロジェクトです。

## 取り込んだSQL

- `sql/*.sql`
  - Spring プロジェクト直下 `sql/` の検索系SQLなど
- `sql/spring_boot_resources/*.sql`
  - Spring プロジェクト `src/main/resources/*.sql` のSQL
  - `schema.sql` / `data.sql` / テーブル別SQL

## すぐ動かす

### Docker Compose で起動して投入する

前提:
- Docker Desktop / Docker Engine が使えること

#### PostgreSQL

1. PostgreSQL を起動

```powershell
docker compose up -d postgres
```

2. スキーマ+初期データを投入

```powershell
.\scripts\bootstrap-db.ps1 -Engine postgres
```

3. 接続確認

```powershell
docker compose exec postgres psql -U postgres -d postgres -c "select count(*) from employee.employee;"
```

接続URL:

```text
postgresql://postgres:postgres@localhost:15433/postgres
```

#### MySQL

1. MySQL を起動

```powershell
docker compose up -d mysql
```

2. スキーマ+初期データを投入

```powershell
.\scripts\bootstrap-db.ps1 -Engine mysql
```

3. 接続確認

```powershell
docker compose exec mysql mysql -u root -pmysql -e "select count(*) as employee_count from employee.employee;"
```

接続先:

```text
host=localhost port=3306 user=root password=mysql database=employee
```

### ローカルの `psql` を使う場合

前提:
- `psql` コマンドが使えること
- PostgreSQL に接続できること

1. 接続URLを環境変数に設定

```powershell
$env:DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/postgres"
```

2. スキーマ+初期データを投入

```powershell
.\scripts\bootstrap-db.ps1 -Engine postgres
```

## 補足

- セットアップは `sql/spring_boot_resources/schema.sql` → `data.sql` の順で実行します。
- `schema.sql` / `data.sql` はそのままだとスキーマ解決に差が出るため、`bootstrap-db.ps1` 側で `search_path` を補って投入しています。
- MySQL は PostgreSQL の元SQLから投入時に方言変換しています。元データのソースは `schema.sql` / `data.sql` のままです。
- `bootstrap-db.ps1` は PostgreSQL の場合、`psql` があればローカル実行を使い、無ければ `docker compose exec` にフォールバックします。

## 追加SQL（MySQL）

ハイスキル（`skill_level >= 8`）の社員とスキル種別・スキル名・レベルを取得:

```powershell
docker compose exec mysql mysql -u root -pmysql -D employee < sql/high_skill_users_search.sql
```

Go統合テスト（実DBの MySQL を使う）:

```powershell
go test -v ./test/integration
```

## おすすめSQL（分析用）

社員ごとのスキル概要（総スキル数 / ハイスキル数 / 最高レベル）:

```powershell
docker compose exec mysql mysql -u root -pmysql -D employee < sql/employee_skill_overview.sql
```

ハイスキル分布（スキル別の人数・平均レベル）:

```powershell
docker compose exec mysql mysql -u root -pmysql -D employee < sql/high_skill_distribution_by_skill.sql
```

未登録カテゴリ検出（社員ごとの不足カテゴリ）:

```powershell
docker compose exec mysql mysql -u root -pmysql -D employee < sql/employee_missing_skill_category.sql
```

## ビジネスアプリ向けSQL（横断系）

先に不足データを補完（初回のみ）:

```powershell
docker compose exec mysql mysql -u root -pmysql -D employee < sql/sample_business_data_for_queries.sql
```

組織 + 役職 + 案件参画数のスナップショット:

```powershell
docker compose exec mysql mysql -u root -pmysql -D employee < sql/employee_org_project_snapshot.sql
```

案件ごとの要員・ハイスキル比率・最新評価平均:

```powershell
docker compose exec mysql mysql -u root -pmysql -D employee < sql/project_staffing_quality_summary.sql
```

社員イベント時系列（入社・配属・休職・復職・退職）:

```powershell
docker compose exec mysql mysql -u root -pmysql -D employee < sql/employee_event_timeline.sql
```

チームのキャパシティ/リスク要約:

```powershell
docker compose exec mysql mysql -u root -pmysql -D employee < sql/team_capacity_risk_summary.sql
```
