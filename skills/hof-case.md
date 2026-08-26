---
name: hof-case
description: Build a rigorous, evidence-grounded Hall of Fame case for any
  baseball player. Use when asked to evaluate, argue, or assess a player's
  Hall of Fame candidacy. Pulls canonical stats from the PLAYERS_AND_TEAMS
  semantic view and structures both the case FOR and the honest case AGAINST.
---

# Building a Hall of Fame Case

A reproducible procedure for arguing any player's Hall of Fame candidacy from
governed data — not from memory. The first Layer 3 Skill in the baseball
agentic-analytics build (mirrors Anthropic's 4-layer self-service architecture).

## When to use this skill

Use whenever asked to evaluate, argue, assess, or weigh a baseball player's
Hall of Fame candidacy — whether the player is enshrined, on the ballot, fell
off the ballot, or is not yet eligible. Do **not** use it for a single-stat
lookup or a generic player comparison; this is specifically the procedure for
constructing a balanced, evidence-grounded Hall of Fame argument.

## Step 1 — Pull the canonical line

Before arguing anything, pull the player's real numbers from the
`BASEBALL.ANALYTICS.PLAYERS_AND_TEAMS` semantic view. Never assert a stat
from memory — every number in the case must trace to a metric below.

Filter by `full_name` (e.g. 'Don Mattingly'). All career metrics aggregate
across seasons and stints automatically (they SUM under the hood), so one
query returns the career line.

**Hitting (from `batting`):**
- `career_home_runs`, `career_hits`, `career_rbi`, `career_runs`,
  `career_doubles`, `career_games`, `career_at_bats`
- `batting_average`  ← rate stat; the peak-case anchor

**Defense (from `fielding`):**
- `fielding_pct`, `career_putouts`, `career_assists`, `career_errors`

**Hardware (from `awards`):** `award_count`, filtered by `award_name`:
- Gold Gloves → `award_name = 'Gold Glove'`
- MVP → `award_name = 'Most Valuable Player'`

**Postseason (from `batting_post`):**
- `post_home_runs`, `post_hits`, `post_rbi`

**Ballot history (from `hof`):**
- `best_vote_pct` (best single-year ballot share)
- `inducted` (did the BBWAA elect him?)

Capture each number with its source table — that provenance becomes the
footer in Step 4.

## Step 2 — Frame the case on the six axes

A Hall of Fame case is not a stat dump. Map the Step 1 numbers onto six
recognized argument axes. For each axis, state the evidence AND whether it
helps or hurts the case — honesty here is what makes the verdict credible.

1. **Peak** — How high was the ceiling? Best 3–5 seasons by `batting_average`,
   plus the MVP year. A short, towering peak is a real HOF argument
   (the "fame" in Hall of Fame), but voters discount it if it didn't last.

2. **Longevity / counting stats** — `career_hits`, `career_home_runs`,
   `career_rbi`, `career_games`. Compare against the traditional milestones
   voters anchor on (3,000 hits, 500 HR). Falling short isn't fatal, but it
   shifts weight onto peak and defense.

3. **Defense** — `fielding_pct` + Gold Glove count
   (`award_count` where `award_name = 'Gold Glove'`). Elite glove at a
   premium-defense position is a genuine plank; at first base it helps less
   than at shortstop or center field. Name the position honestly.

4. **Postseason** — `post_home_runs`, `post_hits`, `post_rbi`. A strong
   October résumé is a thumb on the scale; a thin one (few appearances) is
   context, not an indictment — note whether the player's teams made it.

5. **Awards & honors** — MVP (`award_name = 'Most Valuable Player'`),
   All-Star selections, Gold Gloves. These are the contemporaneous verdict
   of the player's own era — voters weight them heavily.

6. **Ballot history** — `best_vote_pct` and `inducted`. This is the meta-axis:
   how the electorate has ALREADY judged the player. Never cleared 75%?
   State the peak share, why support stalled, and the remaining path
   (BBWAA ballot exhausted → Era/Veterans Committee).

## Step 3 — Argue both sides

A one-sided case is advocacy, not analysis. Build the strongest version of
each side from the SAME grounded numbers, then weigh them. This is what
separates a credible verdict from a fan's argument.

### The case FOR
Lead with the player's strongest axes. Synthesize — don't list. Tie the
peak (axis 1), the defense (axis 3), and the hardware (axis 5) into a single
claim about what the player was at his best: "For a five-to-seven year
window, was he among the very best in the game at his position?" If yes,
that is a real Hall of Fame argument even without the counting milestones.

### The honest case AGAINST
Build the skeptic's case just as rigorously. Usually it lives on axes 2 and 6:
- **Counting stats fell short** of the traditional milestones (state the gap).
- **The peak didn't last** — injury, decline, or early retirement capped the
  career arc (name the cause from the data: compare late-career `batting_average`
  and `career_games` trajectory).
- **The electorate already ruled** — `best_vote_pct` never reached 75%, and the
  BBWAA ballot is exhausted. The bar now is an Era Committee, which weighs
  legacy differently.

### Weigh it
State which side is stronger and WHY, in one honest paragraph. Acceptable
verdicts: "clear yes," "clear no," or "a genuine borderline case whose
outcome depends on how much you weight peak vs. longevity." Borderline is a
legitimate conclusion — do not manufacture false certainty to sound decisive.

## Step 4 — Render the verdict with provenance

Output the case in a fixed shape so it's reproducible and skimmable. Same
structure for every player.

**Format:**

> **[Player Name] — Hall of Fame Case**
>
> **The line:** [one sentence — career AVG / HR / hits / signature stat]
>
> **Case for:** [2–3 sentences synthesizing the strongest axes]
>
> **Case against:** [2–3 sentences, the honest skeptic's view]
>
> **Verdict:** [clear yes / clear no / borderline — and the one factor the
> call hinges on]
>
> ---
> *Source: BASEBALL.ANALYTICS.PLAYERS_AND_TEAMS semantic view (Lahman).
> Hitting ← BATTING · Defense ← FIELDING · Awards ← AWARDSPLAYERS ·
> Ballot ← HALLOFFAME · Postseason ← BATTINGPOST.*

**The provenance footer is not optional.** It is the single most important
line for trust: it tells the reader every number is queryable and which
table it came from. If a stat can't be traced to the semantic view, it does
not go in the case.

## Worked example: Don Mattingly

Running the four steps against `PLAYERS_AND_TEAMS`:

**Step 1 — the line:** .307 AVG · 222 HR · 2,153 hits · 1,099 RBI · 1,785 games ·
.9956 fielding pct · 9 Gold Gloves · 1985 AL MVP · 1984 batting title (.343).
Postseason: 1995 ALDS only — .417 (10-for-24), 1 HR, 6 RBI. Best HOF ballot
share ~28% (2001); never elected by BBWAA; ballot exhausted after 2015.

**Step 2 — axes:**
- *Peak* (★ strong): 1984–1989 he was arguably the best hitter in the AL —
  a batting title, an MVP, top-tier average and doubles power.
- *Longevity* (weak): 222 HR / 2,153 hits fall well short of the milestones;
  a chronic back injury collapsed his power after 1989 and ended him at 34.
- *Defense* (★ strong): .9956 fielding pct and 9 Gold Gloves — an all-time
  great defensive first baseman. (Caveat: first base is a low-value glove.)
- *Postseason* (context): one series, but he raked. Thin résumé is on the
  late-'80s/early-'90s Yankees not making October, not on him.
- *Awards* (★ strong): MVP + batting title + 9 Gold Gloves = his era's verdict
  that he was elite.
- *Ballot* (weak): peaked at ~28%, never near 75%. Path now is an Era Committee.

**Step 3 — both sides:**
- *For:* For six years he was the best position player in the American League,
  with the bat and the glove, validated by an MVP and near-annual Gold Gloves.
  A peak that high is a Hall of Fame argument on its own.
- *Against:* The peak didn't last. A back injury turned a potential
  inner-circle career into a six-year window, and the counting stats never
  came. The BBWAA has already ruled — 15 years, never close to 75%.
- *Weigh:* A genuine borderline case. If you weight peak, he's in; if you
  weight career value and milestones, he's short. The injury is the whole story.

**Step 4 — verdict:**

> **Don Mattingly — Hall of Fame Case**
>
> **The line:** A .307 career hitter with an MVP, a batting title, and 9 Gold
> Gloves across a brilliant but injury-shortened peak.
>
> **Case for:** Mid-1980s Mattingly was the best all-around player in the AL —
> elite bat, elite glove, hardware to prove it.
>
> **Case against:** A back injury capped him at six great years; 222 HR and
> 2,153 hits fall short of the milestones, and BBWAA voters never got him past ~28%.
>
> **Verdict:** Borderline — the call hinges entirely on how much you weight a
> towering peak against a short career. An Era Committee question now, not a
> statistical slam dunk.
>
> ---
> *Source: BASEBALL.ANALYTICS.PLAYERS_AND_TEAMS semantic view (Lahman).
> Hitting ← BATTING · Defense ← FIELDING · Awards ← AWARDSPLAYERS ·
> Ballot ← HALLOFFAME · Postseason ← BATTINGPOST.*

> ⚠️ Regenerate this example from the live semantic view once agent runtime is
> available (trial-gated as of 2026-06-09). Confirm the ~28% best-ballot share
> and Gold Glove count against `best_vote_pct` and `award_count` when it runs.

## Gotchas

These are the traps that make a HOF case wrong even when the query runs clean.

1. **Stints inflate or fragment seasons.** A player traded mid-year has
   multiple `stint` rows for that season. Career metrics SUM across stints
   (correct), but any *per-season* breakdown must aggregate stints or it shows
   a partial line. Mattingly never moved, so it doesn't bite here — but it will
   for journeymen.

2. **No era adjustment.** This semantic view carries traditional counting and
   rate stats only — no OPS+, no WAR, no park/era normalization. A .307 in the
   1980s is not a .307 in the 1930s. Argue honestly within that limit, and name
   it: a modern analyst would also reach for rate-plus and WAR (not yet modeled).

3. **Award strings are exact literals.** `'Gold Glove'` and
   `'Most Valuable Player'` — a near-miss string returns zero and silently
   erases the player's hardware. Never guess the literal; use these.

4. **Fielding blends positions.** `fielding_pct` aggregates every position a
   player logged. Fine for a career first baseman; misleading for a
   multi-position player. Name the primary position in the case.

5. **Missing ballot data ≠ rejection.** Active or recently-retired players have
   no `hof` rows yet. Absence of a ballot is "not yet eligible," not "the voters
   said no." Don't read a null as a negative — and check `inducted`, not just
   `best_vote_pct` (a player can surge to election in a final year).
