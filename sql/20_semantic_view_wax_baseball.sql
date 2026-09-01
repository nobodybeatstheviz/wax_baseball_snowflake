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
-- Parity column identifiers are case-preserved lowercase from Parquet
-- INFER_SCHEMA -> every base-table column is quoted.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WAX_WH;

CREATE SCHEMA IF NOT EXISTS BASEBALL.SEMANTICS
  COMMENT = 'Governed semantic views over the WAX_BASEBALL parity corpus.';

CREATE OR REPLACE SEMANTIC VIEW BASEBALL.SEMANTICS.KEEPING_SCORE

  -- ---- logical tables -------------------------------------------------------
  TABLES (
    attended_games AS BASEBALL.WAX_BASEBALL.FCT_ATTENDED_GAMES
      PRIMARY KEY ("game_id")
      WITH SYNONYMS ('games attended','ballgames','my games')
      COMMENT = 'One row per game Wax attended (178).',

    plays AS BASEBALL.WAX_BASEBALL.FCT_PLAYS
      PRIMARY KEY ("game_id","event_id")
      WITH SYNONYMS ('play by play','events','plays witnessed')
      COMMENT = 'One row per Retrosheet play in an attended game (14,406).',

    game_attendee AS BASEBALL.WAX_BASEBALL.FCT_GAME_ATTENDEE
      WITH SYNONYMS ('who was there','companions','who i went with')
      COMMENT = 'One row per (game, attendee) pair (320).',

    attended_team_games AS BASEBALL.WAX_BASEBALL.FCT_ATTENDED_TEAM_GAMES
      WITH SYNONYMS ('team perspective','wins and losses','team games')
      COMMENT = 'Two rows per attended game -- one per team -- for win/decided (356).',

    hof_sightings AS BASEBALL.WAX_BASEBALL.FCT_HOF_SIGHTINGS
      PRIMARY KEY ("player_id")
      WITH SYNONYMS ('hall of famers','cooperstown sightings','hof seen')
      COMMENT = 'One row per HOF player Wax has seen (44).'
  )

  -- ---- relationships --------------------------------------------------------
  -- Kept sparse on purpose: each golden question queries a single fact table,
  -- so we do not need to join facts for correctness. Attendee/event lookups
  -- are already denormalized onto the facts.
  RELATIONSHIPS (
    plays_to_game            AS plays               ("game_id")       REFERENCES attended_games,
    attendee_to_game         AS game_attendee       ("wax_game_id")   REFERENCES attended_games ("game_id"),
    team_game_to_game        AS attended_team_games ("game_id")       REFERENCES attended_games
  )

  -- ---- facts (row-level numeric values) -------------------------------------
  FACTS (
    plays.f_runs_on_play    AS plays."runs_on_play",
    plays.f_event_code      AS plays."event_code",
    plays.f_is_home_run     AS CASE WHEN plays."event_code" = 23 THEN 1 ELSE 0 END,

    attended_team_games.f_team_won  AS CASE WHEN attended_team_games."team_won"  THEN 1 ELSE 0 END,
    attended_team_games.f_is_decided AS CASE WHEN attended_team_games."is_decided" THEN 1 ELSE 0 END
  )

  -- ---- dimensions (attributes for grouping / filtering) ---------------------
  DIMENSIONS (
    attended_games.game_date AS attended_games."game_date"
      WITH SYNONYMS ('date','game day','when'),
    attended_games.year      AS YEAR(attended_games."game_date")
      WITH SYNONYMS ('season','yr','year of game'),
    attended_games.venue_wax AS attended_games."venue_wax"
      WITH SYNONYMS ('venue','stadium','ballpark','park'),
    attended_games.city      AS attended_games."city",
    attended_games.state     AS attended_games."state",

    plays.play_date          AS plays."game_date",
    plays.play_year          AS YEAR(plays."game_date"),
    plays.event_code         AS plays."event_code"
      WITH SYNONYMS ('event code','retrosheet code'),
    plays.event_text         AS plays."event_text",
    plays.inning             AS plays."inning",

    game_attendee.attendee_name AS game_attendee."attendee_name"
      WITH SYNONYMS ('attendee','companion','who with','who was there'),
    game_attendee.attendee_type AS game_attendee."attendee_type"
      WITH SYNONYMS ('relationship','attendee category'),
    game_attendee.attendee_game_date AS game_attendee."game_date",

    attended_team_games.team_id          AS attended_team_games."team_id"
      WITH SYNONYMS ('team','team code','franchise'),
    attended_team_games.opponent_team_id AS attended_team_games."opponent_team_id"
      WITH SYNONYMS ('opponent','other team'),
    attended_team_games.is_home          AS attended_team_games."is_home"
      WITH SYNONYMS ('home','home game','at home'),
    attended_team_games.team_game_date   AS attended_team_games."game_date",

    hof_sightings.player_id      AS hof_sightings."player_id",
    hof_sightings.player_name    AS hof_sightings."player_name"
      WITH SYNONYMS ('player','hof player','name'),
    hof_sightings.induction_year AS hof_sightings."induction_year"
      WITH SYNONYMS ('year inducted','cooperstown year')
  )

  -- ---- metrics (aggregations -- the parity contract) -----------------------
  METRICS (
    -- 1. games_attended
    attended_games.games_attended AS COUNT(*)
      WITH SYNONYMS ('games','games seen','games i attended','how many games')
      COMMENT = 'Count of attended games. Parity: 178.',

    -- 2. unique_stadiums
    attended_games.unique_stadiums AS COUNT(DISTINCT attended_games."venue_wax")
      WITH SYNONYMS ('stadiums','ballparks','venues','parks visited')
      COMMENT = 'Distinct venues visited. Parity: 22.',

    -- 3. home_runs_witnessed
    plays.home_runs_witnessed AS SUM(CASE WHEN plays."event_code" = 23 THEN 1 ELSE 0 END)
      WITH SYNONYMS ('home runs','homers seen','dingers witnessed','hrs')
      COMMENT = 'Home runs (event_code=23) across all attended plays. Parity: 400.',

    -- 4. runs_witnessed
    plays.runs_witnessed AS SUM(plays."runs_on_play")
      WITH SYNONYMS ('runs','runs seen','total runs scored')
      COMMENT = 'Sum of runs on every attended play. Parity: 1706.',

    -- 5. team_wins_attended (component)
    attended_team_games.team_wins_attended AS SUM(CASE WHEN attended_team_games."team_won" THEN 1 ELSE 0 END)
      WITH SYNONYMS ('team wins','wins when attending')
      COMMENT = 'Team perspective wins. Group by team_id. NYA parity: 90.',

    -- 6. team_games_decided (component)
    attended_team_games.team_games_decided AS SUM(CASE WHEN attended_team_games."is_decided" THEN 1 ELSE 0 END)
      WITH SYNONYMS ('decided games','games with a decision')
      COMMENT = 'Team perspective decided games (excludes ties/suspended). NYA parity: 143.',

    -- 7. attended_win_rate
    attended_team_games.attended_win_rate AS
      SUM(CASE WHEN attended_team_games."team_won"  THEN 1 ELSE 0 END)::FLOAT
      / NULLIF(SUM(CASE WHEN attended_team_games."is_decided" THEN 1 ELSE 0 END), 0)
      WITH SYNONYMS ('win rate','winning percentage','win pct')
      COMMENT = 'team_wins_attended / team_games_decided. Group by team_id. NYA parity: 0.629.',

    -- 8. games_per_attendee
    game_attendee.games_per_attendee AS COUNT(*)
      WITH SYNONYMS ('games with','how many games with','attendee game count')
      COMMENT = 'Games grouped by attendee_name. Melissa=57, Bergan=27, Al=26, solo=16, Poppa=14.',

    -- 9. hall_of_famers_seen
    hof_sightings.hall_of_famers_seen AS COUNT(DISTINCT hof_sightings."player_id")
      WITH SYNONYMS ('hall of famers','hofers seen','cooperstown count')
      COMMENT = 'Distinct HOF players Wax has seen live. Parity: 44.'
  )

  COMMENT = 'Keeping Score parity semantic view: the 7 governed metrics (plus 2 components) over the WAX_BASEBALL parity corpus. Semantics identical to the dbt reference in wax_baseball_dbt.';
