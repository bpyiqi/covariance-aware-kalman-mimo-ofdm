function result = auditMechanismFixedR3Update(hPilot,PPilot,zDa,Rlegacy,Rls,Rfull,variant,cfg)
%AUDITMECHANISMFIXEDR3UPDATE A-G fixed-radius-3 covariance mechanism.
hPilot=hPilot(:);zDa=zDa(:);result=struct('accepted',true,'hardRejected',false, ...
    'nis',NaN,'normalizedNis',NaN,'nisInflationFactor',1,'decisionInflationFactor',NaN, ...
    'Rda',[],'hFinal',hPilot,'PFinal',PPilot,'updateCount',0);
switch string(variant)
    case "A",base=Rlegacy;useHard=false;useInflation=false;
    case "B",base=Rlegacy;useHard=true;useInflation=false;
    case "C",base=Rlegacy;useHard=true;useInflation=true;
    case "D",base=Rls;useHard=false;useInflation=false;
    case "E",base=Rls;useHard=true;useInflation=false;
    case "F",base=Rls;useHard=true;useInflation=true;
    case "G",result.Rda=Rfull;result=localApply(result,hPilot,PPilot,zDa,Rfull,false,cfg);return;
    otherwise,error('Unknown mechanism variant %s.',variant);
end
if variant=="A"||variant=="D",result.Rda=base;result=localApply(result,hPilot,PPilot,zDa,base,false,cfg);result.nisInflationFactor=NaN;return;end
innovation=zDa-hPilot;S=(PPilot+base+PPilot'+base')/2;nis=real(innovation'*(S\innovation));result.nis=nis;result.normalizedNis=nis/cfg.stateDimension;
if useHard&&nis>cfg.chiSquareHardThresholdDof8P999,result.accepted=false;result.hardRejected=true;return;end
alpha=1;if useInflation,alpha=max(1,nis/cfg.stateDimension);end;result.nisInflationFactor=alpha;result.Rda=alpha*base;result=localApply(result,hPilot,PPilot,zDa,result.Rda,true,cfg);
end

function result=localApply(result,hPilot,PPilot,zDa,Rda,keepNis,cfg)
selection=struct('accepted',true,'candidate',struct('Rda',Rda,'zDa',zDa));[h,P,audit]=auditQualityAwareDaKalmanUpdate(hPilot,PPilot,selection,Rda,cfg);result.hFinal=h;result.PFinal=P;result.updateCount=audit.daUpdateCount;result.Rda=Rda;if ~keepNis,result.nis=NaN;result.normalizedNis=NaN;end
end
