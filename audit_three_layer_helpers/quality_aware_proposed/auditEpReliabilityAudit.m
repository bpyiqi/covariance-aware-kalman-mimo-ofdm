function result=auditEpReliabilityAudit(root,options)
%AUDITEPRELIABILITYAUDIT Read-only dry-run or offline raw-LLR reliability audit.
arguments,root (1,:) char,options.run (1,1) logical=false,end
cfg=auditEpReliabilityConfig(root);source=auditEpReliabilityPreflight(cfg);
if ~options.run
    assert(exist(cfg.outputDirectory,'dir')~=7,'Dry-run must not create the EP reliability output directory.');
    result=struct('dryRun',true,'verifiedChunkCount',source.chunkCount,'receiverRuns',0,'physicalSeedsConsumed',0);
    fprintf('EP reliability audit dry-run PASS: source COMPLETE=1, chunks=12, hashes=12, receiverRuns=0, physicalSeeds=0.\n');return;
end
auditRefuseNonemptyOutput(cfg.outputDirectory);if exist(cfg.outputDirectory,'dir')~=7,mkdir(cfg.outputDirectory);end
[rawRows,tailRows,varianceRows,quantiles]=auditEpReliabilityBuildRows(cfg,source);bins=auditEpReliabilityAggregate(rawRows);
byMethod=localEnhance(bins(bins.dimension=="method"|bins.dimension=="methodSnr",:),bins,tailRows,quantiles);
bySnr=localEnhance(bins(bins.dimension=="snr",:),bins,tailRows,quantiles);
tails=localTailSummary(tailRows);slope=auditEpReliabilitySlopeDiagnostics(cfg,source);
writetable(byMethod,fullfile(cfg.outputDirectory,'ep_llr_reliability_by_method.csv'));writetable(bySnr,fullfile(cfg.outputDirectory,'ep_llr_reliability_by_snr.csv'));
writetable(bins,fullfile(cfg.outputDirectory,'ep_llr_reliability_bins.csv'));writetable(tails,fullfile(cfg.outputDirectory,'ep_llr_tail_audit.csv'));
writetable(varianceRows,fullfile(cfg.outputDirectory,'ep_variance_reliability_audit.csv'));writetable(slope,fullfile(cfg.outputDirectory,'ep_llr_calibration_slope_diagnostic.csv'));
auditWriteEpLlrFormulaAudit(fullfile(cfg.outputDirectory,'ep_llr_formula_audit.txt'),root);localManifest(cfg,source);localReport(cfg,bins,byMethod,varianceRows,slope);
save(fullfile(cfg.outputDirectory,'ep_reliability_results.mat'),'cfg','source','rawRows','bins','byMethod','bySnr','tails','varianceRows','quantiles','slope','-v7.3');
fclose(fopen(fullfile(cfg.outputDirectory,'COMPLETE'),'w'));
result=struct('dryRun',false,'receiverRuns',0,'physicalSeedsConsumed',0,'outputDirectory',string(cfg.outputDirectory));
end
function enhanced=localEnhance(summary,bins,tails,quantiles)
enhanced=summary;enhanced.maximumCalibrationError=nan(height(enhanced),1);enhanced.wrongTailRatio=nan(height(enhanced),1);enhanced.highConfidenceErrorNllContribution=nan(height(enhanced),1);enhanced.medianSignedMargin=nan(height(enhanced),1);enhanced.p95SignedMargin=nan(height(enhanced),1);
for i=1:height(enhanced)
    method=enhanced.method(i);snr=enhanced.targetSnrDb(i);take=bins.method==method&bins.targetSnrDb==snr&bins.dimension=="absLlrBin";
    if snr==-999,take=bins.method==method&bins.dimension=="absLlrBin";end
    if method=="ALL",take=bins.method~="ALL"&bins.targetSnrDb==snr&bins.dimension=="absLlrBin";end
    enhanced.maximumCalibrationError(i)=max(abs(bins.empiricalErrorRate(take)-bins.meanPredictedErrorProbability(take)),[],'omitnan');
    tailTake=tails.method==method&tails.targetSnrDb==snr&tails.absLlrThreshold==10;if snr==-999,tailTake=tails.method==method&tails.absLlrThreshold==10;end;if method=="ALL",tailTake=tails.targetSnrDb==snr&tails.absLlrThreshold==10;end
    if any(tailTake),wrong=sum(tails.wrongBitCount(tailTake));correct=sum(tails.correctBitCount(tailTake));enhanced.wrongTailRatio(i)=wrong/max(correct,1);enhanced.highConfidenceErrorNllContribution(i)=sum(tails.wrongTailNll(tailTake))/max(sum(tails.totalNll(tailTake)),eps);end
    qTake=quantiles.method==method&quantiles.targetSnrDb==snr;if snr==-999,qTake=quantiles.method==method;end;if method=="ALL",qTake=quantiles.targetSnrDb==snr;end
    if any(qTake),enhanced.medianSignedMargin(i)=mean(quantiles.medianSignedMargin(qTake));enhanced.p95SignedMargin(i)=mean(quantiles.p95SignedMargin(qTake));end
end
end
function result=localTailSummary(rows)
keys=unique(rows(:,{'method','targetSnrDb','absLlrThreshold'}),'rows');out=cell(height(keys),1);
for i=1:height(keys),x=rows(rows.method==keys.method(i)&rows.targetSnrDb==keys.targetSnrDb(i)&rows.absLlrThreshold==keys.absLlrThreshold(i),:);out{i}=table(keys.method(i),keys.targetSnrDb(i),keys.absLlrThreshold(i),sum(x.wrongBitCount),sum(x.correctBitCount),sum(x.wrongTailNll),sum(x.totalNll),sum(x.wrongBitCount)/max(sum(x.correctBitCount),1),sum(x.wrongTailNll)/max(sum(x.totalNll),eps), ...
'VariableNames',{'method','targetSnrDb','absLlrThreshold','wrongBitCount','correctBitCount','wrongTailNll','totalNll','wrongCorrectTailRatio','highConfidenceErrorNllContribution'});end
result=vertcat(out{:});
end
function localManifest(cfg,source)
f=fopen(fullfile(cfg.outputDirectory,'ep_reliability_manifest.txt'),'w','n','UTF-8');assert(f>=0);cleanup=onCleanup(@()fclose(f));
fprintf(f,'experiment=%s\nsource=%s\nreceiverRuns=0\nphysicalSeedsConsumed=0\nabsLlrBins=%s\n',cfg.experimentName,cfg.sourceDirectory,strjoin(cfg.absLlrLabels,','));
for i=1:source.chunkCount,fprintf(f,'chunk=%s SHA256=%s\n',source.chunkPaths(i),source.chunkHashes(i));end
end
function localReport(cfg,bins,methods,variance,slope)
f=fopen(fullfile(cfg.outputDirectory,'ep_reliability_report.txt'),'w','n','UTF-8');assert(f>=0);cleanup=onCleanup(@()fclose(f));
fprintf(f,'EP soft-information reliability audit. Only frozen raw LLR chunks were read; no receiver, EP, Kalman, decoder, channel, or physical seed was rerun.\n\n');
fprintf(f,'Evidence available: bitwise raw-LLR reliability by method/SNR/stream/QAM-bit/codeword/symbol interval/subcarrier/magnitude bin. Per-RE posterior/extrinsic variance was not captured in raw chunks, so ep_variance_reliability_audit.csv records availability=notCapturedInRawChunk and does not infer variance from LLR.\n\n');
fprintf(f,'Implementation-supported classification: B and C are formula-level omissions because auditEpDetectorOjcd passes only noiseVar into its precision and discrete posterior; no explicit residual-interference or channel-estimation-uncertainty variance appears. D is not supported: posterior normalization and bit LLRs use exact stabilized sums, not max-log. E is not supported for decoder priors: no decoder prior LLR is passed into EP. F has an explicit 1e-12 variance/precision floor and rollback; its actual frequency is unavailable from chunks. A and the dominant quantitative cause remain H (cannot determine) without saved per-RE v_e/v_p and rollback counters.\n\n');
fprintf(f,'PerfectCSI high-confidence errors therefore cannot be attributed solely to channel-estimation uncertainty; their concentration is reported by stream/QAM-bit/subcarrier bins. OJCD uses the same final EP formula but a two-stage Hdata path. CovarianceAware raw NLL relative to Base is measured in ep_llr_reliability_by_method.csv; this audit does not assert a cause beyond the formula and observed reliability evidence. Unified beta and clipping failed because their common transform could not satisfy every method holdout constraint; this audit does not search replacements.\n\n');
fprintf(f,'Rows: bins=%d, method/SNR=%d, variance audit=%d, slope diagnostics=%d. No approval marker is generated.\n',height(bins),height(methods),height(variance),height(slope));
end
