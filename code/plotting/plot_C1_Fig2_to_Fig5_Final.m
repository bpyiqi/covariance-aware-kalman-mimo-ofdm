function outputDir = plot_C1_Fig2_to_Fig5_Final(projectRoot, outputDir, overwriteOutput)
%PLOT_C1_FIG2_TO_FIG5_FINAL Reproduce C1 Figs. 2--5 from verified CSVs.
%   Fixed inputs; no channel simulation; no 50-packet or ablation reuse.

if nargin < 1 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin < 2 || isempty(outputDir)
    outputDir = fullfile(projectRoot,'figures');
end
if nargin < 3 || isempty(overwriteOutput)
    overwriteOutput = false;
end
dataDir = fullfile(projectRoot,'data','figure_source');
sourceFiles = { ...
    fullfile(dataDir,'figure2_nmse_snr.csv'), ...
    fullfile(dataDir,'figure3_nmse_doppler.csv'), ...
    fullfile(dataDir,'figure4_preldpc_ber_snr.csv'), ...
    fullfile(dataDir,'figure5_preldpc_ber_doppler.csv')};

listing = dir(fullfile(outputDir,'*'));
hasContent = isfolder(outputDir) && any(~ismember({listing.name},{'.','..'}));
if hasContent && ~overwriteOutput
    error('C1Fig:NonEmptyOutput','Output directory is non-empty: %s',outputDir);
end
if ~isfolder(outputDir), mkdir(outputDir); end
for k = 1:numel(sourceFiles)
    if ~isfile(sourceFiles{k})
        error('C1Fig:MissingFixedCsv','Missing required CSV: %s',sourceFiles{k});
    end
end

% Corrected mapping: the historical script swapped Fig.3 and Fig.4.
specs = { ...
    struct('figure','Fig.2','sweep','SNR','metric','NMSE','xName','snr_db', ...
        'xExpected',[15 20 25],'fixedName','doppler_hz','fixedValue',200, ...
        'methods',{{'Base','Fixed','Proposed'}},'refY',[0 .07], ...
        'refTicks',0:.01:.07,'legend',[.38 .67 .33 .21], ...
        'xLim',[14 26],'xTicks',[15 20 25],'xLabel','SNR (dB)','yLabel','NMSE'), ...
    struct('figure','Fig.3','sweep','Doppler','metric','NMSE','xName','doppler_hz', ...
        'xExpected',[100 200 300],'fixedName','snr_db','fixedValue',20, ...
        'methods',{{'Base','Fixed','Proposed'}},'refY',[.005 .0205], ...
        'refTicks',[.005 .01 .015 .02],'legend',[.38 .58 .34 .23], ...
        'xLim',[80 320],'xTicks',[100 200 300], ...
        'xLabel','Maximum Doppler frequency (Hz)','yLabel','NMSE'), ...
    struct('figure','Fig.4','sweep','SNR','metric','PreLdpcBer','xName','snr_db', ...
        'xExpected',[15 20 25],'fixedName','doppler_hz','fixedValue',200, ...
        'methods',{{'Base','Fixed','Proposed','Perfect CSI'}},'refY',[0 .12], ...
        'refTicks',0:.02:.12,'legend',[.55 .68 .37 .22], ...
        'xLim',[14 26],'xTicks',[15 20 25],'xLabel','SNR (dB)', ...
        'yLabel','Pre-LDPC BER'), ...
    struct('figure','Fig.5','sweep','Doppler','metric','PreLdpcBer','xName','doppler_hz', ...
        'xExpected',[100 200 300],'fixedName','snr_db','fixedValue',20, ...
        'methods',{{'Base','Fixed','Proposed'}},'refY',[.03 .055], ...
        'refTicks',.03:.005:.055,'legend',[.215 .470 .35 .205], ...
        'xLim',[80 320],'xTicks',[100 200 300], ...
        'xLabel','Maximum Doppler frequency (Hz)','yLabel','Pre-LDPC BER')};

tables = cell(1,4); plotData = cell(1,4); used = table(); rangeNotes = strings(4,1);
for k = 1:4
    tables{k} = readAndValidate(sourceFiles{k},specs{k});
    [x,y] = orderedPlotData(tables{k},specs{k});
    plotData{k} = struct('x',x,'y',y);
    [~,rangeNotes(k)] = compatibleYLim(specs{k},y);
    t = tables{k};
    t.source_recovery_csv = repmat(string(sourceFiles{k}),height(t),1);
    used = [used; t]; %#ok<AGROW>
end

for k = 1:4
    fig = drawOriginalStyle(specs{k},plotData{k}.x,plotData{k}.y);
    base = fullfile(outputDir,figureBaseName(specs{k}.figure));
    savefig(fig,[base '.fig']);
    try
        exportgraphics(fig,[base '.svg'],'ContentType','vector','BackgroundColor','white');
    catch svgErr %#ok<NASGU>
        % Older MATLAB releases do not support SVG in exportgraphics.
        print(fig,[base '.svg'],'-dsvg');
    end
    exportgraphics(fig,[base '.png'],'Resolution',600,'BackgroundColor','white');
    close(fig);
end
writetable(used,fullfile(outputDir,'figure_data_used.csv'));
writeProvenance(outputDir,sourceFiles,specs,rangeNotes);
fprintf('Exported corrected C1 Figs. 2--5 to %s\n',outputDir);
end

function T = readAndValidate(fileName,S)
T = readtable(fileName,'TextType','string','VariableNamingRule','preserve');
required = {'figure','sweep','x_value','snr_db','doppler_hz','payload_symbols', ...
    'method','plot_metric','plot_value','packet_count'};
missing = required(~ismember(required,T.Properties.VariableNames));
if ~isempty(missing)
    error('C1Fig:Schema','%s is missing columns: %s',fileName,strjoin(missing,', '));
end
if any(string(T.figure) ~= string(S.figure)), error('C1Fig:FigureLabel','Unexpected figure label in %s.',fileName); end
if any(string(T.sweep) ~= string(S.sweep)), error('C1Fig:Sweep','Unexpected sweep label in %s.',fileName); end
if any(string(T.plot_metric) ~= string(S.metric)), error('C1Fig:Metric','Unexpected plot metric in %s.',fileName); end
if any(double(T.payload_symbols) ~= 169) || any(double(T.packet_count) ~= 20)
    error('C1Fig:Protocol','Payload or physical-packet count mismatch in %s.',fileName);
end
if any(~isfinite(double(T.plot_value))) || any(~isfinite(double(T.x_value)))
    error('C1Fig:Finite','NaN/Inf detected in %s.',fileName);
end
if any(~ismember(double(T.x_value),S.xExpected)) || numel(unique(double(T.x_value))) ~= numel(S.xExpected)
    error('C1Fig:SweepPoints','Unexpected sweep points in %s.',fileName);
end
if any(double(T.(S.fixedName)) ~= S.fixedValue)
    error('C1Fig:FixedCondition','Fixed condition mismatch in %s.',fileName);
end
methods = cellstr(unique(string(T.method)));
if ~all(ismember(S.methods,methods)) || ~all(ismember(methods,S.methods))
    error('C1Fig:Methods','Method set mismatch in %s.',fileName);
end
for m = 1:numel(S.methods)
    for x = S.xExpected
        hit = string(T.method)==S.methods{m} & double(T.x_value)==x;
        if nnz(hit) ~= 1
            error('C1Fig:Multiplicity','%s/%s/x=%g has %d rows in %s; expected one.', ...
                S.figure,S.methods{m},x,nnz(hit),fileName);
        end
    end
end
end

function [x,Y] = orderedPlotData(T,S)
x = S.xExpected; Y = zeros(numel(S.methods),numel(x));
for m = 1:numel(S.methods)
    for k = 1:numel(x)
        hit = string(T.method)==S.methods{m} & double(T.x_value)==x(k);
        Y(m,k) = double(T.plot_value(find(hit,1,'first')));
    end
end
end

function [yl,note] = compatibleYLim(S,Y)
yl = S.refY; maxY = max(Y,[],'all');
if maxY > yl(2)
    % Preserve all measured data; do not clip a verified point.
    % Include a marker-radius margin as well as the data-center margin.
    yl(2) = ceil((maxY + max(6e-4,0.03*diff(S.refY)))*10000)/10000;
    if yl(2) <= maxY, yl(2) = maxY + max(eps(maxY),1e-6); end
    note = sprintf('reference [%g,%g] extended to [%g,%g] to include max=%0.15g', ...
        S.refY(1),S.refY(2),yl(1),yl(2),maxY);
else
    note = sprintf('reference y-limit retained [%g,%g]',S.refY(1),S.refY(2));
end
end

function fig = drawOriginalStyle(S,X,Y)
blue=[31 82 148]/255; green=[46 133 102]/255; red=[199 56 46]/255; black=[36 36 36]/255;
fig=figure('Color','white','Units','centimeters','Position',[3 3 17.05 12.70], ...
    'PaperPositionMode','auto','Renderer','painters','Visible','off');
ax=axes('Parent',fig,'Units','normalized','Position',[.147 .160 .827 .819], ...
    'FontName','Times New Roman','FontSize',16,'LineWidth',1.15,'TickDir','in', ...
    'TickLength',[.020 .016],'Box','on','XMinorTick','off','YMinorTick','on','Layer','top');
hold(ax,'on'); hs=gobjects(numel(S.methods),1);
for m=1:numel(S.methods)
    switch S.methods{m}
        case 'Base', color=blue; lineStyle='--'; marker='o'; face='white'; markerSize=10.5; lineWidth=2.5;
        case 'Fixed', color=green; lineStyle='--'; marker='s'; face='white'; markerSize=9.0; lineWidth=2.5;
        case 'Proposed', color=red; lineStyle='-'; marker='^'; face=red; markerSize=11.0; lineWidth=3.3;
        case 'Perfect CSI', color=black; lineStyle=':'; marker='d'; face='white'; markerSize=10.0; lineWidth=2.4;
    end
    hs(m)=plot(ax,X,Y(m,:),'Color',color,'LineStyle',lineStyle,'LineWidth',lineWidth, ...
        'Marker',marker,'MarkerSize',markerSize,'MarkerEdgeColor',color,'MarkerFaceColor',face);
end
ax.XLim=S.xLim; ax.XTick=S.xTicks;
xlabel(ax,S.xLabel,'FontName','Times New Roman','FontSize',17);
ylabel(ax,S.yLabel,'FontName','Times New Roman','FontSize',17);
[yl,~]=compatibleYLim(S,Y); ax.YLim=yl; ax.YTick=S.refTicks; ax.YAxis.Exponent=0; ytickformat(ax,'%.3g');

% Use explicit legend proxy objects whose style is copied from the plotted
% series.  Some MATLAB/exportgraphics combinations shorten or normalize the
% line sample when the displayed plot handles are passed directly to legend,
% which can make the dashed Base/Fixed samples look solid.  The proxies carry
% no data (NaN coordinates), so they cannot alter the plotted curves.
hleg=gobjects(numel(S.methods),1);
for m=1:numel(S.methods)
    hleg(m)=plot(ax,[NaN NaN],[NaN NaN], ...
        'Color',hs(m).Color,'LineStyle',hs(m).LineStyle, ...
        'LineWidth',hs(m).LineWidth,'Marker',hs(m).Marker, ...
        'MarkerSize',hs(m).MarkerSize,'MarkerEdgeColor',hs(m).MarkerEdgeColor, ...
        'MarkerFaceColor',hs(m).MarkerFaceColor,'HandleVisibility','off', ...
        'DisplayName',S.methods{m});
end
lgd=legend(ax,hleg,S.methods,'Box','off','FontName','Times New Roman','FontSize',14, ...
    'Interpreter','none','AutoUpdate','off');
% Use a long legend token so dashed styles remain visually identifiable.
try, lgd.ItemTokenSize=[70 18]; catch, end
lgd.Units='normalized'; lgd.Position=S.legend; set(fig,'InvertHardcopy','off'); drawnow;
end

function name = figureBaseName(figLabel)
switch figLabel
    case 'Fig.2', name='Fig2_NMSE_SNR';
    case 'Fig.3', name='Fig3_NMSE_Doppler';
    case 'Fig.4', name='Fig4_PreLDPC_BER_SNR';
    case 'Fig.5', name='Fig5_PreLDPC_BER_Doppler';
    otherwise, error('C1Fig:Name','Unknown figure label %s.',figLabel);
end
end

function writeProvenance(outDir,files,specs,rangeNotes)
fid=fopen(fullfile(outDir,'PLOT_PROVENANCE_README.txt'),'w');
if fid<0, error('C1Fig:WriteFailure','Cannot write plot provenance.'); end
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'C1 Fig.2--Fig.5 final redraw\nGenerated: %s\nMATLAB version: %s\n',datestr(now,31),version);
fprintf(fid,'No channel simulation was run. Only these four fixed recovery CSVs were read:\n');
for k=1:numel(files), fprintf(fid,'  %s\n',files{k}); end
fprintf(fid,'\nCorrected mapping and y-range decisions:\n');
for k=1:numel(specs), fprintf(fid,'  %s: %s / %s; %s\n',specs{k}.figure,specs{k}.metric,specs{k}.sweep,rangeNotes(k)); end
fprintf(fid,'\nStyle source: Word v7 image137/138/140/141 and existing C1 style specification.\n');
fprintf(fid,'Colors: Base #1F5294, Fixed #2E8566, Proposed #C7382E, Perfect CSI #242424.\n');
end
