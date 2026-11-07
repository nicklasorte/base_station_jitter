function briefing_style(ax, opts)
%BRIEFING_STYLE Apply decluttered NTIA styling (mid gray plus light blue).
%
%   briefing_style(ax) styles the axes for a 6.5 in report figure.
%   briefing_style(ax, Medium="slide") sizes text for a slide image.
%   briefing_style(ax, Highlight=2) colors the 2nd plotted line or bar
%   series with the accent and the rest gray.
%   briefing_style(ax, Orientation="horizontal") puts the zero baseline
%   on the y-axis and gridlines on x, for barh charts.
%
%   Export for Office with:
%       exportgraphics(ancestor(ax,"figure"), "fig.emf", ContentType="vector")
%   or for other uses:
%       exportgraphics(ancestor(ax,"figure"), "fig.png", Resolution=300)

arguments
    ax (1,1) matlab.graphics.axis.Axes = gca
    opts.Medium (1,1) string {mustBeMember(opts.Medium, ["report","slide"])} = "report"
    opts.Highlight double = []
    opts.Orientation (1,1) string {mustBeMember(opts.Orientation, ["vertical","horizontal"])} = "vertical"
    opts.Accent (1,3) double = [86 116 196]/255     % NTIA light blue
    opts.FontName (1,1) string = "Times New Roman" % July 2026 NTIA style guide
end

grayText    = [22 51 83]/255;     % NTIA dark blue
grayContext = [138 141 145]/255;  % mid gray
grayGrid    = [230 230 230]/255;
grayBase    = [138 141 145]/255;

if opts.Medium == "slide"
    fontSize = 16;
    figSize  = [10 5.2];   % inches, for a chart that fills most of a slide
else
    fontSize = 9;
    figSize  = [6.5 3.6];  % inches, one report column
end

fig = ancestor(ax, "figure");
fig.Color = "w";
fig.Units = "inches";
fig.Position(3:4) = figSize;

box(ax, "off")
ax.Color      = "w";
ax.FontName   = opts.FontName;
ax.FontSize   = fontSize;
ax.TickDir    = "out";
ax.TickLength = [0 0];
ax.LineWidth  = 0.75;
ax.XColor     = grayText;
ax.YColor     = grayText;
ax.XGrid      = "off";
ax.YGrid      = "on";
if opts.Orientation == "horizontal"
    ax.XGrid = "on";
    ax.YGrid = "off";
end
ax.GridColor  = grayGrid;
ax.GridAlpha  = 1;
ax.Title.FontWeight = "bold";
ax.TitleHorizontalAlignment = "left";

% Quiet zero baseline on the category axis; hide the value-axis line.
if opts.Orientation == "horizontal"
    baseAxis = ax.YAxis(1); valueAxis = ax.XAxis;
else
    baseAxis = ax.XAxis; valueAxis = ax.YAxis(1);
end
baseAxis.Color = grayBase;
baseAxis.TickLabelColor = grayText;
valueAxis.Color = "none";
valueAxis.TickLabelColor = grayText;
valueAxis.Label.Color = grayText;

% Gray plus accent on plotted series (Children are in reverse plot order).
series = flipud(findobj(ax.Children, "-depth", 0, ...
    {"Type","line","-or","Type","bar","-or","Type","scatter","-or","Type","area"}));
if ~isempty(opts.Highlight) || numel(series) > 1
    hl = opts.Highlight;
    if isempty(hl), hl = 1; end
    for k = 1:numel(series)
        c = grayContext;
        if ismember(k, hl), c = opts.Accent; end
        s = series(k);
        switch s.Type
            case "line"
                s.Color = c;
                s.LineWidth = 2 + ismember(k, hl);
            case "bar"
                s.FaceColor = c;
                s.EdgeColor = "none";
            case "scatter"
                s.MarkerFaceColor = c;
                s.MarkerEdgeColor = "none";
            case "area"
                s.FaceColor = c;
                s.EdgeColor = "none";
        end
    end
elseif isscalar(series)
    s = series(1);
    switch s.Type
        case "line",    s.Color = opts.Accent; s.LineWidth = 2;
        case "bar",     s.FaceColor = opts.Accent; s.EdgeColor = "none";
        case "scatter", s.MarkerFaceColor = opts.Accent; s.MarkerEdgeColor = "none";
        case "area",    s.FaceColor = opts.Accent; s.EdgeColor = "none";
    end
end

% Prefer direct labels; remove any legend.
legend(ax, "off")
end
