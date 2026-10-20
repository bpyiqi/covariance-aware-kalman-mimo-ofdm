function artifacts=auditDecoderConfidenceCalibrationFinalize(cfg,out,T,chunkPaths,chunkHashes)
%AUDITDECODERCONFIDENCECALIBRATIONFINALIZE Fit public beta and evaluate fixed holdout.
schema=auditDecoderConfidenceCalibrationSchema();assert(height(T)==420);calPaths=localPaths(chunkPaths,cfg.calibrationScenarios);holdPaths=localPaths(chunkPaths,cfg.holdoutScenarios);
allMargins=auditCollectDecoderConfidenceMargins(calPaths,cfg.methods);fit=auditFitDecoderTemperature(allMargins,cfg.betaBounds);clear allMargins;
betaFit=struct2table(fit,'AsArray',true);methodRows=cell(numel(cfg.methods),1);
for m=1:numel(cfg.methods),z=auditCollectDecoderConfidenceMargins(calPaths,cfg.methods(m));q=auditFitDecoderTemperature(z,cfg.betaBounds);methodRows{m}=table(cfg.methods(m),q.betaStar,q.lossAtOne,q.lossAtBetaStar,q.relativeLossReduction,q.boundaryHit,q.sampleBitCount,'VariableNames',{'method','diagnosticBeta','lossAtOne','lossAtBeta','relativeLossReduction','boundaryHit','sampleBitCount'});clear z;end
methodSpecific=vertcat(methodRows{:});[betaGrid,lossGrid,bitCounts]=auditDecoderConfidenceScenarioLossGrid(calPaths,cfg);
bootstrap=auditBootstrapDecoderTemperature(lossGrid,betaGrid,cfg.bootstrapSeed,cfg.bootstrapCount);
[holdout,transitions,clip]=auditEvaluateDecoderConfidenceHoldout(holdPaths,cfg,fit.betaStar);
ideal=auditLdpcIdealLlrSelftest(cfg.root);noiseless=auditNoiselessPerfectCsiLdpcChainSelftest(cfg.root);
allRow=holdout(holdout.method=="ALL",:);methodRows=holdout(holdout.method~="ALL",:);
hardUnchanged=allRow.preBitErrorsRaw==allRow.preBitErrorsCalibrated;noNllWorse=all(methodRows.pooledNllCalibrated<=1.01*methodRows.pooledNllRaw);
eligible=fit.lossAtBetaStar<fit.lossAtOne&&allRow.pooledNllCalibrated<allRow.pooledNllRaw&&hardUnchanged&& ...
    ideal.positiveLlrMeansZero&&noiseless.codewordPassRate==1&&~fit.boundaryHit&& ...
    allRow.fewerPreErrorsButPassToFailCalibrated<=allRow.fewerPreErrorsButPassToFailRaw&& ...
    allRow.reverseCrossingCountCalibrated<=allRow.reverseCrossingCountRaw&&noNllWorse;
writetable(T,fullfile(out,schema.files.receiverRows));writetable(betaFit,fullfile(out,schema.files.betaFit));
writetable(methodSpecific,fullfile(out,schema.files.methodSpecific));writetable(bootstrap,fullfile(out,schema.files.bootstrap));
writetable(holdout,fullfile(out,schema.files.holdout));writetable(clip,fullfile(out,schema.files.clip));writetable(transitions,fullfile(out,schema.files.transitions));
localManifest(cfg,out,fit,chunkPaths,chunkHashes);localReport(out,fit,bootstrap,holdout,eligible);
candidate=fopen(fullfile(out,schema.files.candidate),'w','n','UTF-8');assert(candidate>=0);fprintf(candidate,'betaStar=%.17g\ncandidateEligible=%d\nhumanApproved=false\nDECODER_BETA_APPROVED=false\n',fit.betaStar,eligible);fclose(candidate);
save(fullfile(out,schema.files.resultsMat),'cfg','T','fit','methodSpecific','bootstrap','holdout','clip','transitions','betaGrid','lossGrid','bitCounts','eligible','-v7.3');
artifacts=struct('fit',fit,'methodSpecific',methodSpecific,'bootstrap',bootstrap,'holdout',holdout,'clip',clip,'transitions',transitions,'candidateEligible',eligible);
end
function paths=localPaths(paths,indices)
numbers=zeros(numel(paths),1);for i=1:numel(paths),token=regexp(paths(i),'scenario_(\d+)\.mat','tokens','once');numbers(i)=str2double(token{1});end
paths=paths(ismember(numbers,indices));assert(numel(paths)==numel(indices));
end
function localManifest(cfg,out,fit,paths,hashes)
f=fopen(fullfile(out,'decoder_confidence_manifest.txt'),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,['experimentName=%s\nmasterSeed=%d\nbootstrapSeed=%d\nscenarioCount=%d\ncalibrationScenarios=1:8\nholdoutScenarios=9:12\nSNRdBGrid=%s\nmethods=%s\n' ...
'betaModel=Lcal=beta*Lraw\nbetaBounds=[0.01 2.0]\nbetaSelection=pooled_bitwise_logistic_NLL_not_BLER\nbootstrapUnit=scenario\nbootstrapCount=2000\n' ...
'commonBetaAcrossMethodsSnrCodewords=true\nclippingDiagnosticOnly=[10 20 40 Inf]\ndecoderIterations=50\ndecoderAlgorithmUnchanged=true\nbetaStar=%.17g\n'], ...
cfg.experimentName,cfg.masterSeed,cfg.bootstrapSeed,cfg.scenarioCount,mat2str(cfg.SNRdBGrid),strjoin(cfg.methods,','),fit.betaStar);
for i=1:numel(paths),fprintf(f,'chunk=%s SHA256=%s\n',paths(i),hashes(i));end
end
function localReport(out,fit,B,H,eligible)
f=fopen(fullfile(out,'decoder_confidence_report.txt'),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));all=H(H.method=="ALL",:);
fprintf(f,'Decoder-confidence temperature calibration development experiment; not final performance validation.\n');
fprintf(f,'Public betaStar=%.9g selected only by calibration pooled logistic NLL: beta=1 %.9g, betaStar %.9g, relative reduction %.4f%%, bits=%d, boundaryHit=%d.\n',fit.betaStar,fit.lossAtOne,fit.lossAtBetaStar,100*fit.relativeLossReduction,fit.sampleBitCount,fit.boundaryHit);
fprintf(f,'Scenario bootstrap median=%.9g, 95%% CI=[%.9g, %.9g], boundary hits=%d/%d.\n',median(B.beta),auditDeterministicPercentile(B.beta,.025),auditDeterministicPercentile(B.beta,.975),nnz(B.boundaryHit),height(B));
fprintf(f,'Holdout pooled NLL raw/calibrated %.9g/%.9g; codeword BLER %.6g/%.6g; fewer-error pass-to-fail %d/%d; reverse crossings %d/%d.\n',all.pooledNllRaw,all.pooledNllCalibrated,all.codewordBlerRaw,all.codewordBlerCalibrated,all.fewerPreErrorsButPassToFailRaw,all.fewerPreErrorsButPassToFailCalibrated,all.reverseCrossingCountRaw,all.reverseCrossingCountCalibrated);
fprintf(f,'candidateEligible=%d. Human approval remains required. No DECODER_BETA_APPROVED marker is generated. Temperature acts only on LDPC decoder input; hard bits, pre-BER, NMSE, EVM, estimators, EP, and decoder configuration are unchanged.\n',eligible);
end
