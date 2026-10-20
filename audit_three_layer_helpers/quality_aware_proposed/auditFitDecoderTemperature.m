function fit=auditFitDecoderTemperature(margins,bounds)
%AUDITFITDECODERTEMPERATURE Deterministic convex one-dimensional NLL fit.
margins=double(margins(:));assert(all(isfinite(margins))&&numel(margins)>0&&bounds(1)>0);
objective=@(b)mean(auditStableSoftplus(-b*margins));options=optimset('TolX',1e-8,'Display','off');
[beta,loss,exitflag,output]=fminbnd(objective,bounds(1),bounds(2),options);loss1=objective(1);
step=max(1e-5,1e-4*beta);left=objective(max(bounds(1),beta-step));right=objective(min(bounds(2),beta+step));
derivative=(right-left)/(min(bounds(2),beta+step)-max(bounds(1),beta-step));
tol=1e-6*(bounds(2)-bounds(1));boundary=beta-bounds(1)<=tol||bounds(2)-beta<=tol;
fit=struct('betaStar',beta,'lossAtOne',loss1,'lossAtBetaStar',loss,'relativeLossReduction',(loss1-loss)/loss1, ...
    'exitflag',exitflag,'iterations',output.iterations,'boundaryHit',boundary,'neighborLossLeft',left, ...
    'neighborLossRight',right,'derivativeAudit',derivative,'sampleBitCount',numel(margins));
end

