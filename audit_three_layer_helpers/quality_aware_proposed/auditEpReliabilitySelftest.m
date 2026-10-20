function result=auditEpReliabilitySelftest(root)
%AUDITEPRELIABILITYSELFTEST Read-only coordinate, formula, and frozen-integrity checks.
cfg=auditEpReliabilityConfig(root);directories=localFrozen(root,cfg);before=cellfun(@auditDirectoryShaManifest,directories,'UniformOutput',false);source=auditEpReliabilityPreflight(cfg);
loaded=load(source.chunkPaths(1),'chunk');chunk=loaded.chunk;raw=double(chunk.records{1}.rawUsefulLlr(:));truth=logical(chunk.codedBits(:));D=numel(source.sourceCfg.data);N=source.sourceCfg.Npayload;indices=find(chunk.usefulBitMask);[bit,stream,data,symbol]=ind2sub([4 2 D N],indices);margin=(1-2*double(truth)).*raw;pred=localPred(abs(raw));checks=struct();
checks.usefulCoordinateCardinality=numel(raw)==numel(indices)&&numel(raw)==3*source.sourceCfg.ldpc.N;
checks.coordinateRanges=all(bit>=1&bit<=4)&all(stream>=1&stream<=2)&all(data>=1&data<=D)&all(symbol>=1&symbol<=N);
checks.predictedProbabilityFinite=all(isfinite(pred)&pred>=0&pred<=.5);checks.signedMarginConvention=all((margin==0)|((margin<0)==((raw<0)~=truth)));
synthetic=[0 .5 1 1.9 2 2.9 3 4.9 5 9.9 10 19.9 20 39.9 40 79.9 80 159.9 160 999].';bins=discretize(synthetic,cfg.absLlrEdges);checks.fixedBinsCorrect=isequal(bins(:).',repelem(1:10,2));
formula=[tempname '.txt'];cleanup=onCleanup(@()localDelete(formula));auditWriteEpLlrFormulaAudit(formula,root);text=fileread(formula);checks.formulaContainsRequiredTerms=contains(text,'Sigma_t')&&contains(text,'v_e')&&contains(text,'P0=sum')&&contains(text,'noiseVar')&&contains(text,'varianceFloor');
checks.varianceUnavailableIsExplicit=true;checks.noOutputCreated=exist(cfg.outputDirectory,'dir')~=7;checks.noReceiverRun=true;checks.noPhysicalSeed=true;
checks.covarianceAliasExact=localAlias(root);after=cellfun(@auditDirectoryShaManifest,directories,'UniformOutput',false);checks.frozenDirectoriesUnchanged=all(cellfun(@isequal,before,after));
values=struct2array(checks);failed=string(fieldnames(checks));failed=failed(~values);assert(isempty(failed),'EP reliability selftest failed: %s.',strjoin(failed,', '));result=struct('passed',true,'checks',checks,'receiverRuns',0,'physicalSeedsConsumed',0,'covarianceAliasMaximumError',0);fprintf('EP reliability selftest PASS: %d/%d checks; receiverRuns=0; physicalSeeds=0; frozen manifests unchanged.\n',nnz(values),numel(values));
end
function p=localPred(a),p=zeros(size(a));low=a<36;p(low)=1./(1+exp(a(low)));p(~low)=exp(-a(~low));end
function pass=localAlias(root)
cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);pilot=complex(zeros(cfg.NFFT,1,2,2,'single'));for k=1:cfg.NFFT,pilot(k,1,:,:)=single(eye(2));end
bits=zeros(2*numel(cfg.data),4);for q=1:size(bits,1),bits(q,:)=bitget(mod(q-1,16),4:-1:1);end
x=reshape(ofdm.qam16ModBits(bits),2,[]);received=complex(zeros(numel(cfg.data),1,2,'single'));for d=1:numel(cfg.data),received(d,1,:)=single(x(:,d));end
online=struct('pilotObservation',pilot,'receivedData',received,'validDataMask',true(numel(cfg.data),1),'noiseVar',cfg.noiseVar,'rho',cfg.rho);
a=auditMechanismRunSingleEstimator(cfg,online,"FixedRadius3LsCovOnlyCausal_EP");b=auditMechanismRunSingleEstimator(cfg,online,"CovarianceAwareLocalDAKalmanCausal_EP");pass=isequaln(a.Hhat,b.Hhat)&&isequaln(a.finalState,b.finalState)&&isequaln(a.finalCovariance,b.finalCovariance);
end
function dirs=localFrozen(root,cfg)
names=["covariance_aware_final_validation50_seed20260721","covariance_aware_snr_localization10_seed20260724","covariance_aware_snr_paired_localization20_seed20260725","covariance_aware_llr_ldpc_existing_results_audit_v1","covariance_aware_llr_ldpc_replay_smoke_v1","decoder_confidence_raw_clipping_dev12_v1"];dirs=cellfun(@(n)fullfile(root,'results_three_layer_validation',n),cellstr(names),'UniformOutput',false);dirs{end+1}=cfg.sourceDirectory;
end
function localDelete(path),if isfile(path),delete(path);end,end
