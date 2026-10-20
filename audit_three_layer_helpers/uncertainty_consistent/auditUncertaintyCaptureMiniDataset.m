function result=auditUncertaintyCaptureMiniDataset(root,mode)
cfg=localConfig(root);
switch string(mode)
    case "dryrun"
        preflight=localPreflight(cfg);
        result=struct('mode',"dryrun",'receiverRuns',0,'newPhysicalSeeds',0,'preflight',preflight);
        fprintf('uncertainty capture mini dataset v1 dry-run\nreceiverRuns=0\nplannedReceiverRuns=18\nuniquePhysicalInputsPlanned=2\nnewPhysicalSeeds=0\nsourceReady=%d\n',preflight.ready);
    case "selftest"
        result=localSelftest(cfg);
    case "run"
        result=localRun(cfg);
    otherwise
        error('Unknown uncertainty capture mini dataset mode: %s',mode);
end
end

function cfg=localConfig(root)
cfg=struct();
cfg.root=root;
cfg.source=fullfile(root,'results_three_layer_validation','causal_refactor_smoke','mini_smoke','causal_mini_results.mat');
cfg.output=fullfile(root,'results_three_layer_validation','uncertainty_propagation_capture_mini_dataset_v1');
cfg.sceneCells=[1 3];
cfg.snrDb=[18 24 30];
cfg.methods=["BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP"];
cfg.plannedRuns=18;
end

function result=localPreflight(cfg)
assert(isfile(cfg.source),'Saved development packet source is missing.');
w=whos('-file',cfg.source);names=string({w.name});
ready=all(ismember(["results","c"],names));
assert(ready,'Saved development packet source lacks results or configuration.');
assert(exist(cfg.output,'dir')~=7,'Refusing to overwrite existing dataset directory.');
result=struct('ready',ready,'source',string(cfg.source),'sceneCells',cfg.sceneCells,'newPhysicalSeeds',0);
end

function result=localSelftest(cfg)
preflight=localPreflight(cfg);
names=["source preflight";"frozen run count";"frozen methods";"frozen SNR grid";"no random generation";"core contraction";"effective noise finite";"PSD diagnostics";"output overwrite gate";"checkcode"];
checks=false(numel(names),1);
checks(1)=preflight.ready;
checks(2)=numel(cfg.sceneCells)*numel(cfg.snrDb)*numel(cfg.methods)==18;
checks(3)=isequal(cfg.methods,["BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP"]);
checks(4)=isequal(cfg.snrDb,[18 24 30]);
sourcePath=[mfilename('fullpath') '.m'];sourceText=string(fileread(sourcePath));
randomCalls=["ran"+"di(","ran"+"dn(","rn"+"g("];checks(5)=~any(contains(sourceText,randomCalls));
P=diag(1:8)/100;[Ph,~,d]=ucRealStateCovToComplex(P);mx=[.2+.1i;-.3+.2i];V=diag([.1 .2]);Rn=.01*eye(2);
[Reff,Rcsi,e]=ucChannelUncertaintyEffectiveNoise(Rn,Ph,mx,V,2,2);
checks(6)=isequal(size(Rcsi),[2 2])&&d.propernessRatio>=0;
checks(7)=all(isfinite(Reff(:)))&&isfinite(e.csiToNoiseRatio);
checks(8)=min(real(eig(Rcsi)))>=-1e-12&&min(real(eig(Reff)))>0;
checks(9)=exist(cfg.output,'dir')~=7;
issues=checkcode(sourcePath,'-id');checks(10)=isempty(issues);
result=localMakeGateTable("dataset_selftest",names,checks);
disp(result);assert(all(result.passed),'Uncertainty capture mini dataset selftest failed.');
fprintf('receiverRuns=0\nnewPhysicalSeeds=0\n');
end

function result=localRun(plan)
localPreflight(plan);
loaded=load(plan.source,'results','c');
assert(numel(loaded.results)>=max(plan.sceneCells),'Saved source has fewer scenes than required.');
baseCfg=auditQualityAwareDefaultConfig(plan.root);
baseCfg.rho=loaded.c.rho;
runCells=cell(plan.plannedRuns,1);rowCells=cell(plan.plannedRuns,1);derivedCells=cell(plan.plannedRuns,1);
cursor=0;actualReceiverRuns=0;
for scene=1:numel(plan.sceneCells)
    packet0=loaded.results{plan.sceneCells(scene)}.packet;
    localValidatePacket(packet0);
    unitNoise=double(packet0.noise)/sqrt(loaded.c.noiseVar);
    noiseless=double(packet0.y)-double(packet0.noise);
    for snrDb=plan.snrDb
        point=baseCfg;point.noiseVar=10^(-snrDb/10);
        packet=packet0;packet.noise=single(sqrt(point.noiseVar)*unitNoise);packet.y=single(noiseless+double(packet.noise));
        for method=plan.methods
            cursor=cursor+1;
            [run,captureRows,derived]=localCapture(point,packet,method,scene,snrDb,plan.sceneCells(scene));
            actualReceiverRuns=actualReceiverRuns+1;runCells{cursor}=run;rowCells{cursor}=captureRows;derivedCells{cursor}=derived;
        end
    end
end
assert(actualReceiverRuns==plan.plannedRuns,'Receiver run count mismatch.');
reLevel=vertcat(rowCells{:});assert(all(reLevel.finitePassed)&&all(reLevel.psdPassed),'Read-only covariance diagnostics failed.');
conditionSummary=localConditionSummary(reLevel);
daSummary=localDaSummary(reLevel);
propernessSummary=localPropernessSummary(reLevel);
localSpotCheck(runCells,derivedCells);
assert(exist(plan.output,'dir')~=7,'Refusing to overwrite existing dataset directory.');
mkdir(plan.output);
writetable(reLevel,fullfile(plan.output,'uncertainty_capture_re_level.csv'));
writetable(conditionSummary,fullfile(plan.output,'uncertainty_capture_condition_summary.csv'));
writetable(daSummary,fullfile(plan.output,'uncertainty_capture_da_summary.csv'));
writetable(propernessSummary,fullfile(plan.output,'uncertainty_capture_properness_summary.csv'));
save(fullfile(plan.output,'uncertainty_capture_results.mat'),'plan','runCells','derivedCells','reLevel','conditionSummary','daSummary','propernessSummary','-v7.3');
localWriteReport(plan,actualReceiverRuns,reLevel);
localWriteManifest(plan);
fclose(fopen(fullfile(plan.output,'COMPLETE'),'w'));
result=struct('actualReceiverRuns',actualReceiverRuns,'uniquePhysicalInputs',2,'newPhysicalSeeds',0,'outputDirectory',plan.output);
end

function localValidatePacket(p)
required={'H','txbits','qam','obs','y','noise','validReMask','usefulBitMask','coded','Npayload','nCodeword'};
assert(all(isfield(p,required)),'Saved packet is missing required physical fields.');
assert(all(isfinite(double(p.H(:))))&&all(isfinite(double(p.y(:)))),'Saved packet contains nonfinite physical data.');
end

function [run,T,derived]=localCapture(cfg,packet,method,scene,snrDb,sourceCell)
online=struct('pilotObservation',packet.obs,'receivedData',packet.y,'validDataMask',packet.validReMask,'validReMask',packet.validReMask,'noiseVar',cfg.noiseVar,'rho',cfg.rho,'Npayload',packet.Npayload,'nCodeword',packet.nCodeword,'usefulBitMask',packet.usefulBitMask);
before=rng;estimate=auditMechanismRunSingleEstimator(cfg,online,method,struct('bypassCapture',true));receiver=auditMechanismOnlineReceive(cfg,online,estimate.Hhat,estimate.onlineEstimationRuntimeSeconds,bypassCapture=true);after=rng;
run=struct('method',method,'scene',scene,'snrDb',snrDb,'physicalInputId',sprintf('causal_mini_cell_%02d',sourceCell),'estimate',estimate,'receiver',receiver,'randomBefore',before,'randomAfter',after);
[T,derived]=localDerive(cfg,packet,run);
end

function [T,derived]=localDerive(cfg,packet,run)
c=run.estimate.bypassCapture;p=run.receiver.bypassCapture;D=numel(cfg.data);N=packet.Npayload;count=2*nnz(packet.validReMask);
scene=zeros(count,1);snr=zeros(count,1);method=strings(count,1);physicalInputId=strings(count,1);symbol=zeros(count,1);subcarrier=zeros(count,1);stream=zeros(count,1);paddingMask=false(count,1);validDataMask=false(count,1);reliabilityMask=false(count,1);candidateMask=false(count,1);selectedCandidateMask=false(count,1);softMean=complex(zeros(count,1));softVariance=zeros(count,1);posteriorMean=complex(zeros(count,1));posteriorVariance=zeros(count,1);propernessRatio=zeros(count,1);csiToNoiseRatio=zeros(count,1);decisionToNoiseRatio=zeros(count,1);interactionToNoiseRatio=zeros(count,1);finitePassed=false(count,1);psdPassed=false(count,1);
derived=cell(D,N);cursor=0;Rn=cfg.noiseVar*eye(2);
for n=1:N
    for d=find(packet.validReMask(:,n)).'
        Hbar=reshape(double(c.HhatPilotFrozen{d,n}),2,2);Preal=double(c.PrealPilotFrozen{d,n});[Ph,Ppseudo,pd]=ucRealStateCovToComplex(Preal);
        mx=double(p.softMean(:,d,n));v=max(double(p.softVariance(:,d,n)),0);Vx=diag(v);Sx=Vx+mx*mx';
        [Reff,Rcsi,ed]=ucChannelUncertaintyEffectiveNoise(Rn,Ph,mx,Vx,2,2);Cnoise=Rn;Cdecision=Hbar*Vx*Hbar';Cinteraction=ucChannelCovarianceContraction(Ph,Vx,2,2);CdaTotal=Cnoise+Cdecision+Cinteraction;
        finite=all(isfinite([Ph(:);Ppseudo(:);Sx(:);Rcsi(:);Cnoise(:);Cdecision(:);Cinteraction(:);CdaTotal(:);Reff(:)]));psd=min(real(eig((Rcsi+Rcsi')/2)))>=-1e-11&&min(real(eig((CdaTotal+CdaTotal')/2)))>=-1e-11;
        derived{d,n}=struct('Ph',Ph,'Ppseudo',Ppseudo,'Sx',Sx,'Rcsi',Rcsi,'Cnoise',Cnoise,'Cdecision',Cdecision,'Cinteraction',Cinteraction,'CdaTotal',CdaTotal);
        masks=localMasks(c,d,n,D,methodIsBase(run.method));
        for s=1:2
            cursor=cursor+1;scene(cursor)=run.scene;snr(cursor)=run.snrDb;method(cursor)=run.method;physicalInputId(cursor)=run.physicalInputId;symbol(cursor)=n;subcarrier(cursor)=cfg.data(d);stream(cursor)=s;paddingMask(cursor)=masks.padding;validDataMask(cursor)=masks.valid;reliabilityMask(cursor)=masks.reliable;candidateMask(cursor)=masks.candidate;selectedCandidateMask(cursor)=masks.selected;softMean(cursor)=p.softMean(s,d,n);softVariance(cursor)=p.softVariance(s,d,n);posteriorMean(cursor)=p.posteriorMean(s,d,n);posteriorVariance(cursor)=p.posteriorVariance(s,d,n);propernessRatio(cursor)=pd.propernessRatio;csiToNoiseRatio(cursor)=ed.csiToNoiseRatio;decisionToNoiseRatio(cursor)=real(trace(Cdecision))/max(real(trace(Cnoise)),eps);interactionToNoiseRatio(cursor)=real(trace(Cinteraction))/max(real(trace(Cnoise)),eps);finitePassed(cursor)=finite;psdPassed(cursor)=psd;
        end
    end
end
T=table(scene,snr,method,physicalInputId,symbol,subcarrier,stream,paddingMask,validDataMask,reliabilityMask,candidateMask,selectedCandidateMask,softMean,softVariance,posteriorMean,posteriorVariance,propernessRatio,csiToNoiseRatio,decisionToNoiseRatio,interactionToNoiseRatio,finitePassed,psdPassed);
end

function masks=localMasks(c,d,n,D,isBase)
masks=struct('padding',false,'valid',true,'reliable',false,'candidate',false,'selected',false);
if isBase,return;end
if isempty(c.validDataMask{d,n}),masks.valid=false;masks.padding=true;return;end
valid=logical(c.validDataMask{d,n});padding=logical(c.paddingMask{d,n});reliable=logical(c.reliabilityMask{d,n});
assert(numel(valid)==D&&numel(padding)==D&&numel(reliable)==D,'Captured mask length mismatch.');
masks.valid=valid(d);masks.padding=padding(d);masks.reliable=reliable(d);masks.candidate=logical(c.candidateMask{d,n});masks.selected=logical(c.selectedCandidateMask{d,n});
end
function yes=methodIsBase(method),yes=startsWith(string(method),"Base");end

function S=localConditionSummary(T)
keys=unique(T(:,{'method','scene','snr'}),'rows');cells=cell(height(keys),1);
for i=1:height(keys),x=T(T.method==keys.method(i)&T.scene==keys.scene(i)&T.snr==keys.snr(i),:);cells{i}=table(keys.method(i),keys.scene(i),keys.snr(i),height(x),localPct(x.propernessRatio,.50),localPct(x.propernessRatio,.90),localPct(x.propernessRatio,.95),localPct(x.propernessRatio,.99),max(x.propernessRatio),localPct(x.csiToNoiseRatio,.50),localPct(x.csiToNoiseRatio,.90),localPct(x.csiToNoiseRatio,.95),localPct(x.csiToNoiseRatio,.99),max(x.csiToNoiseRatio),mean(x.csiToNoiseRatio>.1),mean(x.csiToNoiseRatio>.5),mean(x.csiToNoiseRatio>1),localPct(x.decisionToNoiseRatio,.50),localPct(x.interactionToNoiseRatio,.50),all(x.finitePassed),all(x.psdPassed),'VariableNames',{'method','scene','snr','sampleCount','properMedian','properP90','properP95','properP99','properMax','csiMedian','csiP90','csiP95','csiP99','csiMax','csiAbove01','csiAbove05','csiAbove1','decisionMedian','interactionMedian','finitePassed','psdPassed'});end
S=vertcat(cells{:});
end
function S=localDaSummary(T)
keys=unique(T(:,{'method','scene','snr'}),'rows');cells=cell(height(keys),1);
for i=1:height(keys),x=T(T.method==keys.method(i)&T.scene==keys.scene(i)&T.snr==keys.snr(i),:);a=x.softVariance(x.selectedCandidateMask);b=x.softVariance(~x.selectedCandidateMask);cells{i}=table(keys.method(i),keys.scene(i),keys.snr(i),numel(a),localPct(a,.50),localPct(a,.95),numel(b),localPct(b,.50),localPct(b,.95),'VariableNames',{'method','scene','snr','selectedCount','selectedVarianceMedian','selectedVarianceP95','nonselectedCount','nonselectedVarianceMedian','nonselectedVarianceP95'});end
S=vertcat(cells{:});
end
function S=localPropernessSummary(T),S=localConditionSummary(T);S=S(:,{'method','scene','snr','sampleCount','properMedian','properP90','properP95','properP99','properMax'});end
function v=localPct(x,p),x=sort(x(isfinite(x)));if isempty(x),v=NaN;else,index=1+(numel(x)-1)*p;lo=floor(index);hi=ceil(index);v=x(lo)+(index-lo)*(x(hi)-x(lo));end,end

function localSpotCheck(runs,derived)
indices=[1 9 18];for i=indices,before=runs{i};llr=before.receiver.llr;berHash=sum(double(llr(:)).*(1:numel(llr))');audit=before.estimate.audit;touch=derived{i};assert(~isempty(touch)&&isequaln(llr,before.receiver.llr)&&berHash==sum(double(before.receiver.llr(:)).*(1:numel(llr))')&&isequaln(audit,before.estimate.audit),'Read-only derivation changed receiver output.');end
end
function localWriteReport(plan,runs,T)
f=fopen(fullfile(plan.output,'uncertainty_capture_report.txt'),'w');fprintf(f,'actualReceiverRuns=%d\nuniquePhysicalInputs=%d\nnewPhysicalSeeds=0\nreceiverAlgorithmChanged=0\nnewUncertaintyAlgorithmEnabled=0\nallFinite=%d\nallPsd=%d\n',runs,numel(unique(T.physicalInputId)),all(T.finitePassed),all(T.psdPassed));fclose(f);
end
function localWriteManifest(plan)
files={plan.source;fullfile(plan.root,'Compare_LongPayload_VideoLink_Kalman.m');fullfile(plan.root,'Exp_ProblemExistence_CSI_Aging.m');fullfile(plan.root,'Audit_ProblemExistence_CSI_Aging.m')};f=fopen(fullfile(plan.output,'uncertainty_capture_manifest.txt'),'w');for i=1:numel(files),[status,h]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',files{i}));assert(status==0);fprintf(f,'%s %s\n',files{i},strtrim(h));end;fclose(f);
end
