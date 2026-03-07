# employee-management-sql

https://github.com/tonbiattack/employee-management

の SQL 一式を取り込み、PostgreSQL / MySQL で動かして検証するためのプロジェクトです。

## 取り込んだSQL

- `sql/*.sql`
  - Spring プロジェクト直下 `sql/` の検索系SQLなど
- `sql/spring_boot_resources/*.sql`
  - Spring プロジェクト `src/main/resources/*.sql` のSQL
  - `schema.sql` / `data.sql` / テーブル別SQL

## ER図
![image](https://user-images.githubusercontent.com/40497724/226085559-26d1df07-9c2b-4735-b808-91990bfb574f.png)

- データベース設計は実務の中で積めていなかった経験であり、後工程での手戻りが非常に大きくなる工程なので[WEB+DB PRESS Vol.130](https://amzn.asia/d/d9WZIUN)のイミュータブルデータモデル と[楽々ERDレッスン](https://amzn.asia/d/1hdFDWd)を参考にして何度も修正を重ねながら作成しました。

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
