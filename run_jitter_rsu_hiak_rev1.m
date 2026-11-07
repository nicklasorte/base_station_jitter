%RUN_JITTER_RSU_HIAK_REV1 Jitter the Rand_Table_RSU_HIAK base stations and save a new table.
%
%   Example driver for jitter_base_station_table_rev1. Reads
%   Rand_Table_RSU_HIAK.xlsx (columns Latitude, Longitude, Height_M, AZI,
%   ID), jitters each site within 1/3 of the distance to its nearest
%   neighbor, and writes Rand_Table_RSU_HIAK_jitter_seed<N>.xlsx. Height,
%   azimuth, and ID carry over unchanged, so the output drops into
%   init_sim_folder_FSS_neigh_rev25_fdr_github.m in place of the original.

seed = 42;               % change to draw a different realization
jitter_fraction = 1/3;   % radius as a fraction of nearest-neighbor distance
max_radius_m = Inf;      % cap on the radius in meters; Inf means no cap
input_filename = "Rand_Table_RSU_HIAK.xlsx";
output_filename = sprintf("Rand_Table_RSU_HIAK_jitter_seed%d.xlsx", seed);

tic;
[jitter_table, jitter_info] = jitter_base_station_table_rev1(input_filename, seed, ...
    Fraction=jitter_fraction, MaxRadius_m=max_radius_m, OutputFile=output_filename);
toc;

%%%%% QA summary
fprintf("Sites: %d   Seed: %d   Fraction: %.4f   MaxRadius_m: %g\n", ...
    height(jitter_table), seed, jitter_fraction, max_radius_m);
fprintf("Nearest-neighbor distance (m): median %.1f, min %.1f, max %.1f\n", ...
    median(jitter_info.nn_dist_m), min(jitter_info.nn_dist_m), max(jitter_info.nn_dist_m));
fprintf("Offset (m): median %.1f, 95th pct %.1f, max %.1f\n", ...
    median(jitter_info.offset_m), prctile(jitter_info.offset_m, 95), max(jitter_info.offset_m));
fprintf("Max offset/radius: %.6f (must be <= 1)\n", max(jitter_info.offset_m ./ jitter_info.radius_m));
fprintf("Wrote %s\n", output_filename);
