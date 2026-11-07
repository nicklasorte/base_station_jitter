function [jitter_table, jitter_info] = jitter_base_station_table_rev1(input_file, seed, options)
%JITTER_BASE_STATION_TABLE_REV1 Jitter the base station locations in a spreadsheet.
%
%   jitter_table = jitter_base_station_table_rev1(input_file, seed)
%   [jitter_table, jitter_info] = jitter_base_station_table_rev1(input_file, seed, ...
%       Fraction=1/3, OutputFile="out.xlsx")
%
%   Reads a base station table, moves each site to a random point within
%   Fraction of the distance to its nearest neighbor (see
%   jitter_base_stations_rev1), and returns the table with new latitude and
%   longitude. Every other column is returned unchanged and in the same
%   order, so the output can replace the input in downstream code.
%
%   Inputs:
%     input_file         - Spreadsheet or text file that readtable can read,
%                          for example Rand_Table_RSU_HIAK.xlsx.
%     seed               - Random number generator seed. The same file,
%                          seed, and Fraction always return the same table.
%
%   Name-value arguments:
%     Fraction           - Jitter radius as a fraction of the nearest-
%                          neighbor distance. Default 1/3. Must be in (0, 0.5).
%     OutputFile         - File to write the jittered table to. Default ""
%                          (no file written). Can't be the input file.
%     LatitudeVariable   - Name of the latitude column. Default "Latitude".
%     LongitudeVariable  - Name of the longitude column. Default "Longitude".
%
%   Outputs:
%     jitter_table - Input table with jittered latitude and longitude.
%     jitter_info  - Per-site table from jitter_base_stations_rev1:
%                    nn_idx, nn_dist_m, radius_m, offset_m, azimuth_deg.
%
%   Example:
%     jitter_table = jitter_base_station_table_rev1("Rand_Table_RSU_HIAK.xlsx", 42, ...
%         OutputFile="Rand_Table_RSU_HIAK_jitter_seed42.xlsx");

arguments
    input_file (1,1) string {mustBeFile}
    seed (1,1) double {mustBeInteger, mustBeNonnegative}
    options.Fraction (1,1) double {mustBePositive, mustBeLessThan(options.Fraction,0.5)} = 1/3
    options.OutputFile (1,1) string = ""
    options.LatitudeVariable (1,1) string = "Latitude"
    options.LongitudeVariable (1,1) string = "Longitude"
end

%%%%% 1) Read and check the table.
bs_table = readtable(input_file, VariableNamingRule="preserve");
var_names = string(bs_table.Properties.VariableNames);
lat_var = options.LatitudeVariable;
lon_var = options.LongitudeVariable;
missing_vars = setdiff([lat_var lon_var], var_names, "stable");
if ~isempty(missing_vars)
    error("jitter_base_station_table:missingColumn", ...
        "%s has no column named %s. Columns found: %s.", ...
        input_file, strjoin(missing_vars, ", "), strjoin(var_names, ", "));
end
lat = bs_table.(lat_var);
lon = bs_table.(lon_var);
if ~isnumeric(lat) || ~isnumeric(lon) || any(~isfinite([lat; lon]))
    error("jitter_base_station_table:badCoordinates", ...
        "%s and %s in %s must be numeric with no blank or NaN rows.", lat_var, lon_var, input_file);
end

%%%%% 2) Jitter.
[lat_new, lon_new, jitter_info] = jitter_base_stations_rev1(lat, lon, ...
    Seed=seed, Fraction=options.Fraction);

jitter_table = bs_table;
jitter_table.(lat_var) = lat_new;
jitter_table.(lon_var) = lon_new;

%%%%% 3) Optionally write the result, never over the input.
if strlength(options.OutputFile) > 0
    % The output can only be the input if it already exists; dir resolves
    % relative paths so two spellings of one file compare equal.
    if isfile(options.OutputFile)
        in_info = dir(input_file);
        out_info = dir(options.OutputFile);
        if strcmp(fullfile(in_info.folder, in_info.name), fullfile(out_info.folder, out_info.name))
            error("jitter_base_station_table:overwriteInput", ...
                "OutputFile is the same as the input file %s. Choose another name.", input_file);
        end
    end
    writetable(jitter_table, options.OutputFile);
end
end
