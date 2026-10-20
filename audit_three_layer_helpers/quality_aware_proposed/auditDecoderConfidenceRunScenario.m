function [rows,chunk]=auditDecoderConfidenceRunScenario(cfg,scenarioIndex)
%AUDITDECODERCONFIDENCERUNSCENARIO Run one complete CRN scenario and collect post-receiver raw LLR.
scenario=auditBuildPairedSnrScenario(cfg,scenarioIndex);covariance=localCovariance(cfg);
recordCount=numel(cfg.SNRdBGrid)*numel(cfg.methods);records=cell(recordCount,1);rowCells=cell(recordCount,1);cursor=0;
for snrDb=cfg.SNRdBGrid
    point=cfg;point.SNRdB=snrDb;point.noiseVar=10^(-snrDb/10);packet=auditRealizePairedSnrScenario(point,scenario,snrDb);
    online=struct('pilotObservation',packet.obs,'receivedData',packet.y,'validDataMask',packet.validReMask, ...
        'validReMask',packet.validReMask,'noiseVar',point.noiseVar,'rho',point.rho,'Npayload',packet.Npayload, ...
        'nCodeword',packet.nCodeword,'usefulBitMask',packet.usefulBitMask);
    for method=cfg.methods
        switch method
            case {"BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP"}
                estimate=auditMechanismRunSingleEstimator(point,online,method);Hhat=estimate.Hhat;
                receiver=auditMechanismOnlineReceive(point,online,Hhat,estimate.onlineEstimationRuntimeSeconds);
            case "OJCD_LMMSE_EP_Adapted"
                oj=auditCovarianceAwareOjcdReceive(point,packet,covariance);Hhat=oj.Hhat;receiver=oj.receiver;
            case "PerfectCSI_EP"
                Hhat=packet.H;receiver=auditMechanismOnlineReceive(point,online,Hhat,0);
        end
        metric=auditMechanismOfflineDetectionMetrics(point,receiver,Hhat,packet.H,scenario.qam,scenario.codedBits,scenario.validReMask);
        rawDouble=double(receiver.llr(scenario.usefulBitMask));rawSingle=single(rawDouble);hard=rawDouble<0;
        cursor=cursor+1;records{cursor}=struct('scenarioIndex',scenarioIndex,'targetSnrDb',snrDb,'method',method, ...
            'rawUsefulLlr',rawSingle,'hardUsefulBits',logical(hard),'baselineCodewordPass',logical(receiver.codewordPass));
        split=localSplit(cfg,scenarioIndex);h=scenario.hashes;
        rowCells{cursor}=table(cfg.experimentName,cfg.masterSeed,scenarioIndex,split,snrDb,method,h.H,h.txBits,h.qam,h.unitNoise, ...
            packet.sharedHashY,numel(rawSingle),localHash(rawSingle),max(abs(rawDouble-double(rawSingle))),metric.preLdpcBer, ...
            metric.csiNmse,metric.softEvmRms,metric.codewordPassRate,double(metric.codewordPassRate==1), ...
            receiver.onlineRuntimeSeconds,double(receiver.hasNaN),double(receiver.hasInf), ...
            'VariableNames',cellstr(auditDecoderConfidenceCalibrationSchema().receiverRows));
    end
end
rows=vertcat(rowCells{:});assert(height(rows)==recordCount&&~any(rows.hasNaN)&&~any(rows.hasInf));
chunk=struct('schemaVersion',"1.0",'experimentName',cfg.experimentName,'scenarioIndex',scenarioIndex, ...
    'scenarioSeed',scenario.scenarioSeed,'split',localSplit(cfg,scenarioIndex),'records',{records}, ...
    'codedBits',logical(scenario.codedBits),'informationBits',logical(scenario.informationBits), ...
    'usefulBitMask',logical(scenario.usefulBitMask),'codewordBoundaries',[1 cfg.ldpc.N+1 2*cfg.ldpc.N+1 3*cfg.ldpc.N+1], ...
    'scenarioHashes',scenario.hashes);
for i=1:numel(records),assert(numel(records{i}.rawUsefulLlr)==3*cfg.ldpc.N&&isequal(records{i}.hardUsefulBits,records{i}.rawUsefulLlr<0));end
end
function split=localSplit(cfg,index),if ismember(index,cfg.calibrationScenarios),split="calibration";else,split="holdout";end,end
function covariance=localCovariance(cfg),s=load(cfg.covariancePath,'covariance');covariance=s.covariance;end
function value=localHash(data),v=double(data(:));w=mod((1:numel(v))',104729)+1;value=sum(real(v).*w)+sqrt(2)*sum(imag(v).*w)+sum(abs(v).^2)/max(numel(v),1);end
