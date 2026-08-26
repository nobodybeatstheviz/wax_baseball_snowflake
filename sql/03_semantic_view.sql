-- ============================================================================
-- Wax-Baseball :: Snowflake Cortex build :: Phase 1 (hand-built semantic view)
-- ----------------------------------------------------------------------------
-- One curated object that Snowflake Intelligence / Cortex Analyst points at.
-- Spine questions:  (1) Mattingly's HOF case   (2) the 1998 Yankees
-- Later: dbt regenerates THIS SAME object; Sigma can also point at it.
-- Lahman columns are case-sensitive quoted identifiers -> every "col" is quoted.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WAX_WH;

CREATE SCHEMA IF NOT EXISTS BASEBALL.ANALYTICS
  COMMENT = 'Curated semantic layer over LAHMAN_RAW for Cortex / Sigma / dbt';

CREATE OR REPLACE SEMANTIC VIEW BASEBALL.ANALYTICS.PLAYERS_AND_TEAMS

  -- ---- logical tables -------------------------------------------------------
  TABLES (
    players AS BASEBALL.LAHMAN_RAW.PEOPLE
      PRIMARY KEY ("playerID")
      WITH SYNONYMS ('player','people','guy','ballplayer')
      COMMENT = 'One row per player (biographical).',

    batting AS BASEBALL.LAHMAN_RAW.BATTING
      PRIMARY KEY ("playerID","yearID","stint")
      WITH SYNONYMS ('hitting','offense','batting stats')
      COMMENT = 'Regular-season batting, one row per player-season-stint.',

    fielding AS BASEBALL.LAHMAN_RAW.FIELDING
      PRIMARY KEY ("playerID","yearID","stint","POS")
      WITH SYNONYMS ('defense','glove','fielding stats')
      COMMENT = 'Regular-season fielding by position, one row per player-season-stint-position.',

    awards AS BASEBALL.LAHMAN_RAW.AWARDSPLAYERS
      PRIMARY KEY ("playerID","awardID","yearID","lgID")
      WITH SYNONYMS ('hardware','honors','trophies')
      COMMENT = 'Player awards (MVP, Gold Glove, etc.), one row per award won.',

    hof AS BASEBALL.LAHMAN_RAW.HALLOFFAME
      PRIMARY KEY ("playerID","yearid","votedBy")
      WITH SYNONYMS ('hall of fame','cooperstown','hof ballot')
      COMMENT = 'Hall of Fame voting, one row per player-year-ballot.',

    batting_post AS BASEBALL.LAHMAN_RAW.BATTINGPOST
      PRIMARY KEY ("yearID","round","playerID","teamID")
      WITH SYNONYMS ('postseason hitting','october','playoff batting')
      COMMENT = 'Postseason batting, one row per player-year-round.',

    teams AS BASEBALL.LAHMAN_RAW.TEAMS
      PRIMARY KEY ("teamID","yearID","lgID")
      WITH SYNONYMS ('team','club','ballclub','franchise season')
      COMMENT = 'Team-season records, one row per team-season.',

    series_post AS BASEBALL.LAHMAN_RAW.SERIESPOST
      PRIMARY KEY ("yearID","round")
      WITH SYNONYMS ('series results','playoff series','postseason rounds')
      COMMENT = 'Postseason series outcomes, one row per year-round.'
  )

  -- ---- relationships --------------------------------------------------------
  RELATIONSHIPS (
    batting_to_players      AS batting      ("playerID") REFERENCES players,
    fielding_to_players     AS fielding     ("playerID") REFERENCES players,
    awards_to_players       AS awards       ("playerID") REFERENCES players,
    hof_to_players          AS hof          ("playerID") REFERENCES players,
    batting_post_to_players AS batting_post ("playerID") REFERENCES players,
    batting_to_teams        AS batting      ("teamID","yearID","lgID") REFERENCES teams
  )

  -- ---- facts (row-level numeric values) -------------------------------------
  FACTS (
    batting.b_games   AS batting."G",
    batting.b_ab      AS batting."AB",
    batting.b_runs    AS batting."R",
    batting.b_hits    AS batting."H",
    batting.b_doubles AS batting."2B",
    batting.b_triples AS batting."3B",
    batting.b_hr      AS batting."HR",
    batting.b_rbi     AS batting."RBI",
    batting.b_bb      AS batting."BB",
    batting.b_so      AS batting."SO",
    batting.b_sb      AS batting."SB",

    fielding.f_games    AS fielding."G",
    fielding.f_putouts  AS fielding."PO",
    fielding.f_assists  AS fielding."A",
    fielding.f_errors   AS fielding."E",
    fielding.f_dp       AS fielding."DP",

    batting_post.p_games AS batting_post."G",
    batting_post.p_ab    AS batting_post."AB",
    batting_post.p_hits  AS batting_post."H",
    batting_post.p_hr    AS batting_post."HR",
    batting_post.p_rbi   AS batting_post."RBI",
    batting_post.p_runs  AS batting_post."R",

    teams.t_wins   AS teams."W",
    teams.t_losses AS teams."L",
    teams.t_runs   AS teams."R",
    teams.t_ra     AS teams."RA",
    teams.t_hr     AS teams."HR",

    hof.h_votes   AS hof."votes",
    hof.h_ballots AS hof."ballots",
    hof.h_needed  AS hof."needed"
  )

  -- ---- dimensions (attributes for grouping / filtering) ---------------------
  DIMENSIONS (
    players.player_id  AS players."playerID",
    players.full_name  AS players."nameFirst" || ' ' || players."nameLast"
      WITH SYNONYMS ('name','player name','who')
      COMMENT = 'Player full name, e.g. Don Mattingly.',
    players.bats       AS players."bats"   WITH SYNONYMS ('batting hand','handedness'),
    players.throws     AS players."throws" WITH SYNONYMS ('throwing hand'),
    players.birth_year AS players."birthYear",
    players.debut      AS players."debut",
    players.final_game AS players."finalGame",

    batting.season  AS batting."yearID"  WITH SYNONYMS ('year','batting year'),
    batting.team    AS batting."teamID"  WITH SYNONYMS ('team code'),
    batting.league  AS batting."lgID"    WITH SYNONYMS ('lg','al or nl'),

    fielding.position AS fielding."POS"  WITH SYNONYMS ('pos','field position','spot'),
    fielding.f_season AS fielding."yearID",

    awards.award_name AS awards."awardID" WITH SYNONYMS ('award','honor','trophy'),
    awards.award_year AS awards."yearID",
    awards.award_lg   AS awards."lgID",

    hof.hof_year  AS hof."yearid" WITH SYNONYMS ('ballot year','hof year'),
    hof.voted_by  AS hof."votedBy",
    hof.inducted  AS hof."inducted" WITH SYNONYMS ('elected','made it'),
    hof.category  AS hof."category",

    batting_post.round    AS batting_post."round" WITH SYNONYMS ('series','playoff round'),
    batting_post.p_season AS batting_post."yearID",

    teams.team_name   AS teams."name"     WITH SYNONYMS ('club name','franchise'),
    teams.team_code   AS teams."teamID",
    teams.season      AS teams."yearID"   WITH SYNONYMS ('year','team year'),
    teams.league      AS teams."lgID",
    teams.division    AS teams."divID",
    teams.ws_winner   AS teams."WSWin"    WITH SYNONYMS ('world series champ','champions','won it all'),
    teams.div_winner  AS teams."DivWin",

    series_post.s_round  AS series_post."round",
    series_post.s_season AS series_post."yearID",
    series_post.s_winner AS series_post."teamIDwinner" WITH SYNONYMS ('series winner','won the series'),
    series_post.s_loser  AS series_post."teamIDloser"  WITH SYNONYMS ('series loser','lost the series')
  )

  -- ---- metrics (aggregations -- the payoff layer) ---------------------------
  METRICS (
    -- career hitting
    batting.career_home_runs AS SUM(batting.b_hr)
      WITH SYNONYMS ('home runs','homers','dingers','taters','long balls','bombs')
      COMMENT = 'Total regular-season home runs.',
    batting.career_rbi   AS SUM(batting.b_rbi)
      WITH SYNONYMS ('rbis','runs batted in','ribbies'),
    batting.career_hits  AS SUM(batting.b_hits)
      WITH SYNONYMS ('hits','knocks'),
    batting.career_runs  AS SUM(batting.b_runs)
      WITH SYNONYMS ('runs scored'),
    batting.career_doubles AS SUM(batting.b_doubles)
      WITH SYNONYMS ('doubles','two-baggers'),
    batting.career_games AS SUM(batting.b_games)
      WITH SYNONYMS ('games played'),
    batting.career_at_bats AS SUM(batting.b_ab)
      WITH SYNONYMS ('at bats','ab'),
    batting.batting_average AS SUM(batting.b_hits) / NULLIF(SUM(batting.b_ab), 0)
      WITH SYNONYMS ('average','avg','ba','batting avg')
      COMMENT = 'Hits divided by at-bats.',

    -- fielding (the Gold Glove case)
    fielding.career_putouts AS SUM(fielding.f_putouts)
      WITH SYNONYMS ('putouts','po'),
    fielding.career_assists AS SUM(fielding.f_assists)
      WITH SYNONYMS ('assists'),
    fielding.career_errors  AS SUM(fielding.f_errors)
      WITH SYNONYMS ('errors','miscues','boots'),
    fielding.career_double_plays AS SUM(fielding.f_dp)
      WITH SYNONYMS ('double plays','dps','twin killings'),
    fielding.fielding_pct AS (SUM(fielding.f_putouts) + SUM(fielding.f_assists))
      / NULLIF(SUM(fielding.f_putouts) + SUM(fielding.f_assists) + SUM(fielding.f_errors), 0)
      WITH SYNONYMS ('fielding percentage','fielding pct','glove rate')
      COMMENT = '(PO + A) / (PO + A + E) -- defensive reliability.',

    -- awards / HOF
    awards.award_count AS COUNT(awards.award_name)
      WITH SYNONYMS ('awards won','number of awards','hardware count','gold gloves')
      COMMENT = 'Count of awards rows; filter award = the specific honor (e.g. Gold Glove).',
    hof.best_vote_pct AS MAX(hof.h_votes / NULLIF(hof.h_ballots, 0))
      WITH SYNONYMS ('hof vote percentage','vote share','support')
      COMMENT = 'Best single-year share of HOF ballots received.',

    -- postseason hitting
    batting_post.post_home_runs AS SUM(batting_post.p_hr)
      WITH SYNONYMS ('playoff home runs','october homers'),
    batting_post.post_hits AS SUM(batting_post.p_hits)
      WITH SYNONYMS ('playoff hits'),
    batting_post.post_rbi  AS SUM(batting_post.p_rbi)
      WITH SYNONYMS ('playoff rbis'),

    -- team season
    teams.total_wins AS SUM(teams.t_wins)
      WITH SYNONYMS ('wins','games won'),
    teams.total_losses AS SUM(teams.t_losses)
      WITH SYNONYMS ('losses'),
    teams.runs_scored AS SUM(teams.t_runs)
      WITH SYNONYMS ('runs scored','offense'),
    teams.runs_allowed AS SUM(teams.t_ra)
      WITH SYNONYMS ('runs allowed','runs against'),
    teams.run_differential AS SUM(teams.t_runs) - SUM(teams.t_ra)
      WITH SYNONYMS ('run differential','run diff','how dominant','net runs')
      COMMENT = 'Runs scored minus runs allowed -- team dominance.'
  )

  COMMENT = 'Curated baseball semantic view: players, hitting, fielding, awards, HOF, postseason, and team seasons. Built for Cortex Analyst / Snowflake Intelligence.';
