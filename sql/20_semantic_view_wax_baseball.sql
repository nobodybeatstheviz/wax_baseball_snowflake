-- ============================================================================
-- Wax-Baseball :: Keeping Score parity semantic view (W2s)
-- ----------------------------------------------------------------------------
-- Governed expression of the 7 parity metrics (plus 2 components) over the
-- BASEBALL.WAX_BASEBALL parity corpus. Semantics identical to the dbt
-- reference in wax_baseball_dbt.
--
-- Query pattern:
--   SELECT * FROM SEMANTIC_VIEW(
--     BASEBALL.SEMANTICS.KEEPING_SCORE
--       DIMENSIONS attended_games.year
--       METRICS    attended_games.games_attended
--   );
--
-- Physical columns come through sql/15_parity_views_unquoted.sql (generated):
-- unquoted-uppercase views over the WAX_BASEBALL tables, because Cortex
-- Analyst rejects the tables' quoted lowercase identifiers (error 392700,
-- measured 2026-09-03) while plain SEMANTIC_VIEW() SQL accepts them.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WAX_WH;

CREATE SCHEMA IF NOT EXISTS BASEBALL.SEMANTICS
  COMMENT = 'Governed semantic views over the WAX_BASEBALL parity corpus.';

CREATE OR REPLACE SEMANTIC VIEW BASEBALL.SEMANTICS.KEEPING_SCORE

  -- ---- logical tables -------------------------------------------------------
  TABLES (
    attended_games AS BASEBALL.SEMANTICS.FCT_ATTENDED_GAMES
      PRIMARY KEY (GAME_ID)
      WITH SYNONYMS ('games attended','ballgames','my games')
      COMMENT = 'One row per game Wax attended (178).',

    plays AS BASEBALL.SEMANTICS.FCT_PLAYS
      PRIMARY KEY (GAME_ID,EVENT_ID)
      WITH SYNONYMS ('play by play','events','plays witnessed')
      COMMENT = 'One row per Retrosheet play in an attended game (14,406).',

    game_attendee AS BASEBALL.SEMANTICS.FCT_GAME_ATTENDEE
      WITH SYNONYMS ('who was there','companions','who i went with')
      COMMENT = 'One row per (game, attendee) pair (320).',

    attended_team_games AS BASEBALL.SEMANTICS.FCT_ATTENDED_TEAM_GAMES
      WITH SYNONYMS ('team perspective','wins and losses','team games')
      COMMENT = 'Two rows per attended game -- one per team -- for win/decided (356).',

    hof_sightings AS BASEBALL.SEMANTICS.FCT_HOF_SIGHTINGS
      PRIMARY KEY (PLAYER_ID)
      WITH SYNONYMS ('hall of famers','cooperstown sightings','hof seen')
      COMMENT = 'One row per HOF player Wax has seen (44).'
  )

  -- ---- relationships --------------------------------------------------------
  -- Kept sparse on purpose: each golden question queries a single fact table,
  -- so we do not need to join facts for correctness. Attendee/event lookups
  -- are already denormalized onto the facts.
  RELATIONSHIPS (
    plays_to_game            AS plays               (GAME_ID)       REFERENCES attended_games,
    attendee_to_game         AS game_attendee       (WAX_GAME_ID)   REFERENCES attended_games (GAME_ID),
    team_game_to_game        AS attended_team_games (GAME_ID)       REFERENCES attended_games
  )

  -- ---- facts (row-level numeric values) -------------------------------------
  FACTS (
    plays.f_runs_on_play    AS plays.RUNS_ON_PLAY,
    plays.f_event_code      AS plays.EVENT_CODE,
    plays.f_is_home_run     AS CASE WHEN plays.EVENT_CODE = 23 THEN 1 ELSE 0 END,

    attended_team_games.f_team_won  AS CASE WHEN attended_team_games.TEAM_WON  THEN 1 ELSE 0 END,
    attended_team_games.f_is_decided AS CASE WHEN attended_team_games.IS_DECIDED THEN 1 ELSE 0 END
  )

  -- ---- dimensions (attributes for grouping / filtering) ---------------------
  DIMENSIONS (
    attended_games.game_date AS attended_games.GAME_DATE
      WITH SYNONYMS ('date','game day','when'),
    attended_games.year      AS YEAR(attended_games.GAME_DATE)
      WITH SYNONYMS ('season','yr','year of game'),
    attended_games.venue_wax AS attended_games.VENUE_WAX
      WITH SYNONYMS ('venue','stadium','ballpark','park'),
    attended_games.city      AS attended_games.CITY,
    attended_games.state     AS attended_games.STATE,

    plays.play_date          AS plays.GAME_DATE,
    plays.play_year          AS YEAR(plays.GAME_DATE),
    plays.event_code         AS plays.EVENT_CODE
      WITH SYNONYMS ('event code','retrosheet code'),
    plays.event_text         AS plays.EVENT_TEXT,
    plays.inning             AS plays.INNING,

    game_attendee.attendee_name AS game_attendee.ATTENDEE_NAME
      WITH SYNONYMS ('attendee','companion','who with','who was there'),
    game_attendee.attendee_type AS game_attendee.ATTENDEE_TYPE
      WITH SYNONYMS ('relationship','attendee category'),
    game_attendee.attendee_game_date AS game_attendee.GAME_DATE,

    attended_team_games.team_id          AS attended_team_games.TEAM_ID
      WITH SYNONYMS ('team','team code','franchise'),
    attended_team_games.opponent_team_id AS attended_team_games.OPPONENT_TEAM_ID
      WITH SYNONYMS ('opponent','other team'),
    attended_team_games.is_home          AS attended_team_games.IS_HOME
      WITH SYNONYMS ('home','home game','at home'),
    attended_team_games.team_game_date   AS attended_team_games.GAME_DATE,

    hof_sightings.player_id      AS hof_sightings.PLAYER_ID,
    hof_sightings.player_name    AS hof_sightings.PLAYER_NAME
      WITH SYNONYMS ('player','hof player','name'),
    hof_sightings.induction_year AS hof_sightings.INDUCTION_YEAR
      WITH SYNONYMS ('year inducted','cooperstown year')
  )

  -- ---- metrics (aggregations -- the parity contract) -----------------------
  METRICS (
    -- 1. games_attended
    attended_games.games_attended AS COUNT(*)
      WITH SYNONYMS ('games','games seen','games i attended','how many games')
      COMMENT = 'Count of attended games. Parity: 178.',

    -- 2. unique_stadiums
    attended_games.unique_stadiums AS COUNT(DISTINCT attended_games.VENUE_WAX)
      WITH SYNONYMS ('stadiums','ballparks','venues','parks visited')
      COMMENT = 'Distinct venues visited. Parity: 22.',

    -- 3. home_runs_witnessed
    plays.home_runs_witnessed AS SUM(CASE WHEN plays.EVENT_CODE = 23 THEN 1 ELSE 0 END)
      WITH SYNONYMS ('home runs','homers seen','dingers witnessed','hrs')
      COMMENT = 'Home runs (event_code=23) across all attended plays. Parity: 400.',

    -- 4. runs_witnessed
    plays.runs_witnessed AS SUM(plays.RUNS_ON_PLAY)
      WITH SYNONYMS ('runs','runs seen','total runs scored')
      COMMENT = 'Sum of runs on every attended play. Parity: 1706.',

    -- 5. team_wins_attended (component)
    attended_team_games.team_wins_attended AS SUM(CASE WHEN attended_team_games.TEAM_WON THEN 1 ELSE 0 END)
      WITH SYNONYMS ('team wins','wins when attending')
      COMMENT = 'Team perspective wins. Group by team_id. NYA parity: 90.',

    -- 6. team_games_decided (component)
    attended_team_games.team_games_decided AS SUM(CASE WHEN attended_team_games.IS_DECIDED THEN 1 ELSE 0 END)
      WITH SYNONYMS ('decided games','games with a decision')
      COMMENT = 'Team perspective decided games (excludes ties/suspended). NYA parity: 143.',

    -- 7. attended_win_rate
    attended_team_games.attended_win_rate AS
      SUM(CASE WHEN attended_team_games.TEAM_WON  THEN 1 ELSE 0 END)::FLOAT
      / NULLIF(SUM(CASE WHEN attended_team_games.IS_DECIDED THEN 1 ELSE 0 END), 0)
      WITH SYNONYMS ('win rate','winning percentage','win pct')
      COMMENT = 'team_wins_attended / team_games_decided. Group by team_id. NYA parity: 0.629.',

    -- 8. games_per_attendee
    game_attendee.games_per_attendee AS COUNT(*)
      WITH SYNONYMS ('games with','how many games with','attendee game count')
      COMMENT = 'Games grouped by attendee_name. Melissa=57, Bergan=27, Al=26, solo=16, Poppa=14.',

    -- 9. hall_of_famers_seen
    hof_sightings.hall_of_famers_seen AS COUNT(DISTINCT hof_sightings.PLAYER_ID)
      WITH SYNONYMS ('hall of famers','hofers seen','cooperstown count')
      COMMENT = 'Distinct HOF players Wax has seen live. Parity: 44.'
  )

  COMMENT = 'Keeping Score parity semantic view: the 7 governed metrics (plus 2 components) over the WAX_BASEBALL parity corpus. Semantics identical to the dbt reference in wax_baseball_dbt.';
