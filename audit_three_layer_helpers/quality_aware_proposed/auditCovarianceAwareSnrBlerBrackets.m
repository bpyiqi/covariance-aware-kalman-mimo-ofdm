function B=auditCovarianceAwareSnrBlerBrackets(S,methods,target)
%AUDITCOVARIANCEAWARESNRBLERBRACKETS Locate adjacent raw-BLER target crossings.
names=auditCovarianceAwareSnrLocalization10Schema().brackets;rows=cell(numel(methods),1);
for m=1:numel(methods)
    x=sortrows(S(S.method==methods(m),:),'SNRdB');snr=x.SNRdB;bler=x.codewordBler;
    warningFlag=any(diff(bler)>1e-12);index=find(bler(1:end-1)>=target&bler(2:end)<=target,1);
    if isempty(index)
        lowerSnr=NaN;lowerBler=NaN;upperSnr=NaN;upperBler=NaN;found=false;
    else
        lowerSnr=snr(index);lowerBler=bler(index);upperSnr=snr(index+1);upperBler=bler(index+1);found=true;
    end
    rows{m}=table(methods(m),target,lowerSnr,lowerBler,upperSnr,upperBler,found,warningFlag,'VariableNames',cellstr(names));
end
B=vertcat(rows{:});
end

