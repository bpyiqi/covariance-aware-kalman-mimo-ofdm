function B=auditPairedSnrStrictBrackets(S,methods,target)
%AUDITPAIREDSNRSTRICTBRACKETS Strict raw-grid crossing, exact-hit, and plateau audit.
names=auditCovarianceAwareSnrPairedLocalization20Schema().brackets;rows=cell(numel(methods),1);tol=1e-12;
for m=1:numel(methods)
    x=sortrows(S(S.method==methods(m),:),'targetSnrDb');snr=x.targetSnrDb;b=x.codewordBler;
    exact=abs(b-target)<=tol;plateau=any(exact(1:end-1)&exact(2:end));
    cross=(b(1:end-1)>target+tol)&(b(2:end)<target-tol);
    reverseCrossing=any((b(1:end-1)<target-tol)&(b(2:end)>target+tol));
    index=find(cross,1);found=~isempty(index);
    if found,ls=snr(index);lb=b(index);us=snr(index+1);ub=b(index+1);else,ls=NaN;lb=NaN;us=NaN;ub=NaN;end
    hit=any(exact);if hit,hitSnr=snr(find(exact,1));else,hitSnr=NaN;end
    warningFlag=any(diff(b)>tol);ciContains=any(x.codewordBlerCiLower<=target&x.codewordBlerCiUpper>=target);
    if found,suggestion="none";elseif all(b>target+tol),suggestion="extend_higher_snr";elseif all(b<target-tol),suggestion="extend_lower_snr";elseif hit,suggestion="exact_grid_hit_no_interpolation";else,suggestion="denser_neighboring_grid";end
    rows{m}=table(methods(m),target,ls,lb,us,ub,found,found,reverseCrossing,hit,hitSnr,plateau,warningFlag,ciContains,suggestion,'VariableNames',cellstr(names));
end
B=vertcat(rows{:});
end
