%RED_TEAM_EXPERIMENTS_REV1 Adversarial checks of the base station jitter method.
%
%   Reproduces every number in RED_TEAM_rev1.md. Needs
%   Rand_Table_RSU_HIAK.xlsx (in this repo) and the public Census
%   cartographic boundary file cb_2023_us_state_500k.shp, from
%   https://www2.census.gov/geo/tiger/GENZ2023/shp/cb_2023_us_state_500k.zip
%   Set land_shapefile below to where you unzipped it.
%
%   Experiments:
%     E1  Displacement bias: is the mean north and east offset zero?
%     E2  Water placement: how many on-land sites does jitter push off land?
%     E3  Separation from protected receivers: does the nearest base station
%         move closer to a fixed receiver, and how much does that vary by seed?
%     E4  Sensitivity of E3 to Fraction.
%     E5  Effect of MaxRadius_m on offsets and on E2.
%     E6  Offsets by clutter class (Height_M 20, 25, 35 m).

input_file = "Rand_Table_RSU_HIAK.xlsx";
land_shapefile = fullfile("census_states", "cb_2023_us_state_500k.shp");
num_seeds = 20;              % jitter realizations for E3
num_receivers = 500;         % synthetic protected receivers for E3
receiver_range_m = [5e3 30e3];  % receiver distance from a random base station
near_radius_m = 10e3;        % "base stations within" radius for E3 counts
ellipsoid_wgs84 = wgs84Ellipsoid("m");

bs_table = readtable(input_file);
lat = bs_table.Latitude;
lon = bs_table.Longitude;
num_sites = numel(lat);
fprintf("Sites: %d\n\n", num_sites);

%%%%% Land mask from the Census 1:500k state boundaries.
if ~isfile(land_shapefile)
    error("red_team:noLandFile", "Download and unzip %s first (see header).", land_shapefile);
end
land = readgeotable(land_shapefile);
on_land_fcn = @(la, lo) on_land_rev1(land, la, lo);
orig_on_land = on_land_fcn(lat, lon);
fprintf("Baseline: %d of %d original sites (%.2f%%) are off land in the Census file.\n\n", ...
    nnz(~orig_on_land), num_sites, 100*mean(~orig_on_land));

%%%%% E1 Displacement bias (seed 42).
[~, ~, info] = jitter_base_stations_rev1(lat, lon, Seed=42);
north_m = info.offset_m .* cosd(info.azimuth_deg);
east_m = info.offset_m .* sind(info.azimuth_deg);
fprintf("E1 bias (seed 42): mean north %.1f m (SE %.1f), mean east %.1f m (SE %.1f), median offset %.1f m\n\n", ...
    mean(north_m), std(north_m)/sqrt(num_sites), mean(east_m), std(east_m)/sqrt(num_sites), median(info.offset_m));

%%%%% E2 + E5 Water placement and the MaxRadius_m cap (seeds 1-5).
cap_list_m = [Inf 5000 2000];
fprintf("E2/E5 water placement and cap (5 seeds each):\n");
for cap_m = cap_list_m
    off_land_pct = zeros(5, 1);
    num_capped = 0;
    max_offset_m = 0;
    for seed = 1:5
        [lat_c, lon_c, info_c] = jitter_base_stations_rev1(lat, lon, Seed=seed, MaxRadius_m=cap_m);
        moved_off = orig_on_land & ~on_land_fcn(lat_c, lon_c);
        off_land_pct(seed) = 100 * nnz(moved_off) / nnz(orig_on_land);
        num_capped = nnz(info.radius_m > cap_m);
        max_offset_m = max(max_offset_m, max(info_c.offset_m));
    end
    fprintf("  MaxRadius_m %-6g: on-land sites pushed off land %.2f%% (range %.2f-%.2f%%), sites capped %d, max offset %.0f m\n", ...
        cap_m, mean(off_land_pct), min(off_land_pct), max(off_land_pct), num_capped, max_offset_m);
end
fprintf("\n");

%%%%% E3 + E4 Separation from synthetic protected receivers.
% Receivers sit 5-30 km from randomly chosen on-land base stations, a
% stand-in for federal sites near deployments. Only public, synthetic
% locations are used.
recv_stream = RandStream("mrg32k3a", Seed=2026);
land_idx = find(orig_on_land);
pick = land_idx(randi(recv_stream, numel(land_idx), num_receivers, 1));
recv_range = receiver_range_m(1) + diff(receiver_range_m) * rand(recv_stream, num_receivers, 1);
recv_az = 360 * rand(recv_stream, num_receivers, 1);
[recv_lat, recv_lon] = reckon(lat(pick), lon(pick), recv_range, recv_az, ellipsoid_wgs84);

[d0_m, n0] = nearest_and_count_rev1(lat, lon, recv_lat, recv_lon, near_radius_m, ellipsoid_wgs84);
fprintf("E3/E4 receivers: %d, original nearest base station median %.0f m\n", num_receivers, median(d0_m));

for fraction = [0.1 1/3 0.45]
    d_m = zeros(num_receivers, num_seeds);
    n_near = zeros(num_receivers, num_seeds);
    for seed = 1:num_seeds
        [lat_s, lon_s] = jitter_base_stations_rev1(lat, lon, Seed=seed, Fraction=fraction);
        [d_m(:, seed), n_near(:, seed)] = nearest_and_count_rev1(lat_s, lon_s, recv_lat, recv_lon, near_radius_m, ellipsoid_wgs84);
    end
    change_m = d_m - d0_m;
    rel_change = change_m ./ d0_m;
    seed_spread_m = max(d_m, [], 2) - min(d_m, [], 2);
    fprintf("  Fraction %.3f: nearest got closer in %.1f%% of receiver-seeds; median change %+.0f m (%+.1f%%); 5th pct %+.0f m (%+.1f%%); worst %+.0f m\n", ...
        fraction, 100*mean(change_m(:) < 0), median(change_m(:)), 100*median(rel_change(:)), ...
        prctile(change_m(:), 5), 100*prctile(rel_change(:), 5), min(change_m(:)));
    fprintf("                  seed-to-seed spread of nearest distance: median %.0f m, 95th pct %.0f m; count within %g km changes in %.1f%% of receiver-seeds (mean count %.2f vs %.2f)\n", ...
        median(seed_spread_m), prctile(seed_spread_m, 95), near_radius_m/1e3, ...
        100*mean(n_near(:) ~= repmat(n0, num_seeds, 1)), mean(n_near(:)), mean(n0));
end
fprintf("\n");

%%%%% E6 Offsets by clutter class (seed 42).
fprintf("E6 offsets by Height_M class (seed 42):\n");
for h = unique(bs_table.Height_M)'
    in_class = bs_table.Height_M == h;
    fprintf("  %2g m: %5d sites, median NN %.0f m, median offset %.0f m, 95th pct %.0f m, max %.0f m\n", ...
        h, nnz(in_class), median(info.nn_dist_m(in_class)), median(info.offset_m(in_class)), ...
        prctile(info.offset_m(in_class), 95), max(info.offset_m(in_class)));
end

function tf = on_land_rev1(land, la, lo)
% Point-in-polygon against every land polygon. Considered inpolygon (planar,
% wrong near the antimeridian) and landmask (not a built-in).
pts = geopointshape(la, lo);
tf = false(numel(la), 1);
for k = 1:height(land)
    tf = tf | reshape(isinterior(land.Shape(k), pts), [], 1);
end
end

function [nearest_m, count_near] = nearest_and_count_rev1(bs_lat, bs_lon, r_lat, r_lon, near_m, ellipsoid)
% Nearest base station and count within near_m for each receiver.
% knnsearch on ECEF finds candidates; exact geodesic distance ranks them.
[bx, by, bz] = geodetic2ecef(ellipsoid, bs_lat, bs_lon, 0);
[rx, ry, rz] = geodetic2ecef(ellipsoid, r_lat, r_lon, 0);
idx = knnsearch([bx by bz], [rx ry rz], K=4);
num_r = numel(r_lat);
d = distance(repmat(r_lat, 1, 4), repmat(r_lon, 1, 4), bs_lat(idx), bs_lon(idx), ellipsoid);
nearest_m = min(d, [], 2);
% Chord distance is shorter than the geodesic, so the chord radius search
% returns a superset; the geodesic check then trims it.
in_range = rangesearch([bx by bz], [rx ry rz], near_m);
count_near = zeros(num_r, 1);
for k = 1:num_r
    j = in_range{k};
    count_near(k) = nnz(distance(r_lat(k), r_lon(k), bs_lat(j), bs_lon(j), ellipsoid) <= near_m);
end
end
