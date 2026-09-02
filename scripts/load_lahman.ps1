$ErrorActionPreference = 'Stop'

$Snow      = "$env:APPDATA\Python\Python313\Scripts\snow.exe"
$Conn      = 'wax_baseball'
# The CSVs are not kept in any repo (ruled 2026-09-02): download the bundle from
# https://sabr.org/lahman-database/, unzip to %USERPROFILE%\Downloads\lahman_1871-2025_csv
# (or set LAHMAN_DIR), and verify against wax-system\wax-baseball\lahman-2025\MANIFEST.sha256.
$LahmanDir = if ($env:LAHMAN_DIR) { $env:LAHMAN_DIR } else { Join-Path $env:USERPROFILE 'Downloads\lahman_1871-2025_csv' }
$Stage     = '@~/lahman'
$SqlDir    = Join-Path $PSScriptRoot '..\sql'

if (-not (Test-Path $LahmanDir)) { throw "Lahman dir not found: $LahmanDir -- download https://sabr.org/lahman-database/, unzip there (or set LAHMAN_DIR), verify with sha256sum -c against wax-system\wax-baseball\lahman-2025\MANIFEST.sha256" }
if (-not (Test-Path $Snow))      { throw "snow.exe not found: $Snow" }

Write-Host "==> 1. Setup (DATABASE / SCHEMA / FILE FORMAT)" -ForegroundColor Cyan
& $Snow sql -c $Conn -f (Join-Path $SqlDir '01_setup.sql')
if ($LASTEXITCODE -ne 0) { throw "01_setup.sql failed (exit $LASTEXITCODE)" }

$csvs = Get-ChildItem $LahmanDir -Filter *.csv | Sort-Object Name

Write-Host "`n==> 2. PUT $($csvs.Count) CSVs to $Stage" -ForegroundColor Cyan
foreach ($csv in $csvs) {
    $posix = $csv.FullName.Replace('\','/')
    Write-Host "    PUT $($csv.Name)"
    & $Snow sql -c $Conn -q "PUT 'file://$posix' $Stage AUTO_COMPRESS=TRUE OVERWRITE=TRUE"
    if ($LASTEXITCODE -ne 0) { throw "PUT failed for $($csv.Name)" }
}

Write-Host "`n==> 3. CREATE TABLE + COPY INTO per CSV" -ForegroundColor Cyan
foreach ($csv in $csvs) {
    $table   = [System.IO.Path]::GetFileNameWithoutExtension($csv.Name)
    $staged  = "$Stage/$($csv.Name).gz"
    Write-Host "    $table"

    $createSql = @"
CREATE OR REPLACE TABLE BASEBALL.LAHMAN_RAW.$table
USING TEMPLATE (
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
  FROM TABLE(
    INFER_SCHEMA(
      LOCATION      => '$staged',
      FILE_FORMAT   => 'BASEBALL.LAHMAN_RAW.csv_with_header'
    )
  )
);
"@
    & $Snow sql -c $Conn -q $createSql
    if ($LASTEXITCODE -ne 0) { throw "CREATE TABLE failed for $table" }

    $copySql = @"
COPY INTO BASEBALL.LAHMAN_RAW.$table
FROM $staged
FILE_FORMAT          = (FORMAT_NAME = 'BASEBALL.LAHMAN_RAW.csv_with_header')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR             = 'ABORT_STATEMENT';
"@
    & $Snow sql -c $Conn -q $copySql
    if ($LASTEXITCODE -ne 0) { throw "COPY INTO failed for $table" }
}

Write-Host "`n==> 4. Done. Run smoke tests:" -ForegroundColor Green
Write-Host "    $Snow sql -c $Conn -f $(Join-Path $SqlDir '02_smoke_tests.sql')"
