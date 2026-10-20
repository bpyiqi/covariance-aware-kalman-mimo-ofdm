function B=auditBootstrapDecoderTemperature(lossGrid,betaGrid,seed,count)
%AUDITBOOTSTRAPDECODERTEMPERATURE Scenario-level bootstrap over cached full-scenario losses.
scenarioLoss=squeeze(mean(lossGrid,2));S=size(scenarioLoss,1);state=rng;cleanup=onCleanup(@()rng(state));rng(seed,'twister');
beta=zeros(count,1);lossReduction=zeros(count,1);boundary=false(count,1);
for q=1:count
    indices=randi(S,S,1);curve=mean(scenarioLoss(indices,:),1);[minimum,index]=min(curve); %#ok<ASGLU>
    beta(q)=localQuadratic(betaGrid,curve,index);boundary(q)=index==1||index==numel(betaGrid);
    raw=interp1(betaGrid,curve,1,'linear');star=interp1(betaGrid,curve,beta(q),'linear');
    lossReduction(q)=(raw-star)/raw;
end
B=table((1:count).',beta,lossReduction,boundary,'VariableNames',{'bootstrapIndex','beta','relativeLossReduction','boundaryHit'});
end
function beta=localQuadratic(grid,loss,index)
if index==1||index==numel(grid),beta=grid(index);return;end
x=grid(index-1:index+1);y=loss(index-1:index+1);p=polyfit(x,y,2);
if p(1)<=0,beta=grid(index);else,beta=min(max(-p(2)/(2*p(1)),x(1)),x(3));end
end

