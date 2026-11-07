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
| `jitter_base_station_table_rev1.m` | Main entry point. Takes a spreadsheet and a seed, returns the jittered table, and optionally writes it. |
| `jitter_base_stations_rev1.m` | Core function. Takes latitude and longitude vectors and a seed. |
| `run_jitter_rsu_hiak_rev1.m` | Example driver that jitters `Rand_Table_RSU_HIAK.xlsx` and prints QA statistics. |
| `test_jitter_base_station_table_rev1.m` | Unit tests for the spreadsheet function. |
| `test_jitter_base_stations_rev1.m` | Unit tests for the core function. |
| `Rand_Table_RSU_HIAK.xlsx` | Original base station table from FSS_Neighborhood (62,113 sites). |

## Usage

From a spreadsheet:

```matlab
[jitter_table, jitter_info] = jitter_base_station_table_rev1("Rand_Table_RSU_HIAK.xlsx", 42, ...
    OutputFile="Rand_Table_RSU_HIAK_jitter_seed42.xlsx");
```

| Argument | Required | Default | Description |
| --- | --- | --- | --- |
| `input_file` | Yes | | Any file `readtable` reads (`.xlsx`, `.csv`). |
| `seed` | Yes | | Nonnegative integer seed. |
| `Fraction` | No | `1/3` | Radius as a fraction of nearest-neighbor distance, in (0, 0.5). |
| `OutputFile` | No | `""` (no file) | Where to write the jittered table. Can't be the input file. |
| `LatitudeVariable` | No | `"Latitude"` | Latitude column name. |
| `LongitudeVariable` | No | `"Longitude"` | Longitude column name. |

The returned table has the same columns, in the same order, as the input.
Only latitude and longitude change.

From vectors already in memory:

```matlab
[lat_new, lon_new, jitter_info] = jitter_base_stations_rev1(lat, lon, Seed=42);
```

`jitter_info` is a table with `nn_idx`, `nn_dist_m`, `radius_m`,
`offset_m`, and `azimuth_deg` for each site.

To jitter the HIAK table, set `seed` in `run_jitter_rsu_hiak_rev1.m` and
run it. `Rand_Table_RSU_HIAK.xlsx` in this repo is the original, unjittered
table, copied from
[FSS_Neighborhood](https://github.com/nicklasorte/FSS_Neighborhood). The
output keeps `Height_M`, `AZI`, and `ID` unchanged, so it replaces the
original file in `init_sim_folder_FSS_neigh_rev25_fdr_github.m`.

## Requirements

MATLAB R2024b or later with the Mapping Toolbox (`wgs84Ellipsoid`,
`geodetic2ecef`, `distance`, `reckon`) and the Statistics and Machine
Learning Toolbox (`knnsearch`, and `kstest` in the tests).

## Tests

```matlab
runtests(["test_jitter_base_stations_rev1", "test_jitter_base_station_table_rev1"])
```

The core tests check that the same seed gives the same output, the global
`rng` state is untouched, every site stays inside its radius, the
nearest-neighbor distance matches an exhaustive all-pairs geodesic search,
no two sites meet, the draws are uniform over the disc area (KS test),
duplicates separate, and bad inputs raise errors.

The spreadsheet tests check that the same seed gives the same table, the
result matches the core function, non-coordinate columns are unchanged,
the output file round-trips, no file is written unless asked, CSV input
and custom column names work, the function refuses to overwrite its input
or accept blank or NaN values in any column, a relative `OutputFile`
resolves against the current folder, two parallel workers writing the same
`OutputFile` never expose a partial file to a reader, and the full HIAK
table jitters cleanly. The two-worker test is filtered, not passed, when no
parallel pool is available.

`OutputFile` is written to a temporary file in the same folder and then
renamed into place atomically, so several servers can write the same seed's
output at once.

## Result on Rand_Table_RSU_HIAK.xlsx (seed 42)

| Metric | Value |
| --- | --- |
| Sites | 62,113 |
| Nearest-neighbor distance, median | 3,259 m |
| Jitter offset, median | 677 m |
| Jitter offset, 95th percentile | 2,918 m |
| Jitter offset, maximum | 103,555 m (an isolated site, 368 km from its neighbor) |
| Run time | 0.18 s |
