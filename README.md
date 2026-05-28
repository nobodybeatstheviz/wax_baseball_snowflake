# wax_baseball_snowflake

Loads the **SABR Lahman 2025** database into Snowflake as `BASEBALL.LAHMAN_RAW`.
Parallel to [`wax_baseball_dbt`](../wax_baseball_dbt) — Snowflake substrate for
the Lahman half of the cross-warehouse story; BigQuery holds the Retrosheet
event-level half. Future bridge: `PEOPLE."retroID"` join.

## Source

- **SABR Lahman 2025**, released 2025-12-10
- License: CC BY-SA 3.0
- Download page: https://sabr.org/lahman-database/
- CSVs (not committed; live on Drive): `G:\My Drive\001-Wax-System\wax-baseball\lahman-2025\lahman_1871-2025_csv\`
- Content pin (SHA256 per file): `G:\My Drive\001-Wax-System\wax-baseball\lahman-2025\MANIFEST.sha256`

Coverage: 1871–2025 across AL/NL + 9 historical leagues including Negro Leagues
(integrated into existing tables under their league codes, not as separate files).

## Connection

Uses Snowflake CLI connection named `wax_baseball` (see `~/.snowflake/connections.toml`).
Default warehouse `WAX_WH`, role `ACCOUNTADMIN`.

```powershell
snow connection test -c wax_baseball
```

## Run

```powershell
pwsh -File .\scripts\load_lahman.ps1
snow sql -c wax_baseball -f .\sql\02_smoke_tests.sql
```

The load script is idempotent — `CREATE OR REPLACE TABLE` per file, so re-runs
are safe and a re-run with the same source CSVs yields identical state.

## Column case

`INFER_SCHEMA + PARSE_HEADER = TRUE` preserves Lahman's camelCase header names
as quoted identifiers. **All SQL against these tables must quote them:**

```sql
SELECT "playerID", "yearID" FROM PITCHING WHERE "playerID" = 'clemero02';
```

## Refresh (annual)

1. Download new SABR CSV bundle, unzip to a new dated dir under `wax-baseball/`
2. Regenerate `MANIFEST.sha256`
3. Update `$LahmanDir` in `scripts\load_lahman.ps1`
4. Re-run the script

## Smoke tests

1. Clemens career pitching line (PITCHING + playerID lookup)
2. `retroID` population in PEOPLE (cross-warehouse bridge readiness)
3. Lahman boundary case — single-game pitcher question (documents why we need Retrosheet)
4. Negro Leagues player counts by league (SABR 2024 integration sanity)
5. 1998 Yankees season — expecting 114 regular + 11 postseason = 125 total wins
