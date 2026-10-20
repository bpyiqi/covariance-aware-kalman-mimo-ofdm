function out = auditOjcdLmmseEpAdapted(y, Hinitial, xhat, symbolVariance, covariance, noiseVar, options)
%AUDITOJCDLMMSEEPADAPTED OJCD-LMMSE JCD-2, Algorithm 2 and (20)-(43).
% Dimensions are y=D-by-NR, Hinitial=D-by-NR-by-NT, xhat/V=D-by-NT.
% This is the causal 2x2 adaptation; it processes one OFDM symbol only.

arguments
    y (:,:) double
    Hinitial (:,:,:) double
    xhat (:,:) double
    symbolVariance (:,:) double
    covariance struct
    noiseVar (1,1) double {mustBeNonnegative}
    options.symbolMagnitudeFloor (1,1) double = 1e-4
    options.rcondFloor (1,1) double = 1e-12
    options.diagonalLoadingFloor (1,1) double = 1e-12
    options.auditConditionNumbers (1,1) logical = true
end

[D,nr] = size(y); nt = size(xhat,2);
assert(isequal(size(Hinitial),[D nr nt]) && isequal(size(symbolVariance),[D nt]));
assert(nt==2,'The audited adaptation is explicitly 2x2.');
W1 = covariance.Wtraditional;

% Initial-estimation error covariance implied by (36) and Appendix B.
E = cell(nt,nt); Ccross = cell(nt,nt); VC = cell(1,nt);
for a=1:nt
    VC{a}=W1{a}*W1{a}';
    for b=1:nt
        Ccross{a,b}=covariance.Rhdhd{a,b}-covariance.Rhdhp{a,b}*W1{b}';
        E{a,b}=covariance.Rhdhd{a,b}-covariance.Rhdhp{a,b}*W1{b}' ...
            -W1{a}*covariance.Rhdhp{b,a}' + W1{a}*covariance.Rhphp{a,b}*W1{b}';
    end
end

Hnew = complex(zeros(D,nr,nt)); weights=cell(1,nt); B=cell(1,nt); SigmaZ=cell(1,nt);
regularizationCount=0; conditionNumbers=nan(1,nt); reciprocalConditionNumbers=nan(1,nt);
minEigenvalues=nan(1,nt);minimumCholeskyPivots=nan(1,nt);regularizationTriggered=false(1,nt);
regularizationLoadings=zeros(1,nt);solverFailure=false(1,nt);nonFiniteMatrix=false(1,nt);
nonFiniteSolution=false(1,nt);weakSymbolCount=0;
for target=1:nt
    other=setdiff(1:nt,target);
    q=conj(xhat(:,target))./(abs(xhat(:,target)).^2+options.symbolMagnitudeFloor^2);
    weakSymbolCount=weakSymbolCount+nnz(abs(xhat(:,target))<options.symbolMagnitudeFloor);
    Dinv=diag(q);

    % Equation (41), B_n.
    Bn=zeros(D);
    for j=other
        Bn=Bn+Ccross{target,j}*diag(conj(xhat(:,j)).*conj(q));
    end
    B{target}=Bn;

    % Equations (42)-(43), formed directly from the Appendix-B moments.
    Sz=noiseVar*eye(D);
    for a=other
        for b=other
            Vxab=xhat(:,a)*xhat(:,b)';
            Sz=Sz+E{a,b}.*Vxab;
        end
        Sz=Sz+noiseVar*VC{a}.*(xhat(:,a)*xhat(:,a)');
    end
    totalV=sum(max(real(symbolVariance),0),2);
    Sz=Sz+covariance.Rhdhd{target,target}.*diag(totalV);
    Sz=(Sz+Sz')/2;
    SigmaZ{target}=Sz;

    % Equations (38)-(39) and Algorithm 2 weight computation.
    Rcross=covariance.Rhdhd{target,target}+Bn;
    Rls=covariance.Rhdhd{target,target}+Bn+Bn'+Dinv*Sz*Dinv';
    Rls=(Rls+Rls')/2;
    nonFiniteBeforeLoading=any(~isfinite(Rls(:)));preRcond=NaN;preMinimumEigenvalue=NaN;
    if ~nonFiniteBeforeLoading
        preRcond=rcond(Rls);preMinimumEigenvalue=min(real(eig((Rls+Rls')/2)));
    end
    if nonFiniteBeforeLoading || preRcond<options.rcondFloor || preMinimumEigenvalue<=0
        loading=max(options.diagonalLoadingFloor, ...
            options.rcondFloor*max(real(trace(Rls))/D,1));
        if ~isfinite(loading),loading=options.diagonalLoadingFloor;end
        Rls=Rls+loading*eye(D); regularizationCount=regularizationCount+1;
        regularizationTriggered(target)=true;regularizationLoadings(target)=loading;
    end
    nonFiniteMatrix(target)=any(~isfinite(Rls(:)));
    if ~nonFiniteMatrix(target)
        reciprocalConditionNumbers(target)=rcond(Rls);
        minEigenvalues(target)=min(real(eig((Rls+Rls')/2)));
        [cholFactor,cholStatus]=chol((Rls+Rls')/2,'lower');
        if cholStatus==0,minimumCholeskyPivots(target)=min(real(diag(cholFactor)));end
        if options.auditConditionNumbers,conditionNumbers(target)=cond(Rls);else,conditionNumbers(target)=1/max(reciprocalConditionNumbers(target),realmin);end
    end
    try
        weights{target}=Rcross/Rls;
    catch
        weights{target}=complex(nan(D));solverFailure(target)=true;
    end
    nonFiniteSolution(target)=any(~isfinite(weights{target}(:)));

    for rx=1:nr
        % Equations (20) and (24), regularized element-wise division.
        separated=y(:,rx);
        for j=other
            separated=separated-xhat(:,j).*Hinitial(:,rx,j);
        end
        hLs=q.*separated;
        Hnew(:,rx,target)=weights{target}*hLs;
    end
end
values=[Hnew(:);conditionNumbers(:)];
out=struct('Hdata',Hnew,'weights',{weights},'B',{B},'SigmaZ',{SigmaZ}, ...
    'regularizationCount',regularizationCount,'conditionNumbers',conditionNumbers, ...
    'meanWeightNorm',mean(cellfun(@(w)norm(w,'fro'),weights)), ...
    'reciprocalConditionNumbers',reciprocalConditionNumbers, ...
    'minEigenvalueHermitianPart',minEigenvalues, ...
    'minimumCholeskyPivot',minimumCholeskyPivots, ...
    'regularizationTriggered',regularizationTriggered, ...
    'regularizationLoading',regularizationLoadings, ...
    'solverFailure',solverFailure,'nonFiniteMatrix',nonFiniteMatrix, ...
    'nonFiniteSolution',nonFiniteSolution, ...
    'weakSymbolCount',weakSymbolCount,'futureSymbolReadCount',0, ...
    'noncausalInterpolationUseCount',0,'testTruthOnlineUseCount',0, ...
    'ojcdTrueQamOnlineUseCount',0,'ojcdHtrueOnlineUseCount',0, ...
    'ojcdTrueBitsOnlineUseCount',0,'ojcdTestCovarianceUseCount',0, ...
    'hasNaN',any(isnan(values)),'hasInf',any(isinf(values)));
end
