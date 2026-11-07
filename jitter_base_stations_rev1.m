function [lat_new, lon_new, jitter_info] = jitter_base_stations_rev1(lat, lon, options)
%JITTER_BASE_STATIONS_REV1 Move each base station to a random point near its location.
%
%   [lat_new, lon_new] = jitter_base_stations_rev1(lat, lon, Seed=42)
%   [lat_new, lon_new, jitter_info] = jitter_base_stations_rev1(lat, lon, Seed=42, Fraction=1/3)
%
%   For each base station, the function:
%     1. Finds the nearest other base station at a distinct location.
%     2. Sets the jitter radius to Fraction times that geodesic distance.
%     3. Draws a point uniformly over the disc of that radius and moves the
%        base station there.
%
%   Inputs:
%     lat, lon   - Base station latitude and longitude, in degrees (N-by-1).
%     Seed       - Random number generator seed. The same seed and input
%                  order always return the same output.
%     Fraction   - Jitter radius as a fraction of the nearest-neighbor
%                  distance. Default 1/3. Must be in (0, 0.5) so that two
%                  jittered sites can never meet.
%     Ellipsoid  - Reference ellipsoid for distances. Default WGS 84.
%
%   Outputs:
%     lat_new, lon_new - Jittered latitude and longitude, in degrees (N-by-1).
%     jitter_info      - Table with one row per base station:
%                        nn_idx       index of the nearest distinct neighbor
%                        nn_dist_m    geodesic distance to that neighbor (m)
%                        radius_m     jitter radius, Fraction*nn_dist_m (m)
%                        offset_m     distance moved (m)
%                        azimuth_deg  direction moved, clockwise from north
%
%   Duplicate locations: sites that share a location use the nearest
%   distinct location as their neighbor, so each one still gets a nonzero
%   radius and they separate after jitter.
%
%   Reproducibility: draws come from a local RandStream (mrg32k3a), so the
%   global rng state is untouched. Each site uses two consecutive draws
%   (range, then azimuth), so site k's offset depends only on the seed and
%   on k's position in the list.

arguments
    lat (:,1) double {mustBeFinite, mustBeGreaterThanOrEqual(lat,-90), mustBeLessThanOrEqual(lat,90)}
    lon (:,1) double {mustBeFinite}
    options.Seed (1,1) double {mustBeInteger, mustBeNonnegative}
    options.Fraction (1,1) double {mustBePositive, mustBeLessThan(options.Fraction,0.5)} = 1/3
    options.Ellipsoid = wgs84Ellipsoid("m")
end

if ~isfield(options, "Seed")
    error("jitter_base_stations:noSeed", ...
        "Seed is required so the jitter is repeatable, for example Seed=42.");
end
num_sites = numel(lat);
if numel(lon) ~= num_sites
    error("jitter_base_stations:sizeMismatch", ...
        "lat has %d elements and lon has %d; they must match.", num_sites, numel(lon));
end

%%%%% 1) Collapse duplicate locations so each site's neighbor is a distinct location.
[unique_latlon, idx_first, idx_map] = unique([lat lon], "rows", "stable");
num_unique = size(unique_latlon, 1);
if num_unique < 2
    error("jitter_base_stations:tooFewSites", ...
        "Need at least two distinct locations to define a jitter radius; found %d.", num_unique);
end

%%%%% 2) Nearest-neighbor candidates with a k-d tree in ECEF coordinates.
% knnsearch has no geodesic metric, so candidates come from 3-D chord
% distance (monotonic with great-circle distance) and the exact WGS-84
% geodesic distance picks the winner among the closest few.
[x_ecef, y_ecef, z_ecef] = geodetic2ecef(options.Ellipsoid, unique_latlon(:,1), unique_latlon(:,2), 0);
xyz = [x_ecef y_ecef z_ecef];
num_candidates = min(4, num_unique);  % self + 3 candidates
[idx_knn, ~] = knnsearch(xyz, xyz, K=num_candidates);

% Drop self: the first column is the query point itself (unique rows, so
% no zero-distance neighbor can be another site).
idx_cand = idx_knn(:, 2:end);
lat_u = unique_latlon(:,1);
lon_u = unique_latlon(:,2);
dist_cand = distance(repmat(lat_u, 1, num_candidates-1), repmat(lon_u, 1, num_candidates-1), ...
    lat_u(idx_cand), lon_u(idx_cand), options.Ellipsoid);
[nn_dist_unique, col_min] = min(dist_cand, [], 2);
nn_unique = idx_cand(sub2ind(size(idx_cand), (1:num_unique)', col_min));

%%%%% 3) Map back to every input site (duplicates share their location's neighbor).
nn_dist_m = nn_dist_unique(idx_map);
nn_idx = idx_first(nn_unique(idx_map));
radius_m = options.Fraction .* nn_dist_m;

%%%%% 4) Uniform draw over each disc: range = R*sqrt(U1), azimuth = 360*U2.
% sqrt(U1) makes the density uniform over area; a plain R*U1 would pile
% points near the center.
rand_stream = RandStream("mrg32k3a", Seed=options.Seed);
u = rand(rand_stream, 2, num_sites);
offset_m = radius_m .* sqrt(u(1,:)');
azimuth_deg = 360 .* u(2,:)';

%%%%% 5) Move each site along the geodesic on the ellipsoid.
[lat_new, lon_new] = reckon(lat, lon, offset_m, azimuth_deg, options.Ellipsoid);

if nargout > 2
    jitter_info = table(nn_idx, nn_dist_m, radius_m, offset_m, azimuth_deg);
end
end
