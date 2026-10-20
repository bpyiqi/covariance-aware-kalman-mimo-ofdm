function [B,C]=auditDirectionalBlerBracketAudit(S,methods,target)
%AUDITDIRECTIONALBLERBRACKETAUDIT Preserve and classify every raw target crossing.
summaryRows=cell(numel(methods),1);crossRows=cell(max(height(S)-numel(methods),0),1);crossCursor=0;tol=1e-12;
for m=1:numel(methods)
    x=sortrows(S(S.method==methods(m),:),'targetSnrDb');b=x.codewordBler;snr=x.targetSnrDb;exact=abs(b-target)<=tol;
    validCount=0;reverseCount=0;
    for i=1:numel(b)-1
        valid=snr(i)<snr(i+1)&&b(i)>target+tol&&b(i+1)<target-tol;
        reverse=snr(i)<snr(i+1)&&b(i)<target-tol&&b(i+1)>target+tol;
        if valid||reverse
            crossCursor=crossCursor+1;crossRows{crossCursor}=table(methods(m),snr(i),snr(i+1),b(i),b(i+1),valid,reverse, ...
                'VariableNames',{'method','lowerSnrDb','upperSnrDb','lowerBler','upperBler','validDirectionalBracket','reverseCrossingWarning'});
        end
        validCount=validCount+valid;reverseCount=reverseCount+reverse;
    end
    plateau=any(exact(1:end-1)&exact(2:end));hit=any(exact);if hit,hitSnr=snr(find(exact,1));else,hitSnr=NaN;end
    warning=any(diff(b)>tol)||validCount+reverseCount>1;
    summaryRows{m}=table(methods(m),target,validCount>0,validCount,reverseCount>0,reverseCount,hit,hitSnr,plateau,warning, ...
        'VariableNames',{'method','targetBler','validDirectionalBracket','validCrossingCount','reverseCrossingWarning', ...
        'reverseCrossingCount','exactGridHit','exactGridSnrDb','targetPlateau','monotonicityWarning'});
end
B=vertcat(summaryRows{:});if crossCursor==0,C=cell2table(cell(0,7),'VariableNames',{'method','lowerSnrDb','upperSnrDb','lowerBler','upperBler','validDirectionalBracket','reverseCrossingWarning'});else,C=vertcat(crossRows{1:crossCursor});end
end
