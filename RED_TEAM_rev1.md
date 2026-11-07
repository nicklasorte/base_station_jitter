# Red team: base station jitter (rev1)

DRAFT. This review attacks the jitter method the way a skeptical federal
spectrum office would during coordination. Every number comes from
`red_team_experiments_rev1.m`, run in MATLAB R2025b on
`Rand_Table_RSU_HIAK.xlsx` (62,113 sites). The raw output is in
`red_team_log_rev1.txt`.

## Bottom line

The method is unbiased and repeatable, and it preserves base station
density near a receiver on average. A federal reviewer's strongest
objections aren't about the code. They're about two choices the code
can't justify on its own:

1. **A single seed can change a coordination answer.** At the default
   `Fraction` of 1/3, the nearest base station to a receiver moves 1.7 km
   or more closer in 5 percent of cases, and the seed-to-seed spread is a
   median of 2.3 km. One realization isn't a result; the distribution
   across seeds is.
1. **The jitter size has no empirical basis.** One third of the
   nearest-neighbor distance is a modeling choice, not a measured
   location error. Without a comparison to known locations, the agency
   can argue the jitter is too large (it manufactures risk) or too small
   (it understates uncertainty).

## Findings

| # | Agency objection | Evidence | Severity | Response |
| --- | --- | --- | --- | --- |
| 1 | "You picked a seed that moves stations away from our site." | Across 20 seeds, the nearest base station to a receiver varies by a median of 2,298 m and a 95th percentile of 6,477 m (E3). | High | Never report one seed. Run a fixed, published seed list (for example, seeds 1 to 100) and report the CDF across seeds. |
| 2 | "Jitter moves stations into our protection area." | At `Fraction` 1/3, the nearest station gets closer in 49.4 percent of receiver-seed cases. The 5th percentile is 1,693 m closer (41.8 percent of the original distance), and the worst case is 10,824 m closer (E3). | High | This is the point of jitter: it moves stations both ways. Report the closer tail explicitly, and apply exclusion or coordination zones after jitter, not before. |
| 3 | "The jitter size is arbitrary." | Tail effects scale with `Fraction`: the 5th-percentile approach is 565 m at 0.1, 1,693 m at 1/3, and 2,172 m at 0.45 (E4). | High | Tie `Fraction` and `MaxRadius_m` to measured error of the approximation against known locations. Until then, show results at more than one `Fraction`. |
| 4 | "Jitter is biased toward a direction." | Mean displacement is 3.2 m north (standard error 4.0 m) and 0.5 m east (standard error 4.1 m), consistent with zero (E1). | Low | No change. Cite E1. |
| 5 | "Jitter changes aggregate density near our receiver." | The mean count of base stations within 10 km of a receiver is 20.37 after jitter versus 20.34 before (E3). Individual counts change in 45.0 percent of receiver-seed cases, in both directions. | Low | No change for aggregate interference. Use many seeds for single-receiver results. |
| 6 | "Remote stations move tens of kilometers." | With no cap, the largest move across 5 seeds is 99,372 m; with seed 42 it's 103,555 m, for a 35 m (rural) site (E5, E6). A 5 km cap affects 1,076 sites (1.7 percent); a 2 km cap affects 14,823 (23.9 percent). | Medium | Set `MaxRadius_m`. A 5 km cap removes the outliers and leaves 98 percent of sites untouched. |
| 7 | "Stations end up in the ocean." | 0.55 percent of on-land sites (about 340 per realization) land off land in the Census 1:500,000 state boundaries. Capping barely helps: 0.54 percent at 5 km and 0.52 percent at 2 km, so these are coastal sites, not long jumps (E2). The source table already has 83 sites (0.13 percent) off land. | Low to medium | Known limitation. A land check was considered and not adopted. Note it in any filing and flag coastal receivers for manual review. |
| 8 | "Moved stations keep the wrong clutter class." | Height, and so clutter class, carries over unchanged. Urban (20 m) sites move a median of 320 m, suburban (25 m) 582 m, and rural (35 m) 1,454 m (E6). | Medium | Not tested: no clutter map was used. A rural site moving 1.5 km can cross into a suburb. Reassigning class after jitter needs a land-cover dataset. |
| 9 | "The results can't be reproduced." | Seeded local random stream, 24 unit tests, atomic file writes, and this script reproduce every number here. | Low | No change. Share the repo and the seed list. |

## What this review didn't test

- **Ground truth.** No known base station locations were compared, so the
  real error of the approximation is unknown. Finding 3 rests on this gap.
- **Real federal sites.** The 500 receivers are synthetic points 5 to 30 km
  from random base stations, not actual federal or FSS locations.
- **Interference.** The review measures geometry (distances and counts),
  not I/N or aggregate interference. Geometry changes don't map one to one
  onto interference changes once propagation and antenna patterns are
  applied.
- **Independent review.** The author of the code wrote this review. A
  separate reviewer should repeat it before it supports a filing or a
  briefing.

## Reproduce

1. Download and unzip the public Census file
   [cb_2023_us_state_500k.zip](https://www2.census.gov/geo/tiger/GENZ2023/shp/cb_2023_us_state_500k.zip)
   into a `census_states` folder next to the code.
1. In MATLAB, run `red_team_experiments_rev1`. It takes about 5 minutes,
   most of it the land checks.

Experiment IDs: E1 bias, E2 water, E3 receiver separation, E4 `Fraction`
sensitivity, E5 `MaxRadius_m`, E6 offsets by clutter class.
