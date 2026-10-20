function result=auditCovarianceAwareValidation50Postprocess(root)
%AUDITCOVARIANCEAWAREVALIDATION50POSTPROCESS Read-only publication artifacts.
source=fullfile(root,'results_three_layer_validation','covariance_aware_final_validation50_seed20260721');
out=[source '_postprocess_v1'];required=["validation50_packet_level.csv","validation50_summary.csv", ...
    "validation50_paired_statistics.csv","validation50_bootstrap_ci.csv", ...
    "validation50_runtime_audit.csv","validation50_rda_audit.csv", ...
    "validation50_frozen_method_manifest.txt","COMPLETE"];
assert(exist(source,'dir')==7,'Frozen validation50 source directory is missing: %s',source);
assert(all(isfile(fullfile(source,required))),'Frozen validation50 source is incomplete.');
if exist(out,'dir')==7
    entries=dir(out);assert(~any(~ismember({entries.name},{'.','..'})), ...
        'Refusing to overwrite nonempty postprocess directory: %s',out);
else
    mkdir(out);
end
T=readtable(fullfile(source,'validation50_packet_level.csv'),'TextType','string');
S=readtable(fullfile(source,'validation50_summary.csv'),'TextType','string');
P=readtable(fullfile(source,'validation50_paired_statistics.csv'),'TextType','string');
B=readtable(fullfile(source,'validation50_bootstrap_ci.csv'),'TextType','string');
U=readtable(fullfile(source,'validation50_runtime_audit.csv'),'TextType','string');
R=readtable(fullfile(source,'validation50_rda_audit.csv'),'TextType','string'); %#ok<NASGU>
assert(height(T)==600&&height(S)==12,'Unexpected frozen validation50 row count.');
core=S(:,{'payloadSymbols','method','meanAvgCsiNmse','meanPreLdpcBer','meanSoftEvm', ...
    'effectiveSinrDb','codewordPassRate','meanGoodputMbps','meanProcessingTimeSec'});
writetable(core,fullfile(out,'validation50_core_results_table.csv'));
comparisons=localComparisons(P,B);writetable(comparisons,fullfile(out,'validation50_core_comparisons.csv'));
codewords=localCodewordResults(T);writetable(codewords,fullfile(out,'validation50_codeword_results.csv'));
correlations=localCorrelations(T);writetable(correlations,fullfile(out,'validation50_detection_alignment_correlations.csv'));
localCoreFigure(core,out);localEffectsFigure(comparisons,B,out);localAlignmentFigure(T,out);localRuntimeFigure(U,out);
auditWriteValidation50PublicationTables(out);
localReport(fullfile(out,'validation50_interpretation_report.txt'),core,comparisons,codewords,correlations,source);
localProvenance(fullfile(out,'validation50_postprocess_manifest.txt'),source,required);
result=struct('sourceDirectory',source,'outputDirectory',out,'sourceReadOnly',true, ...
    'coreRows',height(core),'comparisonRows',height(comparisons),'codewordRows',height(codewords), ...
    'correlationRows',height(correlations));
fprintf('validation50 read-only postprocess PASS: %s\n',out);
end

function C=localComparisons(P,B)
refs=["BaseKalmanCausal_EP","FixedRadius3Causal_EP","OJCD_LMMSE_EP_Adapted"];
metrics=["avgCsiNmse","preLdpcBer","softEvm","goodputMbps","processingTimeSec"];
Q=P(ismember(P.referenceMethod,refs)&ismember(P.metric,metrics),:);rows=cell(height(Q),1);
for i=1:height(Q)
    label=Q.metric(i)+":meanPairedDifference";b=B(B.payloadSymbols==Q.payloadSymbols(i)& ...
        B.referenceMethod==Q.referenceMethod(i)&B.metric==label,:);assert(height(b)==1);
    rows{i}=table(Q.payloadSymbols(i),Q.proposedMethod(i),Q.referenceMethod(i),Q.metric(i), ...
        Q.proposedMean(i),Q.referenceMean(i),Q.meanPairedDifference(i),Q.relativeImprovementPercent(i), ...
        Q.proposedWins(i),Q.referenceWins(i),Q.ties(i),b.ciLower,b.ciUpper, ...
        'VariableNames',{'payloadSymbols','proposedMethod','referenceMethod','metric','proposedMean', ...
        'referenceMean','meanPairedDifference','relativeImprovementPercent','proposedWins', ...
        'referenceWins','ties','ciLower','ciUpper'});
end
C=vertcat(rows{:});
end

function C=localCodewordResults(T)
keys=unique(T(:,{'payloadSymbols','nCodeword','method'}),'rows');rows=cell(height(keys),1);
for i=1:height(keys)
    x=T(T.payloadSymbols==keys.payloadSymbols(i)&T.method==keys.method(i),:);
    decoded=sum(x.nCodeword);passed=sum(x.codewordPassRate.*x.nCodeword);
    rows{i}=table(keys.payloadSymbols(i),keys.nCodeword(i),keys.method(i),height(x),decoded,passed, ...
        passed/decoded,mean(x.codewordPass),1-mean(x.codewordPass), ...
        'VariableNames',{'payloadSymbols','codewordsPerPayload','method','physicalPacketCount', ...
        'decodedCodewordCount','passedCodewordCount','codewordPassRate','wholePayloadAllCodewordsPassRate','wholePayloadBler'});
end
C=vertcat(rows{:});
end

function C=localCorrelations(T)
payloads=unique(T.payloadSymbols);methods=unique(T.method,'stable');relations={ ...
    "softEvm","preLdpcBer";"avgCsiNmse","preLdpcBer"};
rows=cell(numel(payloads)*(numel(methods)+1)*size(relations,1),1);cursor=0;
for p=payloads.'
    scopes=["ALL_METHODS";methods];
    for s=1:numel(scopes)
        if scopes(s)=="ALL_METHODS",x=T(T.payloadSymbols==p,:);else,x=T(T.payloadSymbols==p&T.method==scopes(s),:);end
        for r=1:size(relations,1)
            a=x.(relations{r,1});b=x.(relations{r,2});valid=isfinite(a)&isfinite(b);
            cursor=cursor+1;rows{cursor}=table(p,scopes(s),relations{r,1},relations{r,2},nnz(valid), ...
                auditPearsonCorrelation(a(valid),b(valid)),auditSpearmanCorrelation(a(valid),b(valid)), ...
                'VariableNames',{'payloadSymbols','scope','xMetric','yMetric','sampleCount','pearsonR','spearmanRho'});
        end
    end
end
C=vertcat(rows{1:cursor});
end

function localCoreFigure(C,out)
methods=unique(C.method,'stable');payloads=unique(C.payloadSymbols);labels=localLabels(methods);colors=lines(numel(payloads));
f=figure('Visible','off','Color','w','Position',[100 100 1300 820]);tl=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
spec={"meanAvgCsiNmse","CSI NMSE","log";"meanPreLdpcBer","Pre-LDPC BER","log"; ...
    "meanSoftEvm","Soft EVM","linear";"codewordPassRate","Codeword pass rate","linear"};
for q=1:4
    ax=nexttile(tl);hold(ax,'on');values=zeros(numel(methods),numel(payloads));
    for j=1:numel(payloads),for i=1:numel(methods),z=C(C.payloadSymbols==payloads(j)&C.method==methods(i),:);values(i,j)=z.(spec{q,1});end,end
    displayValues=values;if spec{q,3}=="log",displayValues=max(displayValues,1e-8);end
    bars=bar(ax,displayValues,'grouped');for j=1:numel(bars),bars(j).FaceColor=colors(j,:);end
    if spec{q,3}=="log",set(ax,'YScale','log');end
    grid(ax,'on');title(ax,spec{q,2});ylabel(ax,spec{q,2});xticks(ax,1:numel(methods));xticklabels(ax,labels);xtickangle(ax,25);
    if q==1,text(ax,.01,.03,'Lower NMSE indicates better channel tracking accuracy.','Units','normalized','FontSize',9);end
end
legend(nexttile(tl,1),compose('%d symbols',payloads),'Location','best');
title(tl,'Frozen validation50 core metrics (SNR 20 dB, f_d 200 Hz)');
localExport(f,out,'validation50_core_metrics');close(f);
end

function localEffectsFigure(C,B,out)
metrics=["avgCsiNmse","preLdpcBer","softEvm"];metricLabels=["NMSE reduction","BER reduction","EVM reduction"];
refs=["BaseKalmanCausal_EP","FixedRadius3Causal_EP","OJCD_LMMSE_EP_Adapted"];payloads=unique(C.payloadSymbols);colors=lines(numel(refs));
f=figure('Visible','off','Color','w','Position',[100 100 1300 760]);tl=tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
for p=1:numel(payloads)
    for m=1:numel(metrics)
        ax=nexttile(tl);hold(ax,'on');x=1:numel(refs);v=zeros(size(x));lo=v;hi=v;
        for r=1:numel(refs)
            z=C(C.payloadSymbols==payloads(p)&C.metric==metrics(m)&C.referenceMethod==refs(r),:);
            b=B(B.payloadSymbols==payloads(p)&B.referenceMethod==refs(r)& ...
                B.metric==metrics(m)+":relativeImprovementPercent",:);assert(height(b)==1);
            v(r)=z.relativeImprovementPercent;lo(r)=v(r)-b.ciLower;hi(r)=b.ciUpper-v(r);
        end
        for r=1:numel(refs),errorbar(ax,x(r),v(r),lo(r),hi(r),'o','Color',colors(r,:),'MarkerFaceColor',colors(r,:),'LineWidth',1.2);end
        yline(ax,0,':');grid(ax,'on');xticks(ax,x);xticklabels(ax,["Base","FixedR3","OJCD"]);
        ylabel(ax,'Relative improvement (%)');title(ax,sprintf('%d symbols: %s',payloads(p),metricLabels(m)));
    end
end
title(tl,'CovarianceAware paired effects with bootstrap 95% confidence intervals');
localExport(f,out,'validation50_paired_effects');close(f);
end

function localAlignmentFigure(T,out)
payloads=unique(T.payloadSymbols);methods=unique(T.method,'stable');colors=lines(numel(methods));
f=figure('Visible','off','Color','w','Position',[100 100 1300 800]);tl=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for p=1:numel(payloads)
    for relation=1:2
        ax=nexttile(tl);hold(ax,'on');
        for m=1:numel(methods)
            x=T(T.payloadSymbols==payloads(p)&T.method==methods(m),:);
            if relation==1,xv=x.softEvm;xlabelText='Soft EVM';else,xv=x.avgCsiNmse;xlabelText='CSI NMSE';end
            scatter(ax,max(xv,1e-10),x.preLdpcBer,18,colors(m,:),'filled','MarkerFaceAlpha',.55);
        end
        grid(ax,'on');xlabel(ax,xlabelText);ylabel(ax,'Pre-LDPC BER');title(ax,sprintf('%d symbols',payloads(p)));
        if relation==2,set(ax,'XScale','log');end
    end
end
legend(nexttile(tl,1),localLabels(methods),'Location','best','FontSize',8);
title(tl,'Detection alignment by physical packet');localExport(f,out,'validation50_detection_alignment');close(f);
end

function localRuntimeFigure(U,out)
methods=unique(U.method,'stable');payloads=unique(U.payloadSymbols);labels=localLabels(methods);colors=lines(numel(payloads));
meanTime=zeros(numel(methods),numel(payloads));vsBase=meanTime;vsFixed=meanTime;
for i=1:numel(methods),for p=1:numel(payloads),x=U(U.method==methods(i)&U.payloadSymbols==payloads(p),:);meanTime(i,p)=x.meanProcessingTimeSec;vsBase(i,p)=x.relativeRuntimeVsBase;vsFixed(i,p)=x.relativeRuntimeVsFixedRadius3;end,end
f=figure('Visible','off','Color','w','Position',[100 100 1250 520]);tl=tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(tl);bars=bar(ax,meanTime,'grouped');for p=1:numel(bars),bars(p).FaceColor=colors(p,:);end
grid(ax,'on');ylabel(ax,'Mean processing time (s)');xticks(ax,1:numel(methods));xticklabels(ax,labels);xtickangle(ax,25);
legend(ax,compose('%d symbols',payloads),'Location','best');title(ax,'Measured packet processing time');
ax=nexttile(tl);hold(ax,'on');for p=1:numel(payloads),plot(ax,1:numel(methods),vsBase(:,p),'-o','Color',colors(p,:),'LineWidth',1.2);plot(ax,1:numel(methods),vsFixed(:,p),'--s','Color',colors(p,:),'LineWidth',1.2);end
grid(ax,'on');yline(ax,1,':');ylabel(ax,'Runtime multiplier');xticks(ax,1:numel(methods));xticklabels(ax,labels);xtickangle(ax,25);
title(ax,'Solid: vs Base; dashed: vs FixedR3');title(tl,'Frozen validation50 runtime audit');localExport(f,out,'validation50_runtime');close(f);
end

function localExport(f,out,name)
savefig(f,fullfile(out,[name '.fig']));exportgraphics(f,fullfile(out,[name '.png']),'Resolution',600);
exportgraphics(f,fullfile(out,[name '.pdf']),'ContentType','vector');
end

function labels=localLabels(methods)
labels=methods;labels=replace(labels,"BaseKalmanCausal_EP","Base");labels=replace(labels,"FixedRadius3Causal_EP","FixedR3");
labels=replace(labels,"CovarianceAwareLocalDAKalmanCausal_EP","CovAware");labels=replace(labels,"OJCD_LMMSE_EP_Adapted","OJCD");
labels=replace(labels,"OracleDataAidedCausal_EP","Oracle DA");labels=replace(labels,"PerfectCSI_EP","Perfect CSI");
end

function localReport(path,C,P,W,K,source)
f=fopen(path,'w','n','UTF-8');assert(f>=0);cleanup=onCleanup(@()fclose(f));
fprintf(f,'Frozen validation50 interpretation report\nSource (read only): %s\nGenerated only from existing CSV files; no wireless packet was rerun.\n\n',source);
fprintf(f,'Operating point: SNR=20 dB, fd=200 Hz; 50 paired physical packets for each of 169- and 507-symbol payloads.\n');
for payload=unique(C.payloadSymbols).'
    fprintf(f,'\nPayload %d symbols\n',payload);x=C(C.payloadSymbols==payload,:);
    for i=1:height(x),fprintf(f,'  %-42s NMSE %.7g; BER %.7g; soft EVM %.7g; codeword pass %.3f; goodput %.4f Mbps; runtime %.4f s.\n',x.method(i),x.meanAvgCsiNmse(i),x.meanPreLdpcBer(i),x.meanSoftEvm(i),x.codewordPassRate(i),x.meanGoodputMbps(i),x.meanProcessingTimeSec(i));end
    q=P(P.payloadSymbols==payload&ismember(P.metric,["avgCsiNmse","preLdpcBer","softEvm"]),:);
    for i=1:height(q),fprintf(f,'  CovarianceAware vs %-28s %-12s relative improvement %.3f%%; wins/losses/ties %d/%d/%d; paired-difference CI [%.7g, %.7g].\n',q.referenceMethod(i),q.metric(i),q.relativeImprovementPercent(i),q.proposedWins(i),q.referenceWins(i),q.ties(i),q.ciLower(i),q.ciUpper(i));end
end
fprintf(f,'\nCodeword interpretation\ncodewordPassRate is the per-codeword success rate. codewordPass is the whole-payload all-codewords-correct event. The 169-symbol payload contains one codeword; the 507-symbol payload contains three, so their whole-payload pass probabilities are not directly interchangeable. Derived rows=%d.\n',height(W));
fprintf(f,'\nDetection alignment\nPearson and Spearman coefficients were computed from packet-level soft EVM/NMSE and pre-LDPC BER and saved separately (%d rows). Correlation is descriptive and does not establish causality.\n',height(K));
fprintf(f,['\nRequired cautions\n' ...
'1. This is an independent validation at one operating point only: SNR=20 dB and fd=200 Hz.\n' ...
'2. CovarianceAware has lower numerical NMSE than Base, FixedRadius3, and OJCD at both payload lengths in this frozen result.\n' ...
'3. Better performance than a baseline does not mean that the NMSE value exceeds the baseline; lower NMSE indicates better channel tracking accuracy.\n' ...
'4. The FixedRadius3 comparison primarily isolates the value of local RLS observation-covariance modeling because radius and other frozen controls are shared.\n' ...
'5. Oracle data assistance is not a strict upper bound for the complete receiver system; its estimator structure and fusion assumptions remain constrained.\n' ...
'6. PerfectCSI is the ideal CSI detection bound among the reported methods.\n' ...
'7. The paired 95%% CI lower bound for CovarianceAware goodput improvement over FixedRadius3 touches zero in the frozen analysis, so that goodput contrast requires conservative interpretation.\n' ...
'8. These simulated link metrics cannot directly establish real UAV range gain.\n' ...
'9. This experiment is not real-airport or over-the-air validation.\n' ...
'10. A separate SNR scan is needed to localize BLER thresholds and link-margin behavior; it must not be treated as parameter tuning.\n']);
end

function localProvenance(path,source,required)
f=fopen(path,'w','n','UTF-8');assert(f>=0);cleanup=onCleanup(@()fclose(f));fprintf(f,'sourceReadOnly=true\nsource=%s\n',source);
for i=1:numel(required),p=fullfile(source,required(i));fprintf(f,'SHA256 %s %s\n',localSha(p),required(i));end
end
function h=localSha(path),f=fopen(path,'rb');assert(f>=0);c=onCleanup(@()fclose(f));bytes=fread(f,inf,'*uint8');md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));end
