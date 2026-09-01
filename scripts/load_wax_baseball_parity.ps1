# Loads the Keeping Score parity corpus (BigQuery wax_baseball_dbt marts,
# exported to local Parquet by the wax_baseball_parity repo) into Snowflake
# as BASEBALL.WAX_BASEBALL.
#
# Idempotent - CREATE OR REPLACE TABLE per file, so re-runs are safe and a
# re-run with the same source Parquet files yields identical state.
#
# Prereq: run the exporter in the sibling repo first, e.g.
#   cd C:\Users\georg\Documents\CODING\wax_baseball_parity
#   python scripts\export_bigquery.py

$ErrorActionPreference = 'Stop'

$Snow      = "$env:APPDATA\Python\Python313\Scripts\snow.exe"
$Conn      = 'wax_baseball_key'
$ParityDir = 'C:\Users\georg\Documents\CODING\wax_baseball_parity\data'
$Stage     = '@~/wax_baseball_parity'
$SqlDir    = Join-Path $PSScriptRoot '..\sql'

if (-not (Test-Path $ParityDir)) { throw "Parity data dir not found: $ParityDir (run export_bigquery.py first)" }
if (-not (Test-Path $Snow))      { throw "snow.exe not found: $Snow" }

Write-Host "==> 1. Setup (DATABASE / SCHEMA / FILE FORMAT)" -ForegroundColor Cyan
& $Snow sql -c $Conn -f (Join-Path $SqlDir '10_setup_wax_baseball.sql')
if ($LASTEXITCODE -ne 0) { throw "10_setup_wax_baseball.sql failed (exit $LASTEXITCODE)" }

$parquets = Get-ChildItem $ParityDir -Filter *.parquet | Sort-Object Name
if ($parquets.Count -eq 0) { throw "No parquet files found in $ParityDir" }

Write-Host "`n==> 2. PUT $($parquets.Count) Parquet files to $Stage" -ForegroundColor Cyan
foreach ($pq in $parquets) {
    $posix = $pq.FullName.Replace('\','/')
    Write-Host "    PUT $($pq.Name)"
    & $Snow sql -c $Conn -q "PUT 'file://$posix' $Stage AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
    if ($LASTEXITCODE -ne 0) { throw "PUT failed for $($pq.Name)" }
}

Write-Host "`n==> 3. CREATE TABLE + COPY INTO per Parquet file" -ForegroundColor Cyan
foreach ($pq in $parquets) {
    $table  = [System.IO.Path]::GetFileNameWithoutExtension($pq.Name)
    $staged = "$Stage/$($pq.Name)"
    Write-Host "    $table"

    $createSql = @"
CREATE OR REPLACE TABLE BASEBALL.WAX_BASEBALL.$table
USING TEMPLATE (
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
  FROM TABLE(
    INFER_SCHEMA(
      LOCATION      => '$staged',
      FILE_FORMAT   => 'BASEBALL.WAX_BASEBALL.parquet_format'
    )
  )
);
"@
    & $Snow sql -c $Conn -q $createSql
    if ($LASTEXITCODE -ne 0) { throw "CREATE TABLE failed for $table" }

    $copySql = @"
COPY INTO BASEBALL.WAX_BASEBALL.$table
FROM $staged
FILE_FORMAT          = (FORMAT_NAME = 'BASEBALL.WAX_BASEBALL.parquet_format')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR             = 'ABORT_STATEMENT';
"@
    & $Snow sql -c $Conn -q $copySql
    if ($LASTEXITCODE -ne 0) { throw "COPY INTO failed for $table" }
}

Write-Host "`n==> 4. Row count verification" -ForegroundColor Green
foreach ($pq in $parquets) {
    $table = [System.IO.Path]::GetFileNameWithoutExtension($pq.Name)
    & $Snow sql -c $Conn -q "SELECT '$table' AS table_name, COUNT(*) AS row_count FROM BASEBALL.WAX_BASEBALL.$table;"
}

Write-Host "`n==> Done." -ForegroundColor Green
