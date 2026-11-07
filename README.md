# base_station_jitter

Seeded, repeatable jitter of base station latitude and longitude.

## Why

The deployment tables used in the FSS Neighborhood analysis, such as
`Rand_Table_RSU_HIAK.xlsx`, give approximate base station locations, not
surveyed ones. This code turns one approximate table into many plausible
layouts. Each seed gives one realization, so you can run the interference
analysis over several seeds and see how sensitive the result is to where
the base stations actually sit.

## Method

For each base station:

1. Find the nearest other base station at a distinct location.
1. Set the jitter radius to 1/3 of the WGS 84 geodesic distance to that
   neighbor.
1. Draw a point uniformly over the disc of that radius
   (`range = R*sqrt(U1)`, `azimuth = 360*U2`) and move the base station
   there with `reckon` on the WGS 84 ellipsoid.

Properties that follow from this design:

- **Dense areas move a little; sparse areas move more.** The radius scales
  with local spacing.
- **No two sites can meet or swap.** Each site moves at most 1/3 of its
  nearest-neighbor distance, so any two sites stay at least 1/3 of their
  original separation apart. This is why `Fraction` must be less than 0.5.
- **Repeatable.** Draws come from a local `RandStream("mrg32k3a")` seeded
  by `Seed`, so the global `rng` state is not touched. Each site uses two
  consecutive draws, so a site's offset depends only on the seed and its
  row position.
- **Duplicate locations separate.** Sites that share a location use the
  nearest distinct location as their neighbor, so each gets a nonzero
  radius.

Nearest neighbors come from `knnsearch` (k-d tree) on ECEF coordinates
from `geodetic2ecef`, then the exact geodesic distance from `distance`
picks the closest of the top three candidates.

## Files

| File | Purpose |
| --- | --- |
| `jitter_base_stations_rev1.m` | The jitter function. |
| `run_jitter_rsu_hiak_rev1.m` | Jitters `Rand_Table_RSU_HIAK.xlsx` and writes `Rand_Table_RSU_HIAK_jitter_seed<N>.xlsx` with the same columns. |
| `test_jitter_base_stations_rev1.m` | Unit tests. |

## Usage

```matlab
[lat_new, lon_new, jitter_info] = jitter_base_stations_rev1(lat, lon, Seed=42);
[lat_new, lon_new] = jitter_base_stations_rev1(lat, lon, Seed=42, Fraction=1/3);
```

`jitter_info` is a table with `nn_idx`, `nn_dist_m`, `radius_m`,
`offset_m`, and `azimuth_deg` for each site.

To jitter the HIAK table, copy `Rand_Table_RSU_HIAK.xlsx` from
[FSS_Neighborhood](https://github.com/nicklasorte/FSS_Neighborhood) into
this folder, set `seed` in `run_jitter_rsu_hiak_rev1.m`, and run it. The
output keeps `Height_M`, `AZI`, and `ID` unchanged, so it replaces the
original file in `init_sim_folder_FSS_neigh_rev25_fdr_github.m`.

## Requirements

MATLAB R2024b or later with the Mapping Toolbox (`wgs84Ellipsoid`,
`geodetic2ecef`, `distance`, `reckon`) and the Statistics and Machine
Learning Toolbox (`knnsearch`, and `kstest` in the tests).

## Tests

```matlab
runtests("test_jitter_base_stations_rev1")
```

The tests check that the same seed gives the same output, the global
`rng` state is untouched, every site stays inside its radius, the
nearest-neighbor distance matches an exhaustive all-pairs geodesic search,
no two sites meet, the draws are uniform over the disc area (KS test),
duplicates separate, and bad inputs raise errors.

## Result on Rand_Table_RSU_HIAK.xlsx (seed 42)

| Metric | Value |
| --- | --- |
| Sites | 62,113 |
| Nearest-neighbor distance, median | 3,259 m |
| Jitter offset, median | 677 m |
| Jitter offset, 95th percentile | 2,918 m |
| Jitter offset, maximum | 103,555 m (an isolated site, 368 km from its neighbor) |
| Run time | 0.18 s |
