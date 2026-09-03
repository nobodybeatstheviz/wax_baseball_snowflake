# wax_baseball_snowflake

Loads the **SABR Lahman 2025** database into Snowflake as `BASEBALL.LAHMAN_RAW`.
Parallel to [`wax_baseball_dbt`](../wax_baseball_dbt) — Snowflake substrate for
the Lahman half of the cross-warehouse story; BigQuery holds the Retrosheet
event-level half. Future bridge: `PEOPLE."retroID"` join.

## Source

- **SABR Lahman 2025**, released 2025-12-10
- License: CC BY-SA 3.0
- Download page: https://sabr.org/lahman-database/
- CSVs: not kept in any repo (ruled 2026-09-02 — the engines hold the data, SABR republishes each winter). Download from the page above and unzip to `%USERPROFILE%\Downloads\lahman_1871-2025_csv` (or set `LAHMAN_DIR`)
- Release pin (SHA256 per file): `wax-system\wax-baseball\lahman-2025\MANIFEST.sha256` — verify with `sha256sum -c` inside the unzipped dir before loading

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

1. Download the new SABR CSV bundle, unzip to `%USERPROFILE%\Downloads\lahman_1871-2025_csv` (or wherever `LAHMAN_DIR` points)
2. Regenerate the pin in wax-system (`sha256sum *.csv > wax-baseball\lahman-2025\MANIFEST.sha256`) and commit it — the pin is the record of which release the engines hold
3. Re-run this script (no path edit needed), then the other two loaders (Databricks: `wax_baseball_parity\databricks\load_lahman_2025.py` · BigQuery: `wax_baseball_dbt\load_lahman_bq.py`) and the parity harness

## Keeping Score parity layer (`sql/10`–`sql/30`)

The second half of this repo: the parity corpus + its governed semantic view + a
Cortex Agent over it. Connection for all of it: `wax_baseball_key` (key-pair; MFA is
enforced on the account, so the password connection above only still works for
`snow connection test`).

| File | What | Rerun |
|---|---|---|
| `sql/10_setup_wax_baseball.sql` + `scripts/load_wax_baseball_parity.ps1` | `BASEBALL.WAX_BASEBALL` — the 8 parity marts, loaded from the Parquet the sibling `wax_baseball_parity` repo exports | after any upstream dbt change |
| `sql/15_parity_views_unquoted.sql` (**generated** by `scripts/build_unquoted_views.py`) | `BASEBALL.SEMANTICS.FCT_*` — unquoted-UPPERCASE views over the five fact tables | after a reload adds a column |
| `sql/20_semantic_view_wax_baseball.sql` | `BASEBALL.SEMANTICS.KEEPING_SCORE` — the 7 governed metrics (+2 components), over the `sql/15` views | after `sql/15` |
| `sql/30_cortex_agent_keeping_score.sql` | `BASEBALL.SEMANTICS.KEEPING_SCORE_AGENT` — one `CREATE AGENT … FROM SPECIFICATION` statement, Cortex Analyst tool bound to the semantic view | whenever the spec changes (it replaces the whole spec) |

```powershell
py .\scripts\build_unquoted_views.py
snow sql -c wax_baseball_key -f .\sql\15_parity_views_unquoted.sql
snow sql -c wax_baseball_key -f .\sql\20_semantic_view_wax_baseball.sql
snow sql -c wax_baseball_key -f .\sql\30_cortex_agent_keeping_score.sql
```

**Why the views exist (measured 2026-09-03):** the parity tables carry case-preserved
lowercase column names from `INFER_SCHEMA`, so every physical column is a quoted
identifier (`"game_id"`). Plain `SEMANTIC_VIEW()` SQL accepts that — the parity
harness passed 28/28 against the original view — but **Cortex Analyst serializes the
semantic view to its YAML model and rejects quoted names** (`error_code 392700:
invalid column name "game_id"`), so a Cortex Agent bound to it could not query at
all. Two front doors into one semantic view; one validates it, one doesn't. The
views change nothing upstream; the semantic view's logical names are unchanged, so
the harness is unaffected.

The agent is queried and traced from the sibling repo:
`wax_baseball_parity/observability/capture_snowflake_cortex_agent.py` (REST SSE
stream + `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS`, which Snowflake populates for
agent runs with no setup).

## Smoke tests

1. Clemens career pitching line (PITCHING + playerID lookup)
2. `retroID` population in PEOPLE (cross-warehouse bridge readiness)
3. Lahman boundary case — single-game pitcher question (documents why we need Retrosheet)
4. Negro Leagues player counts by league (SABR 2024 integration sanity)
5. 1998 Yankees season — expecting 114 regular + 11 postseason = 125 total wins
