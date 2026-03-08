param(
  [ValidateSet("postgres", "mysql")]
  [string]$Engine = "postgres",
  [string]$PostgresService = "postgres",
  [string]$PostgresUser = "postgres",
  [string]$PostgresDatabase = "postgres",
  [string]$MySqlService = "mysql",
  [string]$MySqlUser = "root",
  [string]$MySqlPassword = "mysql"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$postgresSql = Join-Path $repoRoot "sql/all.sql"
$mysqlSchemaSql = Join-Path $repoRoot "docker/mysql-init/01-schema.sql"
$mysqlDataSql = Join-Path $repoRoot "docker/mysql-init/02-data.sql"

function Convert-ToTrimmedText {
  param($Value)
  if ($null -eq $Value) { return "" }
  return ([string]$Value).Trim()
}

function Get-ContainerIdByName {
  param([string]$ContainerName)
  return Convert-ToTrimmedText (docker ps -aq --filter "name=^/$ContainerName$" 2>$null)
}

function Ensure-ComposeServiceReady {
  param(
    [string]$Service,
    [int]$TimeoutSeconds = 90
  )

  $preferredContainerName = "employee-management-$Service"
  function Resolve-ContainerId {
    $composeContainerId = Convert-ToTrimmedText (docker compose ps -q $Service 2>$null)
    if ($composeContainerId) { return $composeContainerId }
    return Get-ContainerIdByName -ContainerName $preferredContainerName
  }

  $containerId = Resolve-ContainerId
  $isRunning = $false
  if ($containerId) {
    $running = Convert-ToTrimmedText (docker inspect -f "{{.State.Running}}" $containerId 2>$null)
    if ($LASTEXITCODE -eq 0 -and $running -eq "true") { $isRunning = $true }
  }

  if (-not $isRunning) {
    if ($containerId) {
      docker start $containerId | Out-Null
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } else {
      docker compose up -d $Service
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
  }

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $containerId = Resolve-ContainerId
    if (-not $containerId) {
      Start-Sleep -Seconds 1
      continue
    }

    $running = Convert-ToTrimmedText (docker inspect -f "{{.State.Running}}" $containerId 2>$null)
    if ($LASTEXITCODE -ne 0 -or $running -ne "true") {
      Start-Sleep -Seconds 1
      continue
    }

    $health = Convert-ToTrimmedText (docker inspect -f "{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}" $containerId 2>$null)
    if ($LASTEXITCODE -ne 0) {
      Start-Sleep -Seconds 1
      continue
    }

    if ($health -eq "healthy" -or $health -eq "none") { return }
    if ($health -eq "unhealthy") {
      Write-Error "docker compose service '$Service' is unhealthy."
      exit 1
    }
    Start-Sleep -Seconds 2
  }

  Write-Error "Timed out waiting for docker compose service '$Service' to become ready."
  exit 1
}

function Invoke-ComposePsqlFile {
  param([string]$Service, [string]$SqlFile)
  $containerName = "employee-management-$Service"
  $fallbackContainerId = Get-ContainerIdByName -ContainerName $containerName

  Get-Content -Raw $SqlFile |
    docker compose exec -T $Service sh -lc "cat > /tmp/bootstrap.sql && psql -U $PostgresUser -d $PostgresDatabase -v ON_ERROR_STOP=1 -f /tmp/bootstrap.sql && rm /tmp/bootstrap.sql"
  if ($LASTEXITCODE -eq 0) { return }
  if (-not $fallbackContainerId) { exit $LASTEXITCODE }

  Get-Content -Raw $SqlFile |
    docker exec -i $fallbackContainerId sh -lc "cat > /tmp/bootstrap.sql && psql -U $PostgresUser -d $PostgresDatabase -v ON_ERROR_STOP=1 -f /tmp/bootstrap.sql && rm /tmp/bootstrap.sql"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Invoke-ComposeMySqlFile {
  param([string]$Service, [string]$SqlFile)
  $containerName = "employee-management-$Service"
  $fallbackContainerId = Get-ContainerIdByName -ContainerName $containerName

  Get-Content -Raw $SqlFile |
    docker compose exec -T $Service sh -lc "cat > /tmp/bootstrap.sql && MYSQL_PWD=$MySqlPassword mysql --default-character-set=utf8mb4 -u $MySqlUser < /tmp/bootstrap.sql && rm /tmp/bootstrap.sql"
  if ($LASTEXITCODE -eq 0) { return }
  if (-not $fallbackContainerId) { exit $LASTEXITCODE }

  Get-Content -Raw $SqlFile |
    docker exec -i $fallbackContainerId sh -lc "cat > /tmp/bootstrap.sql && MYSQL_PWD=$MySqlPassword mysql --default-character-set=utf8mb4 -u $MySqlUser < /tmp/bootstrap.sql && rm /tmp/bootstrap.sql"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($Engine -eq "postgres") {
  if (-not (Test-Path $postgresSql)) {
    Write-Error "Not found: $postgresSql"
    exit 1
  }
  Ensure-ComposeServiceReady -Service $PostgresService
  Invoke-ComposePsqlFile -Service $PostgresService -SqlFile $postgresSql
  Write-Host "Done: postgres bootstrap by sql/all.sql"
  exit 0
}

if (-not (Test-Path $mysqlSchemaSql)) {
  Write-Error "Not found: $mysqlSchemaSql"
  exit 1
}
if (-not (Test-Path $mysqlDataSql)) {
  Write-Error "Not found: $mysqlDataSql"
  exit 1
}

Ensure-ComposeServiceReady -Service $MySqlService
Invoke-ComposeMySqlFile -Service $MySqlService -SqlFile $mysqlSchemaSql
Invoke-ComposeMySqlFile -Service $MySqlService -SqlFile $mysqlDataSql
Write-Host "Done: mysql bootstrap by docker/mysql-init/*.sql"
