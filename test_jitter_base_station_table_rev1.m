classdef test_jitter_base_station_table_rev1 < matlab.unittest.TestCase
    %TEST_JITTER_BASE_STATION_TABLE_REV1 Unit tests for jitter_base_station_table_rev1.
    %   Run with: runtests("test_jitter_base_station_table_rev1")

    properties
        work_folder
        input_file
        input_table
    end

    methods (TestMethodSetup)
        function make_input(tc)
            % 300 synthetic sites in the HIAK column layout, in a temp folder.
            fixture = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.work_folder = string(fixture.Folder);
            s = RandStream("mrg32k3a", Seed=9);
            n = 300;
            Latitude = 21 + 0.4*rand(s, n, 1);
            Longitude = -158.2 + 0.5*rand(s, n, 1);
            Height_M = 20 + 15*(rand(s, n, 1) > 0.5);
            AZI = zeros(n, 1);
            ID = (1:n)';
            tc.input_table = table(Latitude, Longitude, Height_M, AZI, ID);
            tc.input_file = fullfile(tc.work_folder, "sites.xlsx");
            writetable(tc.input_table, tc.input_file);
        end
    end

    methods (Test)
        function same_seed_same_table(tc)
            t1 = jitter_base_station_table_rev1(tc.input_file, 42);
            t2 = jitter_base_station_table_rev1(tc.input_file, 42);
            tc.verifyEqual(t1, t2);
        end

        function different_seed_different_table(tc)
            t1 = jitter_base_station_table_rev1(tc.input_file, 42);
            t2 = jitter_base_station_table_rev1(tc.input_file, 43);
            tc.verifyNotEqual(t1.Latitude, t2.Latitude);
        end

        function matches_core_function(tc)
            [t, info] = jitter_base_station_table_rev1(tc.input_file, 42, Fraction=0.25);
            [lat_ref, lon_ref, info_ref] = jitter_base_stations_rev1( ...
                tc.input_table.Latitude, tc.input_table.Longitude, Seed=42, Fraction=0.25);
            tc.verifyEqual([t.Latitude t.Longitude], [lat_ref lon_ref]);
            tc.verifyEqual(info, info_ref);
        end

        function other_columns_unchanged(tc)
            t = jitter_base_station_table_rev1(tc.input_file, 42);
            tc.verifyEqual(t.Properties.VariableNames, tc.input_table.Properties.VariableNames);
            tc.verifyEqual(t(:, ["Height_M" "AZI" "ID"]), tc.input_table(:, ["Height_M" "AZI" "ID"]));
            tc.verifyNotEqual(t.Latitude, tc.input_table.Latitude);
        end

        function writes_output_file(tc)
            out_file = fullfile(tc.work_folder, "sites_jitter.xlsx");
            t = jitter_base_station_table_rev1(tc.input_file, 42, OutputFile=out_file);
            tc.assertTrue(isfile(out_file));
            t_read = readtable(out_file);
            tc.verifyEqual(t_read{:,:}, t{:,:}, AbsTol=1e-12);
        end

        function no_output_file_by_default(tc)
            jitter_base_station_table_rev1(tc.input_file, 42);
            files = dir(fullfile(tc.work_folder, "*.xlsx"));
            tc.verifyEqual(string({files.name}), "sites.xlsx");
        end

        function csv_and_custom_column_names(tc)
            renamed = renamevars(tc.input_table, ["Latitude" "Longitude"], ["lat_deg" "lon_deg"]);
            csv_file = fullfile(tc.work_folder, "sites.csv");
            writetable(renamed, csv_file);
            t = jitter_base_station_table_rev1(csv_file, 42, ...
                LatitudeVariable="lat_deg", LongitudeVariable="lon_deg");
            t_ref = jitter_base_station_table_rev1(tc.input_file, 42);
            tc.verifyEqual(t.lat_deg, t_ref.Latitude, AbsTol=1e-12);
        end

        function errors(tc)
            tc.verifyError(@() jitter_base_station_table_rev1(tc.input_file, 42, OutputFile=tc.input_file), ...
                "jitter_base_station_table:overwriteInput");
            tc.verifyError(@() jitter_base_station_table_rev1(tc.input_file, 42, LatitudeVariable="Lat"), ...
                "jitter_base_station_table:missingColumn");
            tc.verifyError(@() jitter_base_station_table_rev1(fullfile(tc.work_folder, "nope.xlsx"), 42), ...
                ?MException);
            tc.verifyError(@() jitter_base_station_table_rev1(tc.input_file, 1.5), ?MException);

            bad = tc.input_table; bad.Latitude(5) = NaN;
            bad_file = fullfile(tc.work_folder, "bad.xlsx");
            writetable(bad, bad_file);
            tc.verifyError(@() jitter_base_station_table_rev1(bad_file, 42), ...
                "jitter_base_station_table:badCoordinates");

            % A blank in a non-coordinate column reads as NaN; fail, don't pass it through.
            blank = tc.input_table; blank.Height_M(7) = NaN;
            blank_file = fullfile(tc.work_folder, "blank.xlsx");
            writetable(blank, blank_file);
            tc.verifyError(@() jitter_base_station_table_rev1(blank_file, 42), ...
                "jitter_base_station_table:missingValues");
        end

        function relative_output_path(tc)
            % A relative OutputFile resolves against pwd, not the JVM folder.
            tc.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(tc.work_folder));
            jitter_base_station_table_rev1("sites.xlsx", 42, OutputFile="rel_out.xlsx");
            tc.verifyTrue(isfile(fullfile(tc.work_folder, "rel_out.xlsx")));
            tc.verifyEmpty(dir(fullfile(tc.work_folder, "*.part_*")));
        end

        function two_servers_same_output_file(tc)
            % Two workers write the same OutputFile while this process polls it.
            % A reader must never see a partial file, and no temp files remain.
            tc.assumeTrue(canUseParallelPool, "No parallel pool available.");
            pool = gcp("nocreate");
            if isempty(pool)
                pool = parpool(2);
            end
            tc.assumeGreaterThanOrEqual(pool.NumWorkers, 2, "Need two workers.");
            code_folder = fileparts(which("jitter_base_station_table_rev1"));
            parfevalOnAll(pool, @addpath, 0, code_folder);
            out_file = fullfile(tc.work_folder, "shared_out.xlsx");
            f1 = parfeval(pool, @jitter_base_station_table_rev1, 1, tc.input_file, 42, OutputFile=out_file);
            f2 = parfeval(pool, @jitter_base_station_table_rev1, 1, tc.input_file, 42, OutputFile=out_file);
            num_bad = 0;
            num_polls = 0;
            while ~(strcmp(f1.State, "finished") && strcmp(f2.State, "finished"))
                if isfile(out_file)
                    num_polls = num_polls + 1;
                    try
                        if height(readtable(out_file)) ~= height(tc.input_table)
                            num_bad = num_bad + 1;
                        end
                    catch
                        num_bad = num_bad + 1;
                    end
                end
            end
            tc.verifyEmpty(f1.Error);
            tc.verifyEmpty(f2.Error);
            tc.verifyEqual(num_bad, 0, sprintf("%d of %d polled reads were partial.", num_bad, num_polls));
            tc.verifyEqual(height(readtable(out_file)), height(tc.input_table));
            tc.verifyEmpty(dir(fullfile(tc.work_folder, "*.part_*")));
        end

        function hiak_table_smoke(tc)
            % Runs only when the repo's HIAK table is on the path.
            hiak = which("Rand_Table_RSU_HIAK.xlsx");
            tc.assumeNotEmpty(hiak, "Rand_Table_RSU_HIAK.xlsx not on the path.");
            [t, info] = jitter_base_station_table_rev1(hiak, 42);
            tc.verifyEqual(height(t), 62113);
            tc.verifyLessThanOrEqual(max(info.offset_m ./ info.radius_m), 1);
            tc.verifyEqual(height(unique(t(:, ["Latitude" "Longitude"]))), height(t));
        end
    end
end
