function result=auditUncertaintyBypassCaptureSelftest(~)
% Static, deterministic gate: no receiver invocation or physical randomness.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
files={fullfile(root,'audit_three_layer_helpers','quality_aware_proposed','auditMechanismRunSingleEstimator.m'), ...
    fullfile(root,'audit_three_layer_helpers','quality_aware_proposed','auditMechanismOnlineReceive.m'), ...
    fullfile(root,'audit_three_layer_helpers','quality_aware_proposed','auditCovarianceAwareOjcdReceive.m'), ...
    fullfile(root,'audit_three_layer_helpers','ojcd_baseline','auditOjcdTwoLayerSymbol.m')};
checks=false(28,1); checks(1)=all(cellfun(@isfile,files));
text=string(cellfun(@fileread,files,'UniformOutput',false));
checks(2)=contains(text(1),'options.bypassCapture')&&contains(text(2),'options.bypassCapture');
checks(3)=contains(text(1),'HhatPilotFrozen')&&contains(text(1),'PrealPilotFrozen');
checks(4)=contains(text(2),'posteriorMean')&&contains(text(2),'posteriorVariance')&&contains(text(2),'bitLlr');
checks(5)=contains(text(1),'candidateMask')&&contains(text(1),'selectedCandidateMask')&&contains(text(1),'reliabilityMask');
checks(6)=contains(text(2),'rawUsefulLlrHash')&&contains(text(2),'randomStateHash');
checks(7)=isempty(regexp(strjoin(text),'\<inv\s*\(','once'));
issues=[]; if exist('checkcode','file')==2, for i=1:numel(files), issues=[issues;checkcode(files{i},'-id')]; end, end %#ok<AGROW>
checks(8)=isempty(issues);
orchestratorText=string(fileread(fullfile(root,'audit_three_layer_helpers','uncertainty_consistent','auditUncertaintyBypassCapture.m')));
evaluatorText=string(fileread(fullfile(root,'audit_three_layer_helpers','uncertainty_consistent','localEvaluateBypassSemantic.m')));
checks(9)=contains(orchestratorText,'localMakeGateTable(method,gateColumn,passedColumn)')&&contains(evaluatorText,'localMakeGateTable(method,names');
checks(10)=contains(orchestratorText,'localEvaluateBypassSemantic(method,run)')&&contains(evaluatorText,'localSnapshot')&&contains(evaluatorText,'localMoments')&&contains(evaluatorText,'localAlignment')&&contains(evaluatorText,'localPadding');
checks(11)=contains(orchestratorText,'executionLedger')||contains(orchestratorText,'localEmptyLedger');
[checks(12:17),pureTable]=localGateTableTests(); %#ok<ASGLU>
[checks(18:26),ledgerFixture]=localLedgerTests(); %#ok<ASGLU>
[checks(27),checks(28)]=localSemanticFixtureTests();
names=["formal path exists";"default-off switches";"pilot snapshot fields";"EP posterior fields";"DA context fields";"consistency hashes";"no inverse calls";"checkcode";"unified gate calls";"semantic named checks";"execution ledger";"row vector normalization";"column vector normalization";"count mismatch gate";"char/string method";"logical passed type";"gate order alignment";"empty ledger";"string ID deduplication";"missing/empty ID filtering";"off/on completed counts";"attempted incomplete count";"synthetic versus actual";"untracked seed NaN";"missing optional fields safe";"primary error preserved";"DA cell semantic fixture";"Base semantic fixture"];
result=localMakeGateTable("selftest",names,checks); disp(result); assert(all(result.passed),'Bypass capture selftest failed.'); fprintf('receiverRuns=0\nphysicalSeeds=0\n');
end

function [daPassed,basePassed]=localSemanticFixtureTests()
D=3;N=2;c=struct();fields={'HhatPilotFrozen','PrealPilotFrozen','stream','subcarrier','symbol','paddingMask','validDataMask','reliabilityMask','candidateMask','selectedCandidateMask'};
for i=1:numel(fields),c.(fields{i})=cell(D,N);end
c.captureSymbolIndex=zeros(D,N);c.captureSubcarrierIndex=zeros(D,N);
for n=1:N
    for d=1:D
        c.HhatPilotFrozen{d,n}=reshape(complex(ones(2)),1,1,2,2);c.PrealPilotFrozen{d,n}=eye(8);c.captureSymbolIndex(d,n)=n;c.captureSubcarrierIndex(d,n)=10+d;
        c.stream{d,n}=1:2;c.subcarrier{d,n}=10+d;c.symbol{d,n}=n;c.paddingMask{d,n}=false(D,1);c.validDataMask{d,n}=true(D,1);c.reliabilityMask{d,n}=true(D,1);c.candidateMask{d,n}=true;c.selectedCandidateMask{d,n}=true;
    end
end
p=struct('softMean',complex(ones(2,D,N)),'softVariance',ones(2,D,N),'posteriorMean',complex(ones(2,D,N)),'posteriorVariance',ones(2,D,N));
run=struct('estCapture',c,'receiver',struct('bypassCapture',p),'validDataMask',true(D,N),'audit',struct('daUpdateCount',1));
da=localEvaluateBypassSemantic("FixedRadius3Causal_EP",run);daPassed=all(da.passed);
run.audit.daUpdateCount=0;base=localEvaluateBypassSemantic("BaseKalmanCausal_EP",run);basePassed=all(base.passed);
end

function [checks,T]=localLedgerTests()
T=table(strings(0,1),strings(0,1),false(0,1),false(0,1),strings(0,1),strings(0,1),strings(0,1),false(0,1),false(0,1), ...
    'VariableNames',{'captureMode','physicalInputId','attempted','completed','physicalSeedId','resultSource','isActualReceiverRun','newPhysicalSeedGenerated','isSynthetic'});
s=localSummarizeExecutionLedger(T); checks=false(9,1); checks(1)=s.actualReceiverRuns==0&&s.uniquePhysicalInputsActuallyUsed==0;
ids=strings(5,1);ids(1)="shared";ids(2)=missing;ids(3)="";ids(4)="shared";ids(5)="other";
T=table(["off";"on";"off";"on";"on"],ids,[true;true;true;true;true],[true;false;true;true;false], ...
    ["s1";"s1";"s1";"s2";""],["actual";"actual";"actual";"actual";"synthetic"],[true;true;true;true;false],[true;false;false;false;false],[false;false;false;false;true], ...
    'VariableNames',{'captureMode','physicalInputId','attempted','completed','physicalSeedId','resultSource','isActualReceiverRun','newPhysicalSeedGenerated','isSynthetic'});
s=localSummarizeExecutionLedger(T); checks(2)=s.uniquePhysicalInputsActuallyUsed==2; checks(3)=s.uniquePhysicalInputsActuallyUsed==2; checks(4)=s.captureOffRunsCompleted==2&&s.captureOnRunsCompleted==1; checks(5)=s.attemptedActualReceiverRuns==4&&s.completedActualReceiverRuns==3; checks(6)=s.syntheticRuns==1&&s.actualReceiverRuns==3; checks(7)=s.newPhysicalSeedsActuallyGenerated==1;
T2=removevars(T,'newPhysicalSeedGenerated'); s2=localSummarizeExecutionLedger(T2); checks(8)=isnan(s2.newPhysicalSeedsActuallyGenerated);
checks(9)=s2.uniquePhysicalInputsActuallyUsed==2;
try
    primary=MException('Mini:Primary','primary failure');
    try
        throw(primary);
    catch primaryError
        try
            localSummarizeExecutionLedger(T2);
        catch
        end
        rethrow(primaryError);
    end
catch ME
    checks(9)=checks(9)&&strcmp(ME.identifier,'Mini:Primary');
end
end

function [checks,Trow]=localGateTableTests()
names=["a";"b";"c";"d";"e";"f";"g";"h";"i";"j";"k"];
rowChecks=true(1,11); columnChecks=true(11,1);
Trow=localMakeGateTable('Base',names,rowChecks);
checks=false(6,1);
checks(1)=height(Trow)==11;
checks(2)=height(localMakeGateTable("Base",names,columnChecks))==11;
try
    localMakeGateTable("Base",names,true(1,10));
catch ME
    checks(3)=strcmp(ME.identifier,'GateCheckCountMismatch')||contains(ME.message,'GateCheckCountMismatch');
end
checks(4)=all(string(localMakeGateTable('Base',names,columnChecks).method)=="Base")&&all(string(localMakeGateTable("Base",names,columnChecks).method)=="Base");
checks(5)=islogical(localMakeGateTable("Base",names,columnChecks).passed);
checks(6)=isequal(string(localMakeGateTable("Base",names,(1:11)==(1:11)).gate),names);
end
