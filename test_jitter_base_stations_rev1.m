classdef test_jitter_base_stations_rev1 < matlab.unittest.TestCase
    %TEST_JITTER_BASE_STATIONS_REV1 Unit tests for jitter_base_stations_rev1.
    %   Run with: runtests("test_jitter_base_stations_rev1")

    properties
        lat
        lon
    end

    methods (TestMethodSetup)
        function make_sites(tc)
            % 500 random sites over the Front Range, fixed seed.
            s = RandStream("mrg32k3a", Seed=7);
            tc.lat = 39.5 + 0.5*rand(s, 500, 1);
            tc.lon = -105.2 + 0.5*rand(s, 500, 1);
        end
    end

    methods (Test)
        function same_seed_same_output(tc)
            [a1, o1] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11);
            [a2, o2] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11);
            tc.verifyEqual([a1 o1], [a2 o2]);
        end

        function different_seed_different_output(tc)
            [a1, ~] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11);
            [a2, ~] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=12);
            tc.verifyNotEqual(a1, a2);
        end

        function global_rng_untouched(tc)
            rng(123); expected = rand(1, 3);
            rng(123); jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11); actual = rand(1, 3);
            tc.verifyEqual(actual, expected);
        end

        function stays_inside_radius(tc)
            [a, o, info] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11);
            moved_m = distance(tc.lat, tc.lon, a, o, wgs84Ellipsoid("m"));
            tc.verifyLessThanOrEqual(moved_m, info.radius_m .* (1 + 1e-9) + 1e-6);
            tc.verifyEqual(moved_m, info.offset_m, AbsTol=1e-6);
        end

        function radius_is_one_third_of_brute_force_nn(tc)
            % Compare against an exhaustive all-pairs geodesic search.
            [~, ~, info] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11);
            n = numel(tc.lat);
            [i_idx, j_idx] = ndgrid(1:n, 1:n);
            d = distance(tc.lat(i_idx), tc.lon(i_idx), tc.lat(j_idx), tc.lon(j_idx), wgs84Ellipsoid("m"));
            d(1:n+1:end) = Inf;
            nn_brute = min(d, [], 2);
            tc.verifyEqual(info.nn_dist_m, nn_brute, RelTol=1e-12);
            tc.verifyEqual(info.radius_m, nn_brute/3, RelTol=1e-12);
        end

        function no_two_sites_meet(tc)
            [a, o, info] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11);
            new_gap = distance(a, o, a(info.nn_idx), o(info.nn_idx), wgs84Ellipsoid("m"));
            tc.verifyGreaterThan(new_gap, info.nn_dist_m/3 - 1e-6);
        end

        function uniform_over_disc_area(tc)
            % Under area-uniform draws, (offset/radius)^2 ~ U(0,1).
            s = RandStream("mrg32k3a", Seed=3);
            lat_big = 35 + 5*rand(s, 20000, 1);
            lon_big = -100 + 5*rand(s, 20000, 1);
            [~, ~, info] = jitter_base_stations_rev1(lat_big, lon_big, Seed=5);
            rho2 = (info.offset_m ./ info.radius_m).^2;
            [h, p] = kstest(rho2, CDF=makedist("Uniform"));
            tc.verifyFalse(logical(h), sprintf("KS p = %.3g", p));
        end

        function duplicates_get_nonzero_radius(tc)
            lat_d = [tc.lat; tc.lat(1)];
            lon_d = [tc.lon; tc.lon(1)];
            [a, o, info] = jitter_base_stations_rev1(lat_d, lon_d, Seed=11);
            tc.verifyGreaterThan(info.radius_m(end), 0);
            tc.verifyEqual(info.radius_m(end), info.radius_m(1));
            tc.verifyNotEqual([a(1) o(1)], [a(end) o(end)]);
        end

        function prefix_stability(tc)
            % Site k's draw depends only on the seed and k, not on later sites.
            [~, ~, info_all] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11);
            [~, ~, info_sub] = jitter_base_stations_rev1(tc.lat(1:400), tc.lon(1:400), Seed=11);
            tc.verifyEqual(info_sub.azimuth_deg, info_all.azimuth_deg(1:400));
        end

        function max_radius_default_is_no_cap(tc)
            [a1, o1] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11);
            [a2, o2] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11, MaxRadius_m=Inf);
            tc.verifyEqual([a2 o2], [a1 o1]);
        end

        function max_radius_caps_only_large_radii(tc)
            [~, ~, info_free] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11);
            cap_m = median(info_free.radius_m);
            [a, o, info_cap] = jitter_base_stations_rev1(tc.lat, tc.lon, Seed=11, MaxRadius_m=cap_m);
            capped = info_free.radius_m > cap_m;
            tc.assertTrue(any(capped) && any(~capped));
            % Capped sites: radius equals the cap and they stay inside it.
            tc.verifyEqual(info_cap.radius_m(capped), repmat(cap_m, nnz(capped), 1));
            moved_m = distance(tc.lat, tc.lon, a, o, wgs84Ellipsoid("m"));
            tc.verifyLessThanOrEqual(moved_m, cap_m*(1 + 1e-9) + 1e-6);
            % Uncapped sites: same radius, same draw, same result as no cap.
            tc.verifyEqual(info_cap.radius_m(~capped), info_free.radius_m(~capped));
            tc.verifyEqual(info_cap.offset_m(~capped), info_free.offset_m(~capped));
            % Same random draws: capped offsets scale by cap/radius.
            tc.verifyEqual(info_cap.azimuth_deg, info_free.azimuth_deg);
            tc.verifyEqual(info_cap.offset_m(capped), ...
                info_free.offset_m(capped) .* cap_m ./ info_free.radius_m(capped), RelTol=1e-12);
        end

        function errors(tc)
            tc.verifyError(@() jitter_base_stations_rev1(tc.lat, tc.lon, Seed=1, MaxRadius_m=0), ?MException);
            tc.verifyError(@() jitter_base_stations_rev1(tc.lat, tc.lon), "jitter_base_stations:noSeed");
            tc.verifyError(@() jitter_base_stations_rev1([1;1], [2;2], Seed=1), "jitter_base_stations:tooFewSites");
            tc.verifyError(@() jitter_base_stations_rev1(tc.lat, tc.lon(1:10), Seed=1), "jitter_base_stations:sizeMismatch");
            tc.verifyError(@() jitter_base_stations_rev1(tc.lat, tc.lon, Seed=1, Fraction=0.6), ?MException);
        end
    end
end
