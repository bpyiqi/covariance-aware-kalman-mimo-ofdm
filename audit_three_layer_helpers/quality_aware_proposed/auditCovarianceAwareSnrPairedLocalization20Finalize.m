function artifacts=auditCovarianceAwareSnrPairedLocalization20Finalize(cfg,out,T,testMode)
%AUDITCOVARIANCEAWARESNRPAIREDLOCALIZATION20FINALIZE Aggregate paired localization evidence.
schema=auditCovarianceAwareSnrPairedLocalization20Schema();if ~testMode,assert(height(T)==numel(cfg.SNRdBGrid)*cfg.scenarioCount*numel(cfg.methods));end
S=localSummary(T);B=auditPairedSnrStrictBrackets(S,cfg.methods,cfg.targetCodewordBler);
[trends,rawWarnings]=auditPairedSnrTrendTables(T,S,cfg.methods);H=localCrossSnr(T,cfg);
writetable(T,fullfile(out,schema.files.packetLevel));writetable(S,fullfile(out,schema.files.summary));
writetable(B,fullfile(out,schema.files.brackets));writetable(trends,fullfile(out,schema.files.trends));
writetable(rawWarnings,fullfile(out,schema.files.rawWarnings));writetable(H,fullfile(out,schema.files.crossSnr));
localManifest(cfg,out,schema);localReport(cfg,out,T,B,rawWarnings,H,schema);
save(fullfile(out,schema.files.resultsMat),'cfg','T','S','B','trends','rawWarnings','H','-v7.3');
artifacts=struct('summary',S,'brackets',B,'trends',trends,'rawWarnings',rawWarnings,'crossSnr',H);
end
function S=localSummary(T)
schema=auditCovarianceAwareSnrPairedLocalization20Schema();keys=unique(T(:,{'targetSnrDb','method'}),'rows');rows=cell(height(keys),1);
for i=1:height(keys)
    x=T(T.targetSnrDb==keys.targetSnrDb(i)&T.method==keys.method(i),:);decoded=sum(x.decodedCodewordCount);errors=sum(x.codewordErrorCount);
    [lo,hi]=auditWilsonBinomialInterval(errors,decoded,.95);evm2=mean(x.softEvmSquared);
    rows{i}=table(keys.targetSnrDb(i),keys.method(i),height(x),decoded,errors,errors/decoded,lo,hi, ...
        1-mean(x.codewordPass),mean(x.preLdpcBer),mean(x.avgCsiNmse),mean(x.softEvm), ...
        10*log10(1/max(evm2,eps)),mean(x.goodputMbps),'VariableNames',cellstr(schema.summary));
end
S=vertcat(rows{:});
end
function H=localCrossSnr(T,cfg)
schema=auditCovarianceAwareSnrPairedLocalization20Schema();indices=unique(T.scenarioIndex);rows=cell(numel(indices),1);
for i=1:numel(indices)
    x=T(T.scenarioIndex==indices(i),:);u=@(name)numel(unique(x.(name)));
    counts=[u('scenarioHashH'),u('scenarioHashTxBits'),u('scenarioHashQam'),u('scenarioHashPaddingBits'),u('scenarioHashPaddingSymbols'),u('scenarioHashUnitNoise')];
    yCount=numel(unique(x.sharedHashY));maxError=max(abs(x.realizedSnrDb-x.targetSnrDb));
    pass=all(counts==1)&&yCount==numel(cfg.SNRdBGrid)&&maxError<=cfg.realizedSnrToleranceDb;
    rows{i}=table(indices(i),x.scenarioSeed(1),numel(unique(x.targetSnrDb)),counts(1),counts(2),counts(3),counts(4),counts(5),counts(6),yCount,maxError,pass,'VariableNames',cellstr(schema.crossSnr));
end
H=vertcat(rows{:});assert(all(H.allCrossSnrGatesPass));
end
function localManifest(cfg,out,schema)
f=fopen(fullfile(out,schema.files.manifest),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,['experimentName=%s\nschemaVersion=%s\nmasterSeed=%d\nbootstrapSeed=%d\nSNRdBGrid=%s\nscenarioCount=%d\npayloadSymbols=%d\nnCodeword=%d\nmethods=%s\n' ...
'commonRandomNumbers=true\nscenarioSeedFormula=masterSeed+100000*scenarioIndex\nscenarioSubSeeds=padding+101,bits+202,channel+303,unitNoise+404,pilotNoise+505\n' ...
'noiseVarFormula=10^(-targetSnrDb/10)\nnoiseScaleFormula=sqrt(noiseVar)\nrealizedSnrDefinitionDb=10log10(1/mean(abs(noiseScale*Wunit)^2))\nrealizedSnrToleranceDb=%.6g\n' ...
'CRNExplanation=Within a scenario all SNR points share channel, transmitted data, padding, and standardized Gaussian noise direction; only noise amplitude changes. Scenarios remain independent, each SNR retains the correct marginal Gaussian noise distribution, and no receiver parameter is tuned.\n' ...
'fixedRadius=3\nllrThreshold=2.5\nminEffectiveSamples=2\ngramRcondThreshold=0.001\nRDA=RLS\nNIS=false\nalpha_nis=false\nalpha_dec=false\ndynamicRadius=false\n'], ...
cfg.experimentName,schema.version,cfg.masterSeed,cfg.bootstrapSeed,mat2str(cfg.SNRdBGrid),cfg.scenarioCount,cfg.Npayload,cfg.Ncodeword,strjoin(cfg.methods,','),cfg.realizedSnrToleranceDb);
end
function localReport(cfg,out,T,B,W,H,schema)
f=fopen(fullfile(out,schema.files.report),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,'Paired coarse SNR localization with common random numbers; not a final performance curve and not a tuning experiment.\n');
fprintf(f,'Each scenario shares H, information/coded bits, QAM, padding, valid mask, and standardized Gaussian noise across all SNR points. Only sqrt(noiseVar) changes. Scenarios are mutually independent and each SNR retains the correct marginal Gaussian distribution.\n');
fprintf(f,'Rows=%d; scenarios=%d; SNR points=%d; decoded codewords per SNR/method=%d; realized-SNR tolerance=%.3f dB; maximum observed error=%.6g dB.\n',height(T),height(H),numel(cfg.SNRdBGrid),cfg.scenarioCount*cfg.Ncodeword,cfg.realizedSnrToleranceDb,max(H.maxRealizedSnrErrorDb));
fprintf(f,'Raw BLER is neither smoothed nor interpolated. Wilson 95%% intervals use decoded codewords as denominator.\n');
for i=1:height(B),fprintf(f,'%s bracket=%d exactHit=%d plateau=%d monotonicWarning=%d CIContainsTarget=%d suggestion=%s.\n',B.method(i),B.bracketFound(i),B.exactGridHit(i),B.targetPlateau(i),B.monotonicityWarning(i),B.ciContainsTargetAtAnyPoint(i),B.extensionSuggestion(i));end
perfect=W(W.method=="PerfectCSI_EP"&W.metric=="preLdpcBer",:);fprintf(f,'PerfectCSI pre-LDPC BER raw monotonicity warning=%d.\n',perfect.monotonicityWarning);
fprintf(f,'All cross-SNR hash gates pass=%d. COMPLETE is written only after every scenario contributes all SNR x method rows.\n',all(H.allCrossSnrGatesPass));
end
