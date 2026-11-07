function make_figures_rev1(options)
%MAKE_FIGURES_REV1 Draw Figures 1 through 4 of WORKING_PAPER_rev1.
%
%   make_figures_rev1
%   make_figures_rev1(OutputFolder="figures", Seed=42)
%
%   Figure 1  Method schematic. Illustrative points; the random draws use the
%             same formula as jitter_base_stations_rev1.
%   Figure 2  Oahu sites before and after jitter, computed from the HIAK table.
%   Figure 3  Distance moved by clutter class, computed from the HIAK table and
%             checked against red_team_log_rev1.txt (E6).
%   Figure 4  Closer approach and seed-to-seed spread by jitter fraction, read
%             from red_team_log_rev1.txt (E3/E4).
%
%   Writes 300 dpi PNG files. Styling follows briefing_style (NTIA palette,
%   Times New Roman). Requires Mapping Toolbox and Statistics and Machine
%   Learning Toolbox, like the jitter functions.

arguments
    options.InputFile (1,1) string {mustBeFile} = "Rand_Table_RSU_HIAK.xlsx"
    options.LogFile (1,1) string {mustBeFile} = "red_team_log_rev1.txt"
    options.OutputFolder (1,1) string = "figures"
    options.Seed (1,1) double {mustBeInteger, mustBeNonnegative} = 42
end

if ~isfolder(options.OutputFolder)
    mkdir(options.OutputFolder);
end
c = ntia_colors();

bs_table = readtable(options.InputFile);
[lat_j, lon_j, info] = jitter_base_stations_rev1(bs_table.Latitude, bs_table.Longitude, ...
    Seed=options.Seed);

figure_1_method(c, fullfile(options.OutputFolder, "fig1_method.png"));
figure_2_oahu(c, bs_table, lat_j, lon_j, info, options.Seed, ...
    fullfile(options.OutputFolder, "fig2_oahu.png"));
figure_3_by_class(c, bs_table, info, options, fullfile(options.OutputFolder, "fig3_move_by_class.png"));
figure_4_fraction(c, options.LogFile, fullfile(options.OutputFolder, "fig4_fraction.png"));
end

function figure_1_method(c, out_file)
% Three-panel schematic: nearest neighbor, disc of radius d/3, random point.
pts = [0 0; 3 1; -2.6 2.4; -1 -3.6; 3.4 -2.8];  % illustrative positions
d = hypot(pts(2,1), pts(2,2));
radius = d/3;
titles = ["1. Find the nearest" + newline + "neighbor", ...
          "2. Draw a disc with" + newline + "radius d/3", ...
          "3. Move the site to a" + newline + "random point in the disc"];
fig = figure(Visible="off", Color="w", Units="inches", Position=[1 1 6.5 2.6]);
layout = tiledlayout(fig, 1, 3, TileSpacing="compact", Padding="compact");
for k = 1:3
    ax = nexttile(layout);
    hold(ax, "on"); axis(ax, "equal"); axis(ax, "off");
    xlim(ax, [-3.6 4.2]); ylim(ax, [-4.2 5.6]);
    if k == 3
        % Same draw as the model: range = R*sqrt(U1), azimuth = 360*U2.
        draw_stream = RandStream("mrg32k3a", Seed=7);
        u = rand(draw_stream, 2, 1500);
        r = radius .* sqrt(u(1,:));
        az = 360 .* u(2,:);
        scatter(ax, r.*sind(az), r.*cosd(az), 2, c.gray, "filled", MarkerFaceAlpha=0.55);
    end
    scatter(ax, pts(2:end,1), pts(2:end,2), 28, c.gray, "filled");
    scatter(ax, 0, 0, 40, c.dark, "filled");
    text(ax, -3.5, 5.5, titles(k), FontName=c.font, FontSize=9, Color=c.dark, VerticalAlignment="top");
    switch k
        case 1
            plot(ax, [0 pts(2,1)], [0 pts(2,2)], Color=c.blue, LineWidth=1.6);
            text(ax, 1.5, 0.95, "d", FontName=c.font, FontSize=11, FontWeight="bold", ...
                Color=c.blue, HorizontalAlignment="center");
            text(ax, 0, -0.7, "Site", FontName=c.font, FontSize=9, Color=c.dark, ...
                HorizontalAlignment="center", VerticalAlignment="top");
        case 2
            plot(ax, [0 pts(2,1)], [0 pts(2,2)], ":", Color=c.gray, LineWidth=1);
            draw_circle(ax, 0, 0, radius, c.blue, 1.6);
            plot(ax, [0 radius], [0 0], Color=c.blue, LineWidth=1.6);
            text(ax, radius/2, -radius - 0.25, "d/3", FontName=c.font, FontSize=10, ...
                FontWeight="bold", Color=c.blue, HorizontalAlignment="center", VerticalAlignment="top");
        case 3
            draw_circle(ax, 0, 0, radius, c.blue, 1.6);
            new_pt = [0.62 0.48];
            quiver(ax, 0, 0, new_pt(1), new_pt(2), 0, Color=c.blue, LineWidth=1.4, MaxHeadSize=0.9);
            scatter(ax, new_pt(1), new_pt(2), 40, c.blue, "filled");
            text(ax, 0, -1.6, "Gray dots: 1,500 draws," + newline + "even over the area", ...
                FontName=c.font, FontSize=8, Color=c.dark, HorizontalAlignment="center", ...
                VerticalAlignment="top");
    end
end
exportgraphics(fig, out_file, Resolution=300);
close(fig);
end

function figure_2_oahu(c, bs_table, lat_j, lon_j, info, seed, out_file)
% Oahu sites, listed versus jittered, in local east and north kilometers.
in_box = bs_table.Latitude > 21.25 & bs_table.Latitude < 21.72 & ...
         bs_table.Longitude > -158.29 & bs_table.Longitude < -157.64;
lat0 = mean(bs_table.Latitude(in_box));
lon0 = mean(bs_table.Longitude(in_box));
km = wgs84Ellipsoid("km");
[x0, y0] = geodetic2enu(bs_table.Latitude(in_box), bs_table.Longitude(in_box), 0, lat0, lon0, 0, km);
[x1, y1] = geodetic2enu(lat_j(in_box), lon_j(in_box), 0, lat0, lon0, 0, km);
radius_km = info.radius_m(in_box) / 1000;
is_urban = bs_table.Height_M(in_box) == 20;

fig = figure(Visible="off", Color="w", Units="inches", Position=[1 1 6.5 4.6]);
ax = axes(fig);
hold(ax, "on");
for k = 1:numel(x0)
    draw_circle(ax, x0(k), y0(k), radius_km(k), c.light_gray, 0.8);
end
% One line object with NaN breaks joins each listed site to its new site.
link_x = [x0 x1 nan(size(x0))]';
link_y = [y0 y1 nan(size(y0))]';
h_link = plot(ax, link_x(:), link_y(:));
h_listed = scatter(ax, x0, y0, 9, "filled");
h_jitter = scatter(ax, x1, y1, 9, "filled");
briefing_style(ax, Highlight=3);
fig.Position(3:4) = [6.5 4.6];
h_link.Color = c.gray;
h_link.LineWidth = 0.8;
axis(ax, "equal");
ax.YGrid = "off";
ax.YAxis.Color = c.gray;
ax.YAxis.TickLabelColor = c.dark;
xlabel(ax, "East-west distance (km)");
ylabel(ax, "North-south distance (km)");
ax.XLabel.Color = c.dark;
ax.YLabel.Color = c.dark;
ylim(ax, [min(y0) - 1, max(y0) + 5]);
% AutoUpdate off keeps the callout lines added below out of the legend.
legend(ax, [h_listed h_jitter], ["Listed location", sprintf("Jittered location (seed %d)", seed)], ...
    Location="northeast", Box="off", FontName=c.font, FontSize=8, TextColor=c.dark, AutoUpdate="off");

[r_max, i_max] = max(radius_km);
label_at(ax, c, x0(i_max), y0(i_max), x0(i_max) - 2, max(y0) + 3, ...
    sprintf("Isolated site: radius %.1f km", r_max), "left");
label_at(ax, c, median(x0(is_urban)), median(y0(is_urban)), 14, 14, ...
    sprintf("Dense urban sites: radius %.0f-%.0f m", 1000*min(radius_km(is_urban)), ...
    1000*max(radius_km(is_urban))), "center");
exportgraphics(fig, out_file, Resolution=300);
close(fig);
end

function figure_3_by_class(c, bs_table, info, options, out_file)
% Median and 95th-percentile distance moved by clutter class (Height_M).
heights = [20 25 35];
names = ["Urban (20 m)", "Suburban (25 m)", "Rural (35 m)"];
med_m = zeros(1, 3);
p95_m = zeros(1, 3);
for k = 1:3
    moved = info.offset_m(bs_table.Height_M == heights(k));
    med_m(k) = median(moved);
    p95_m(k) = prctile(moved, 95);
end
% Check against the identified run (E6 in the log) when using its seed.
if options.Seed == 42
    logged = regexp(fileread(options.LogFile), ...
        "(\d+) m: +\d+ sites, median NN \d+ m, median offset (\d+) m, 95th pct (\d+) m", "tokens");
    logged = str2double(vertcat(logged{:}));
    if ~isequal(logged(:,1)', heights) || ~isequal(round(med_m), logged(:,2)') || ...
            ~isequal(round(p95_m), logged(:,3)')
        error("make_figures:logMismatch", ...
            "Figure 3 values don't match E6 in %s. Rerun red_team_experiments_rev1.", options.LogFile);
    end
end

fig = figure(Visible="off", Color="w", Units="inches", Position=[1 1 6.5 2.3]);
ax = axes(fig);
hold(ax, "on");
bars = barh(ax, 1:3, med_m, 0.55);
briefing_style(ax, Orientation="horizontal");
fig.Position(3:4) = [6.5 2.3];
bars.FaceColor = "flat";
bars.CData = [c.gray; c.gray; c.blue];
scatter(ax, p95_m, 1:3, 220, c.dark, "|", LineWidth=1.6);
ax.YDir = "reverse";
yticks(ax, 1:3); yticklabels(ax, names);
ylim(ax, [0.4 3.6]);
xlim(ax, [0 4600]);
ax.XLabel.Color = c.dark;
set_comma_ticks(ax, 0:500:4500);
xlabel(ax, sprintf("Distance moved, seed %d (m)", options.Seed));
for k = 1:3
    text(ax, med_m(k) - 40, k, with_commas(med_m(k)), HorizontalAlignment="right", ...
        FontName=c.font, FontSize=8, FontWeight="bold", Color="w");
    text(ax, p95_m(k) + 70, k, "95th percentile " + with_commas(p95_m(k)), ...
        FontName=c.font, FontSize=8, Color=c.dark);
end
exportgraphics(fig, out_file, Resolution=300);
close(fig);
end

function figure_4_fraction(c, log_file, out_file)
% Closer approach (5th percentile) and seed-to-seed spread by jitter fraction.
logged = regexp(fileread(log_file), ...
    "Fraction ([\d.]+): .*?5th pct ([+-]?\d+) m.*?seed-to-seed spread of nearest distance: median (\d+) m", ...
    "tokens");
logged = str2double(vertcat(logged{:}));
if size(logged, 1) ~= 3
    error("make_figures:logFormat", "Expected 3 fraction rows in %s, found %d.", log_file, size(logged, 1));
end
names = ["0.1", "1/3 (default)", "0.45"];
values = {abs(logged(:,2))', logged(:,3)'};
titles = ["Closer approach, 5th percentile (m)", "Seed-to-seed spread, median (m)"];

fig = figure(Visible="off", Color="w", Units="inches", Position=[1 1 6.5 2.4]);
layout = tiledlayout(fig, 1, 2, TileSpacing="compact", Padding="compact");
for p = 1:2
    ax = nexttile(layout);
    hold(ax, "on");
    bars = barh(ax, 1:3, values{p}, 0.55);
    briefing_style(ax, Orientation="horizontal");
    bars.FaceColor = "flat";
    bars.CData = [c.gray; c.blue; c.gray];
    ax.YDir = "reverse";
    yticks(ax, 1:3);
    ylim(ax, [0.4 3.6]);
    if p == 1
        yticklabels(ax, names);
        ylabel(ax, "Jitter fraction", Color=c.dark);
    else
        yticklabels(ax, []);
    end
    xlim(ax, [0 3500]);
    set_comma_ticks(ax, 0:1000:3000);
    title(ax, titles(p), FontWeight="normal", FontSize=9, Color=c.dark);
    for k = 1:3
        weight = "normal";
        if k == 2
            weight = "bold";  % the default fraction
        end
        text(ax, values{p}(k) + 60, k, with_commas(values{p}(k)), FontName=c.font, FontSize=8, ...
            Color=c.dark, FontWeight=weight);
    end
end
fig.Position(3:4) = [6.5 2.4];
exportgraphics(fig, out_file, Resolution=300);
close(fig);
end

function c = ntia_colors()
% NTIA palette (slide-design color reference) and report font.
c.gray = [138 141 145]/255;
c.blue = [86 116 196]/255;
c.dark = [22 51 83]/255;
c.light_gray = [230 230 230]/255;
c.font = "Times New Roman";
end

function draw_circle(ax, x, y, r, color, width)
% rectangle with full curvature draws a circle in data units.
rectangle(ax, Position=[x - r, y - r, 2*r, 2*r], Curvature=[1 1], EdgeColor=color, LineWidth=width);
end

function label_at(ax, c, x, y, tx, ty, label, align)
% Callout: a thin leader line from the point to a text label.
plot(ax, [x tx], [y ty], Color=c.dark, LineWidth=0.6);
text(ax, tx, ty, label, FontName=c.font, FontSize=8, Color=c.dark, ...
    HorizontalAlignment=align, VerticalAlignment="bottom");
end

function set_comma_ticks(ax, ticks)
% Thousands separators on value-axis ticks. Considered xtickformat, which has
% no thousands-separator flag.
xticks(ax, ticks);
xticklabels(ax, with_commas(ticks));
end

function s = with_commas(v)
% Round to whole numbers and insert thousands separators.
s = regexprep(compose("%d", round(v)), "(\d)(?=(\d{3})+$)", "$1,");
end
