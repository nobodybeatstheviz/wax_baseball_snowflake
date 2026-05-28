USE DATABASE BASEBALL;
USE SCHEMA LAHMAN_RAW;

-- Row counts across all loaded tables
SELECT TABLE_NAME, ROW_COUNT
FROM BASEBALL.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'LAHMAN_RAW'
ORDER BY TABLE_NAME;

-- Smoke 1: Clemens career line (sanity that PITCHING loaded + playerID lookup works)
SELECT "yearID", "teamID", "W", "L", "ERA", "SO"
FROM PITCHING
WHERE "playerID" = 'clemero02'
ORDER BY "yearID";

-- Smoke 2: retroID population in PEOPLE (cross-warehouse bridge readiness)
SELECT
  COUNT(*) AS total_people,
  COUNT("retroID") AS with_retroid,
  ROUND(COUNT("retroID") * 100.0 / COUNT(*), 1) AS pct_with_retroid
FROM PEOPLE;

-- Smoke 3: Lahman BOUNDARY case — Clemens vs Colon, NYA 1999-07-25
-- Lahman pitching grain = season. Single-game pitcher questions need
-- Retrosheet/BigQuery. This query documents the boundary that motivates
-- the future cross-warehouse retroID bridge.
SELECT 'BOUNDARY: Lahman cannot answer game-grain pitcher questions; ' ||
       'see BigQuery Retrosheet for NYA199907250 — bridge via PEOPLE."retroID"' AS boundary_note;

-- Smoke 4: Negro Leagues integration (SABR 2024 addition)
SELECT "lgID", COUNT(DISTINCT "playerID") AS players
FROM BATTING
WHERE "lgID" IN ('NN1','ECL','ANL','EWL','NSL','NN2','NAL')
GROUP BY "lgID"
ORDER BY "lgID";

-- Smoke 5: 1998 Yankees — expecting 114 regular-season + 11 postseason = 125 total wins
SELECT
  (SELECT "W" FROM TEAMS WHERE "yearID" = 1998 AND "teamID" = 'NYA') AS reg_season_W,
  (SELECT SUM("wins") FROM SERIESPOST WHERE "yearID" = 1998 AND "teamIDwinner" = 'NYA') AS postseason_W,
  (SELECT "W" FROM TEAMS WHERE "yearID" = 1998 AND "teamID" = 'NYA')
  + (SELECT SUM("wins") FROM SERIESPOST WHERE "yearID" = 1998 AND "teamIDwinner" = 'NYA') AS total_W;
