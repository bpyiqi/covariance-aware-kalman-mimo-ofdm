function result=auditLlrLdpcReplaySmoke(root)
%AUDITLLRLDPCREPLAYSMOKE Deterministic replay of three frozen paired scenarios.
source=fullfile(root,'results_three_layer_validation','covariance_aware_snr_paired_localization20_seed20260725');
out=fullfile(root,'results_three_layer_validation','covariance_aware_llr_ldpc_replay_smoke_v1');
assert(isfile(fullfile(source,'COMPLETE')));assert(exist(out,'dir')~=7,'Refusing to overwrite replay output: %s',out);mkdir(out);
formal=readtable(fullfile(source,'paired_localization_packet_level.csv'),'TextType','string');
cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);methods=["PerfectCSI_EP","CovarianceAwareLocalDAKalmanCausal_EP","BaseKalmanCausal_EP","OJCD_LMMSE_EP_Adapted"];
covariance=localCovariance(cfg);codewordTables=cell(3*numel(cfg.SNRdBGrid)*numel(methods),1);varianceTables=codewordTables;scaleTables=codewordTables;cursor=0;
maxHashError=0;maxPreBerError=0;allCodewordRatesMatch=true;
for scenarioIndex=1:3
    scenario=auditBuildPairedSnrScenario(cfg,scenarioIndex);
    expectedScenario=formal(formal.scenarioIndex==scenarioIndex,:);
    maxHashError=max(maxHashError,localScenarioHashError(scenario,expectedScenario));
    for snrDb=cfg.SNRdBGrid
        point=cfg;point.SNRdB=snrDb;point.noiseVar=10^(-snrDb/10);packet=auditRealizePairedSnrScenario(point,scenario,snrDb);
        expectedSnr=expectedScenario(expectedScenario.targetSnrDb==snrDb,:);
        maxHashError=max(maxHashError,min(abs(expectedSnr.sharedHashY-packet.sharedHashY)));
        online=struct('pilotObservation',packet.obs,'receivedData',packet.y,'validDataMask',packet.validReMask, ...
            'validReMask',packet.validReMask,'noiseVar',point.noiseVar,'rho',point.rho,'Npayload',packet.Npayload, ...
            'nCodeword',packet.nCodeword,'usefulBitMask',packet.usefulBitMask);
        for method=methods
            switch method
                case "PerfectCSI_EP"
                    Hhat=packet.H;receiver=auditMechanismOnlineReceive(point,online,Hhat,0);
                case {"CovarianceAwareLocalDAKalmanCausal_EP","BaseKalmanCausal_EP"}
                    estimate=auditMechanismRunSingleEstimator(point,online,method);Hhat=estimate.Hhat;
                    receiver=auditMechanismOnlineReceive(point,online,Hhat,estimate.onlineEstimationRuntimeSeconds);
                case "OJCD_LMMSE_EP_Adapted"
                    oj=auditCovarianceAwareOjcdReceive(point,packet,covariance);Hhat=oj.Hhat;receiver=oj.receiver;
            end
            metric=auditMechanismOfflineDetectionMetrics(point,receiver,Hhat,packet.H,scenario.qam,scenario.codedBits,scenario.validReMask);
            expected=expectedSnr(expectedSnr.method==method,:);assert(height(expected)==1);
            maxPreBerError=max(maxPreBerError,abs(metric.preLdpcBer-expected.preLdpcBer));
            allCodewordRatesMatch=allCodewordRatesMatch&&abs(metric.codewordPassRate-expected.codewordPassRate)<1e-12;
            [C,V,B]=auditAnalyzeLlrLdpcReceiver(point,scenario,packet,receiver,method);cursor=cursor+1;
            codewordTables{cursor}=C;varianceTables{cursor}=V;scaleTables{cursor}=B;
        end
    end
    fprintf('LLR replay checkpoint: scenario=%d/%d method-runs=%d\n',scenarioIndex,3,cursor);
end
C=vertcat(codewordTables{1:cursor});V=vertcat(varianceTables{1:cursor});B=vertcat(scaleTables{1:cursor});
assert(maxHashError<=1e-5,'Frozen replay hash mismatch %.9g.',maxHashError);
assert(maxPreBerError<=1e-12&&allCodewordRatesMatch,'Frozen replay metric mismatch.');
X=localTransitions(C);writetable(C,fullfile(out,'llr_ldpc_codeword_diagnostics.csv'));
writetable(X,fullfile(out,'llr_ldpc_snr_transition_audit.csv'));writetable(V,fullfile(out,'llr_variance_chain_audit.csv'));
writetable(B,fullfile(out,'llr_scale_sensitivity_diagnostic.csv'));
localReport(out,C,X,V,B,maxHashError,maxPreBerError);
save(fullfile(out,'llr_ldpc_replay_results.mat'),'C','X','V','B','maxHashError','maxPreBerError','-v7.3');
result=struct('outputDirectory',out,'codewordRows',height(C),'transitionRows',height(X),'varianceRows',height(V), ...
    'scaleRows',height(B),'maxHashAbsoluteError',maxHashError,'maxPreLdpcBerError',maxPreBerError, ...
    'allCodewordRatesMatch',allCodewordRatesMatch,'fewerErrorsPassToFailCount',nnz(X.fewerPreErrorsButPassToFail));
fprintf('LLR/LDPC replay PASS: codewordRows=%d transitions=%d fewerErrorsPassToFail=%d maxHashError=%.9g.\n',height(C),height(X),result.fewerErrorsPassToFailCount,maxHashError);
end

function error=localScenarioHashError(s,T)
pairs={s.hashes.H,'scenarioHashH';s.hashes.txBits,'scenarioHashTxBits';s.hashes.qam,'scenarioHashQam'; ...
s.hashes.paddingBits,'scenarioHashPaddingBits';s.hashes.paddingSymbols,'scenarioHashPaddingSymbols';s.hashes.unitNoise,'scenarioHashUnitNoise'};
error=0;for i=1:size(pairs,1),error=max(error,min(abs(T.(pairs{i,2})-pairs{i,1})));end
end
function covariance=localCovariance(cfg),s=load(cfg.covariancePath,'covariance');covariance=s.covariance;end

function X=localTransitions(C)
keys=unique(C(:,{'method','scenarioIndex','codewordIndex'}),'rows');rows=cell(height(keys)*6,1);cursor=0;
for i=1:height(keys)
    x=sortrows(C(C.method==keys.method(i)&C.scenarioIndex==keys.scenarioIndex(i)&C.codewordIndex==keys.codewordIndex(i),:),'targetSnrDb');
    for j=1:height(x)-1
        cursor=cursor+1;fewer=x.preLdpcBitErrorCount(j+1)<=x.preLdpcBitErrorCount(j)&&x.decoderPass(j)&&~x.decoderPass(j+1);
        rows{cursor}=table(keys.method(i),keys.scenarioIndex(i),keys.codewordIndex(i),x.targetSnrDb(j),x.targetSnrDb(j+1), ...
            x.preLdpcBitErrorCount(j),x.preLdpcBitErrorCount(j+1),x.decoderPass(j),x.decoderPass(j+1), ...
            x.wrongBitMeanAbsLlr(j),x.wrongBitMeanAbsLlr(j+1),x.wrongBitMaxAbsLlr(j),x.wrongBitMaxAbsLlr(j+1), ...
            x.llrClipFraction(j),x.llrClipFraction(j+1),fewer, ...
            'VariableNames',{'method','scenarioIndex','codewordIndex','lowerSnr','upperSnr','lowerPreBitErrors', ...
            'upperPreBitErrors','lowerDecoderPass','upperDecoderPass','lowerWrongMeanAbsLlr','upperWrongMeanAbsLlr', ...
            'lowerWrongMaxAbsLlr','upperWrongMaxAbsLlr','lowerClipFraction','upperClipFraction','fewerPreErrorsButPassToFail'});
    end
end
X=vertcat(rows{1:cursor});
end

function localReport(out,C,X,V,B,hashError,berError)
f=fopen(fullfile(out,'llr_ldpc_root_cause_report.txt'),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fewer=nnz(X.fewerPreErrorsButPassToFail);high=nnz(C.wrongBitHighConfidenceCount10>0);saturated=sum(C.wrongBitSaturatedCount);hardMismatch=sum(C.hardDecisionMismatchCount);
base=B(B.beta==1,:);down=B(B.beta==.25,:);keys={'method','scenarioIndex','targetSnrDb','codewordIndex'};base=sortrows(base,keys);down=sortrows(down,keys);
downRescues=nnz(~base.decoderPass&down.decoderPass);downHarms=nnz(base.decoderPass&~down.decoderPass);
fprintf(f,'LLR/LDPC root-cause evidence report\nFrozen replay hash max absolute CSV error=%.9g; pre-LDPC BER max error=%.9g; codeword pass rates all match.\n',hashError,berError);
fprintf(f,'Codeword rows=%d; fewer-pre-errors pass-to-fail transitions=%d; rows with wrong |LLR|>=10=%d; infinite/saturated wrong LLR count=%d.\n',height(C),fewer,high,saturated);
fprintf(f,'Bitwise-MAP LLR hard decisions differ from symbol-MAP hard-symbol labels at %d bit positions. This is not a serialization error: the independent round-trip is exact, and OJCD has zero such mismatches; it reflects different bitwise versus joint-symbol decision rules in the standard EP path.\n',hardMismatch);
fprintf(f,'Uniform beta=0.25 diagnostic rescues=%d and harms=%d relative to beta=1. This is sensitivity evidence, not parameter selection.\n',downRescues,downHarms);
for method=unique(base.method,'stable').'
    mb=base(base.method==method,:);md=down(down.method==method,:);
    fprintf(f,'  %s: beta=0.25 rescues=%d, harms=%d.\n',method,nnz(~mb.decoderPass&md.decoderPass),nnz(mb.decoderPass&~md.decoderPass));
end
fprintf(f,'Variance chain: decoder path has no explicit LLR clip; complex AWGN variance is passed to EP and per-real variance is half. Posterior symbol variance range=[%.9g, %.9g].\n',min(V.minimumPosteriorSymbolVariance),max(V.maximumPosteriorSymbolVariance));
fprintf(f,['\nClassification\nA bit order/mapping error: excluded by zero-error round trip and noiseless end-to-end tests.\n' ...
'B LLR sign convention error: excluded by ideal decoder and EP/demapper sign tests.\n' ...
'C noise/posterior variance scaling error: AWGN complex/real factor is internally consistent; residual channel-estimation uncertainty is not explicitly added to standard EP noise variance, so model-mismatch scaling is not fully excluded for estimated-CSI methods. OJCD uses covariance in channel estimation, but its final EP detector is still passed AWGN variance only. This cannot explain PerfectCSI by itself.\n' ...
'D clipping/overconfidence: explicit decoder clipping is absent. High-confidence wrong bits and beta sensitivity support overconfidence as a plausible contributor.\n' ...
'E LDPC trapping/numerical behavior: fewer-error pass-to-fail transitions and sensitivity to positive LLR scaling support iterative-decoder trapping/numerical behavior.\n' ...
'F codeword pass/comparison indexing error: excluded by CRC, offline truth comparison, and noiseless 3-codeword tests.\n' ...
'Primary evidence-based classification: D/E combination; no formal receiver parameter was changed.\n\n' ...
'NMSE is unaffected because all diagnostics occur after channel estimation. Pre-LDPC BER is unaffected because signs/order are unchanged. BLER and goodput are affected by soft magnitude and iterative decoding behavior.\n' ...
'validation50 should not be rerun until a separately reviewed decoder-confidence treatment is defined. The paired SNR experiment will require rerun only after such a receiver-chain correction is approved; current frozen results remain diagnostic and cannot support thresholds.\n']);
end
