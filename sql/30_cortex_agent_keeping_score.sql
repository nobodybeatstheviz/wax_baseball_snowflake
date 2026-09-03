-- Keeping Score — Cortex Agent over the parity semantic view (phase 2, O5).
--
-- Stood up 2026-09-03 by SQL alone — no Snowsight step. The whole agent is this
-- one statement: a Cortex Analyst text-to-SQL tool bound to the semantic view
-- from 20_semantic_view_wax_baseball.sql. Contrast Databricks Genie (O4), whose
-- space can only be created in the UI. Runs are traced automatically into
-- SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS (scope snow.cortex.agent) — no setup.
--
-- Rerun-safe (OR REPLACE). The spec replaces the whole previous spec each time.
-- Budget is a safety rail for the observability captures, not a product setting.

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WAX_WH;

CREATE OR REPLACE AGENT BASEBALL.SEMANTICS.KEEPING_SCORE_AGENT
  COMMENT = 'Keeping Score parity agent: the 7 governed metrics via the KEEPING_SCORE semantic view (phase 2, O5).'
  PROFILE = '{"display_name": "Keeping Score"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    budget:
      seconds: 120
      tokens: 20000

  instructions:
    response: "Lead with the number. Answer only from the semantic view's governed metrics; never estimate."
    orchestration: "Every quantitative question goes to query_keeping_score. Team codes are Retrosheet ids (Yankees = NYA)."
    sample_questions:
      - question: "How many home runs have I witnessed in person?"
      - question: "How many Hall of Famers have I seen play?"
      - question: "What is my win rate when I go see the Yankees?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "query_keeping_score"
        description: "Queries the Keeping Score semantic view: Wax's 178 attended MLB games (1984-2025) — games attended, unique stadiums, home runs witnessed, runs witnessed, Hall of Famers seen, games per attendee, and a team's attended win rate."

  tool_resources:
    query_keeping_score:
      semantic_view: "BASEBALL.SEMANTICS.KEEPING_SCORE"
      execution_environment:
        type: "warehouse"
        warehouse: "WAX_WH"
  $$;

DESCRIBE AGENT BASEBALL.SEMANTICS.KEEPING_SCORE_AGENT;
