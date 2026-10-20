function result=auditRawClipSelftest(root)
%AUDITRAWCLIPSELFTEST Offline-only raw clipping invariants and source integrity.
cfg=auditRawClipConfig(root);frozen=localFrozenDirectories(root,cfg);before=cellfun(@auditDirectoryShaManifest,frozen,'UniformOutput',false);
preflight=auditRawClipPreflight(cfg);source=load(preflight.checkpointPath,'cfg');cfg.decoder=source.cfg.ldpc;checks=struct();
loaded=load(preflight.chunkPaths(1),'chunk');chunk=loaded.chunk;rec=chunk.records{1};raw=double(rec.rawUsefulLlr(:));truth=logical(chunk.codedBits(:));
infValue=auditRawClipTransform(raw,Inf,"hard");checks.infTransformExact=isequaln(infValue,raw);
decodedPass=false(3,1);for cw=1:3,index=(cw-1)*cfg.decoder.N+(1:cfg.decoder.N);decoded=logical(ldpcDecode(infValue(index),cfg.decoder.dec,cfg.decoderIterations,'DecisionType','hard'));payload=decoded(1:cfg.decoder.K-32);decodedPass(cw)=isequal(decoded(cfg.decoder.K-31:cfg.decoder.K),ofdm.crc32Bits(payload));end
checks.infDecoderExact=isequal(decodedPass,logical(rec.baselineCodewordPass(:)));
levels=cfg.clipGrid(isfinite(cfg.clipGrid));hardExact=true;preExact=true;signExact=true;errors=zeros(numel(levels),1);
for i=1:numel(levels),value=auditRawClipTransform(raw,levels(i),"hard");hardExact=hardExact&&isequal(value<0,raw<0);preExact=preExact&&nnz((value<0)~=truth)==nnz((raw<0)~=truth);signExact=signExact&&all(sign(value)==sign(raw));errors(i)=max(abs(value-raw));end
checks.hardBitsUnchanged=hardExact;checks.preBerUnchanged=preExact;checks.signMappingCorrect=signExact;
checks.largerCApproachesRaw=all(diff(errors)<=0);
ideal=auditLdpcIdealLlrSelftest(root);noiseless=auditNoiselessPerfectCsiLdpcChainSelftest(root);checks.idealLlrPass=ideal.positiveLlrMeansZero;checks.noiselessPerfectPass=noiseless.codewordPassRate==1;
checks.fixedSplit=isequal(cfg.calibrationScenarios,1:8)&&isequal(cfg.holdoutScenarios,9:12);
checks.holdoutCannotSelect=nargin('auditRawClipCalibrationSummary')==2&&nargin('auditRawClipHoldoutSummary')==3;
checks.methodToleranceWorks=max([0 .0101])>cfg.methodNllTolerance&&max([0 .0099])<=cfg.methodNllTolerance;
synthetic=localSyntheticDetail(cfg,1:8);small=cfg;small.bootstrapCount=20;small.clipGrid=[5 Inf];B=auditRawClipBootstrap(synthetic,small);
checks.bootstrapUsesScenarioUnits=height(B)==20&&all(B.feasibleCandidateCount>=1);
checks.boundaryHandling=all(B.boundaryHit==(B.selectedC==cfg.clipGrid(1)))&&all(B.selectedInf==isinf(B.selectedC));
[grid,methods,snr,selection]=auditRawClipCalibrationSummary(synthetic,small);
checks.calibrationSelectionUsesOnlyCalibration=selection.selectedC==5&&~selection.selectionUsedHoldout&&height(methods)==10;
combinedSummary=[grid;methods;snr];
checks.summarySchemasConcatenate=height(combinedSummary)==height(grid)+height(methods)+height(snr);
holdoutSynthetic=localSyntheticDetail(cfg,9:12);[holdout,transitions,gates]=auditRawClipHoldoutSummary(holdoutSynthetic,small,5);
checks.holdoutEvaluationCannotReselect=~gates.selectionUsedHoldout&&any(holdout.mode=="raw")&&any(holdout.mode=="clipped")&&height(transitions)>0;
temporary=[tempname '_raw_clip_refusal'];mkdir(temporary);fclose(fopen(fullfile(temporary,'sentinel'),'w'));cleanup=onCleanup(@()rmdir(temporary,'s'));checks.overwriteRefusal=false;
try
    auditRefuseNonemptyOutput(temporary);
catch ME
    checks.overwriteRefusal=contains(ME.message,'Refusing to overwrite');
end
checks.covarianceAliasExact=localAlias(cfg);after=cellfun(@auditDirectoryShaManifest,frozen,'UniformOutput',false);
checks.frozenDirectoriesUnchanged=all(cellfun(@isequal,before,after));checks.sourceChunksUnchanged=isequal(before{end},after{end});
values=struct2array(checks);assert(all(values),'Raw clipping selftest failed.');
result=struct('passed',true,'checks',checks,'infDecoderPassDifference',nnz(decodedPass~=logical(rec.baselineCodewordPass(:))), ...
    'hardBitDifference',nnz((auditRawClipTransform(raw,10,"hard")<0)~=(raw<0)), ...
    'preBitErrorDifference',nnz((auditRawClipTransform(raw,10,"hard")<0)~=truth)-nnz((raw<0)~=truth), ...
    'covarianceAliasMaximumError',0,'receiverRuns',0,'newPhysicalSeedsConsumed',0);
fprintf('raw-clipping selftest PASS: %d/%d checks; C=Inf decoder difference=0; hard-bit difference=0; pre-error difference=0; receiverRuns=0; physicalSeeds=0.\n',nnz(values),numel(values));
end
function detail=localSyntheticDetail(cfg,scenarios)
rows=cell(numel(scenarios)*numel(cfg.methods)*2,1);cursor=0;
for s=scenarios
    for method=cfg.methods
        for C=[5 Inf]
            cursor=cursor+1;loss=100;if C==5,loss=90;end
            rows{cursor}=table(s,20,method,1,C,"hard",loss,1000,0,0,true,true,0,0,0,0,0,true,false,false,false, ...
                'VariableNames',{'scenarioIndex','targetSnrDb','method','codewordIndex','clipLevel','transform','nllSum', ...
                'bitCount','preBitErrorsRawRecord','preBitErrorsRecord','hardBitsUnchanged','decoderPass','postBitErrors', ...
                'wrongBitMeanAbsLlr','wrongBitMaxAbsLlr','wrongHighConfidenceCount10','decoderRuntimeSec','rawDecoderPass', ...
                'passToFail','failToPass','unusedAuditFlag'});
        end
    end
end
detail=vertcat(rows{:});detail.unusedAuditFlag=[];
end
function pass=localAlias(cfg)
% Use the source receiver configuration dimensions without changing either branch.
source=auditCovarianceAwareSnrPairedLocalization20Config(cfg.root);pilot=complex(zeros(source.NFFT,1,2,2,'single'));for k=1:source.NFFT,pilot(k,1,:,:)=single(eye(2));end
bits=zeros(2*numel(source.data),4);for q=1:size(bits,1),bits(q,:)=bitget(mod(q-1,16),4:-1:1);end
x=reshape(ofdm.qam16ModBits(bits),2,[]);received=complex(zeros(numel(source.data),1,2,'single'));for d=1:numel(source.data),received(d,1,:)=single(x(:,d));end
online=struct('pilotObservation',pilot,'receivedData',received,'validDataMask',true(numel(source.data),1),'noiseVar',source.noiseVar,'rho',source.rho);
a=auditMechanismRunSingleEstimator(source,online,"FixedRadius3LsCovOnlyCausal_EP");b=auditMechanismRunSingleEstimator(source,online,"CovarianceAwareLocalDAKalmanCausal_EP");
pass=isequaln(a.Hhat,b.Hhat)&&isequaln(a.finalState,b.finalState)&&isequaln(a.finalCovariance,b.finalCovariance);
end
function directories=localFrozenDirectories(root,cfg)
names={"covariance_aware_final_validation50_seed20260721","covariance_aware_snr_localization10_seed20260724", ...
"covariance_aware_snr_paired_localization20_seed20260725","covariance_aware_llr_ldpc_existing_results_audit_v1", ...
"covariance_aware_llr_ldpc_replay_smoke_v1"};directories=cellfun(@(n)fullfile(root,'results_three_layer_validation',n),cellstr(names),'UniformOutput',false);directories{end+1}=cfg.sourceDirectory;
end
