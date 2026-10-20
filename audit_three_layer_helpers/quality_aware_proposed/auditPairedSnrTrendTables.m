function [paired,raw]=auditPairedSnrTrendTables(T,S,methods)
%AUDITPAIREDSNRTRENDTABLES Raw aggregate warnings and paired adjacent-SNR counts.
metrics=["preLdpcBer","softEvm","codewordErrorCount"];summaryMetrics=["meanPreLdpcBer","meanSoftEvm","codewordBler"];
schema=auditCovarianceAwareSnrPairedLocalization20Schema();snr=unique(T.targetSnrDb);rows=cell(numel(methods)*numel(metrics)*max(numel(snr)-1,0),1);cursor=0;
for m=1:numel(methods)
    for q=1:numel(metrics)
        for j=1:numel(snr)-1
            a=sortrows(T(T.method==methods(m)&T.targetSnrDb==snr(j),:),'scenarioIndex');
            b=sortrows(T(T.method==methods(m)&T.targetSnrDb==snr(j+1),:),'scenarioIndex');assert(isequal(a.scenarioIndex,b.scenarioIndex));
            d=b.(metrics(q))-a.(metrics(q));tol=1e-12;cursor=cursor+1;
            rows{cursor}=table(methods(m),metrics(q),snr(j),snr(j+1),nnz(d<-tol),nnz(d>tol),nnz(abs(d)<=tol),'VariableNames',cellstr(schema.trends));
        end
    end
end
if cursor==0,paired=cell2table(cell(0,numel(schema.trends)),'VariableNames',cellstr(schema.trends));else,paired=vertcat(rows{1:cursor});end
rawRows=cell(numel(methods)*numel(metrics),1);cursor=0;
for m=1:numel(methods),for q=1:numel(metrics),x=sortrows(S(S.method==methods(m),:),'targetSnrDb');cursor=cursor+1;rawRows{cursor}=table(methods(m),metrics(q),any(diff(x.(summaryMetrics(q)))>1e-12),'VariableNames',cellstr(schema.rawWarnings));end,end
raw=vertcat(rawRows{:});
end
