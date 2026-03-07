param(
  # PostgreSQL / MySQL のどちらに投入するかを切り替える。
  # 練習用に両DBの違いを追いやすくするため、明示指定にしている。
  [ValidateSet("postgres", "mysql")]
  [string]$Engine = "postgres",
  # PostgreSQL をローカルの psql で叩く場合に使う接続URL。
  # docker compose 経由で実行する場合は未指定でもよい。
  [string]$DatabaseUrl = $env:DATABASE_URL,
  # docker compose 上の PostgreSQL サービス名。
  [string]$ComposeService = "postgres",
  [string]$PostgresUser = "postgres",
  [string]$PostgresDatabase = "postgres",
  # docker compose 上の MySQL サービス名。
  [string]$MySqlComposeService = "mysql",
  [string]$MySqlUser = "root",
  [string]$MySqlPassword = "mysql"
)

# スクリプト中の失敗を握りつぶさず、すぐ止める。
# SQL投入では途中失敗を見逃すと原因追跡が難しいため、早めに落とす。
$ErrorActionPreference = "Stop"

# リポジトリ内の元SQLと、一時的に生成する投入用SQLの置き場所。
# 元SQLは PostgreSQL 向けの形を保持し、DBごとの差分はここで吸収する。
$repoRoot = Split-Path -Parent $PSScriptRoot
$schemaSql = Join-Path $repoRoot "sql/spring_boot_resources/schema.sql"
$dataSql = Join-Path $repoRoot "sql/spring_boot_resources/data.sql"
$tempDir = Join-Path $repoRoot ".tmp"
$schemaBootstrapSql = Join-Path $tempDir "bootstrap-schema.sql"
$dataBootstrapSql = Join-Path $tempDir "bootstrap-data.sql"

if (-not (Test-Path $schemaSql)) {
  Write-Error "Not found: $schemaSql"
  exit 1
}

if (-not (Test-Path $dataSql)) {
  Write-Error "Not found: $dataSql"
  exit 1
}

function Test-CommandExists {
  # 外部コマンドの存在確認用。
  # psql があれば PostgreSQL はローカル実行を優先し、
  # 無ければ docker compose 経由にフォールバックする。
  param([string]$Name)

  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-LocalPsqlFile {
  # PostgreSQL 用: ローカルに入っている psql でSQLファイルを実行する。
  # 失敗時は psql の終了コードをそのまま返す。
  param([string]$SqlFile)

  & psql $DatabaseUrl -v ON_ERROR_STOP=1 -f $SqlFile
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

function Invoke-ComposePsqlFile {
  # PostgreSQL 用: docker compose のコンテナ内に標準入力でSQLを流し込む。
  # ホスト側に psql が無くても学習用DBを再現できるようにしている。
  param([string]$SqlFile)

  Get-Content -Raw $SqlFile |
    docker compose exec -T $ComposeService sh -lc "cat > /tmp/bootstrap.sql && psql -U $PostgresUser -d $PostgresDatabase -v ON_ERROR_STOP=1 -f /tmp/bootstrap.sql && rm /tmp/bootstrap.sql"
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

function Invoke-ComposeMySqlFile {
  # MySQL 用: docker compose 上の mysql クライアントでSQLを実行する。
  # 一時ファイルをコンテナ内に作ってから流すことで、複数文の投入を安定させる。
  param([string]$SqlFile)

  Get-Content -Raw $SqlFile |
    docker compose exec -T $MySqlComposeService sh -lc "cat > /tmp/bootstrap.sql && MYSQL_PWD=$MySqlPassword mysql --default-character-set=utf8mb4 -u $MySqlUser < /tmp/bootstrap.sql && rm /tmp/bootstrap.sql"
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

function Convert-PostgresSqlToMySql {
  # PostgreSQL 向けの元SQLを、学習用途で MySQL でも流せる形に寄せる。
  # ここでは「完全な方言吸収」ではなく、このリポジトリの schema.sql / data.sql が
  # 通るために必要な最小変換をまとめている。
  param(
    [string]$SqlText,
    [switch]$IsSchema
  )

  # 末尾に混入している制御文字や、PostgreSQL 専用の schema 宣言を除去する。
  $converted = $SqlText -replace [char]26, ""
  $converted = $converted -replace '(?im)^DROP SCHEMA IF EXISTS employee cascade;\r?\n', ""
  $converted = $converted -replace '(?im)^CREATE SCHEMA employee;\r?\n', ""
  # PostgreSQL のダブルクォート識別子を、MySQL のバッククォートへ変換する。
  $converted = $converted -replace '"', '`'

  if ($IsSchema) {
    # MySQL では sequence を使わず AUTO_INCREMENT で置き換える。
    $converted = $converted -replace '(?im)^CREATE SEQUENCE\s+\w+;\r?\n', ""
    $converted = $converted -replace '(?im)^drop table if exists ([a-z_]+) cascade;', 'drop table if exists $1;'
    $converted = $converted -replace "integer\s+default\s+nextval\('[^']+'\)\s+not null", "integer not null auto_increment"
    $converted = $converted -replace '(?i)character varying', 'varchar'
    # COMMENT ON は PostgreSQL 固有なので、学習用の MySQL 投入では落としている。
    $converted = $converted -replace '(?im)^comment on .+;\r?$', ''
    # MySQL で予約語扱いに近い識別子は明示的に囲う。
    $converted = $converted -replace '(?im)^create table role \(', 'create table `role` ('
    $converted = $converted -replace '(?im)^drop table if exists role;', 'drop table if exists `role`;'
    $converted = $converted -replace '(?im)^alter table role\b', 'alter table `role`'
    $converted = $converted -replace '(?i)references role\(', 'references `role`('
    $converted = $converted -replace '(?im)^create table position \(', 'create table `position` ('
    $converted = $converted -replace '(?im)^drop table if exists position;', 'drop table if exists `position`;'
    $converted = $converted -replace '(?im)^alter table position\b', 'alter table `position`'
    $converted = $converted -replace '(?i)references position\(', 'references `position`('
    $converted = $converted -replace '(?im)(\s*,\s*)year(\s+integer\s+not null)', '$1`year`$2'
    $converted = $converted -replace '(?im)(\s*,\s*)quarter(\s+integer\s+not null)', '$1`quarter`$2'
    $converted = $converted -replace '(?im)(\s*,\s*)comment(\s+text\s+not null)', '$1`comment`$2'

    # PostgreSQL の schema 相当を、MySQL では database として作り直す。
    # 外部キーを含むので、投入中は一時的に FK チェックを落としている。
    return @"
DROP DATABASE IF EXISTS employee;
CREATE DATABASE employee CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE employee;
SET FOREIGN_KEY_CHECKS = 0;
$converted
SET FOREIGN_KEY_CHECKS = 1;
"@
  }

  # DATE 'YYYY-MM-DD' は MySQL では文字列リテラルに寄せる。
  $converted = $converted -replace "DATE '([0-9-]+)'", '''$1'''
  # データ投入側で schema-qualified な予約語テーブル参照があるため個別に補正する。
  $converted = $converted -replace '(?i)employee\.`role`', 'employee.`role`'
  $converted = $converted -replace '(?i)employee\.position', 'employee.`position`'

  return @"
USE employee;
$converted
"@
}

$useLocalPsql = Test-CommandExists "psql"
$useCompose = Test-CommandExists "docker"

# PostgreSQL をローカル psql で実行する場合のみ DATABASE_URL を必須にする。
if ($Engine -eq "postgres" -and $useLocalPsql -and -not $DatabaseUrl) {
  Write-Error "DATABASE_URL is required when using local psql. Example: postgresql://postgres:postgres@localhost:5432/postgres"
  exit 1
}

# どちらの実行手段も無い場合は、このスクリプトでは先に進めない。
if (-not $useLocalPsql -and -not $useCompose) {
  Write-Error "Neither psql nor docker is available. Install psql or start PostgreSQL with docker compose."
  exit 1
}

if (-not (Test-Path $tempDir)) {
  New-Item -ItemType Directory -Path $tempDir | Out-Null
}

# 元SQLはまず丸ごと読み込んでから、DBごとの一時SQLに組み立てる。
$schemaContent = Get-Content -Raw $schemaSql
$dataContent = Get-Content -Raw $dataSql

if ($Engine -eq "postgres") {
  # PostgreSQL では schema.sql 先頭の CREATE SCHEMA に加えて search_path も補う。
  # これにより、無修飾テーブル名が employee スキーマ上に揃って作成される。
  @(
    "DROP SCHEMA IF EXISTS employee CASCADE;"
    "CREATE SCHEMA employee;"
    "SET search_path TO employee;"
    (Get-Content $schemaSql | Select-Object -Skip 2)
  ) | Set-Content -Path $schemaBootstrapSql -Encoding UTF8

  @(
    "SET search_path TO employee;"
    $dataContent
  ) | Set-Content -Path $dataBootstrapSql -Encoding UTF8
} else {
  # MySQL は元SQLをそのまま流せないため、投入専用SQLを生成してから実行する。
  Convert-PostgresSqlToMySql -SqlText $schemaContent -IsSchema |
    Set-Content -Path $schemaBootstrapSql -Encoding UTF8

  Convert-PostgresSqlToMySql -SqlText $dataContent |
    Set-Content -Path $dataBootstrapSql -Encoding UTF8
}

try {
  # どの経路で実行したかを出しておくと、学習中に「どのDBクライアントが使われたか」を追いやすい。
  if ($Engine -eq "postgres" -and $useLocalPsql) {
    Write-Host "[mode] local psql"
    Write-Host "[1/2] apply schema: $schemaSql"
    Invoke-LocalPsqlFile -SqlFile $schemaBootstrapSql
    Write-Host "[2/2] apply data: $dataSql"
    Invoke-LocalPsqlFile -SqlFile $dataBootstrapSql
  } elseif ($Engine -eq "postgres") {
    Write-Host "[mode] docker compose service: $ComposeService"
    Write-Host "[1/2] apply schema: $schemaSql"
    Invoke-ComposePsqlFile -SqlFile $schemaBootstrapSql
    Write-Host "[2/2] apply data: $dataSql"
    Invoke-ComposePsqlFile -SqlFile $dataBootstrapSql
  } else {
    Write-Host "[mode] docker compose service: $MySqlComposeService"
    Write-Host "[1/2] apply schema: $schemaSql"
    Invoke-ComposeMySqlFile -SqlFile $schemaBootstrapSql
    Write-Host "[2/2] apply data: $dataSql"
    Invoke-ComposeMySqlFile -SqlFile $dataBootstrapSql
  }
} finally {
  # 一時SQLは毎回作り直すので、最後に掃除しておく。
  Remove-Item -Path $schemaBootstrapSql -ErrorAction SilentlyContinue
  Remove-Item -Path $dataBootstrapSql -ErrorAction SilentlyContinue
}

Write-Host "Done."
