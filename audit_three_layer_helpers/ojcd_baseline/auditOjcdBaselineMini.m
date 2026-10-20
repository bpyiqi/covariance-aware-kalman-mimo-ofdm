function auditOjcdBaselineMini(root,variant)
%AUDITOJCDBASELINEMINI User-invoked 5-packet x 2-condition paired mini.
% Codex implementation work must never call this random experiment.
if nargin<2,variant='mini';end
isDiagnostic20=strcmpi(variant,'diagnostic20');cfg=auditOjcdBaselineConfig(root);
if isDiagnostic20
    diagnosticConfig=auditOjcdDiagnostic20Config(cfg);out=diagnosticConfig.outputDirectory;packetCount=diagnosticConfig.packetCountPerCondition;
else
    out=cfg.miniOutput;packetCount=cfg.NpacketPerCondition;
end
if ~exist(out,'dir'),mkdir(out);end
if ~exist(cfg.covariancePath,'file'),covariance=auditBuildOjcdFrequencyCovariance(cfg,cfg.covariancePath);else,L=load(cfg.covariancePath,'covariance');covariance=L.covariance;end
validateCovariance(covariance);
constellation=qammod((0:15).',16,'UnitAveragePower',true);methods=["PerfectCSI_EP","BaseKalmanCausal_EP", ...
    "ProposedCausal_EP","TraditionalLMMSE_EP_Adapted","OJCD_LMMSE_EP_Adapted"];
if isDiagnostic20,assert(isequal(methods,diagnosticConfig.methods),'Diagnostic method configuration drift.');end
rng(cfg.ojcdMiniMasterSeed,'twister');physicalPacketCount=2*packetCount;methodCount=numel(methods);rowTables=cell(physicalPacketCount*methodCount,1);hashTables=cell(physicalPacketCount,1);convergenceTables=cell(physicalPacketCount,1);regularizationTables=cell(physicalPacketCount,1);rowCursor=0;packetCursor=0;rollbackTables=cell(2,packetCount);conditionTables=cell(2,packetCount);results=cell(2,packetCount);wall=tic;
for ci=1:numel(cfg.Ncodeword)
    ncw=cfg.Ncodeword(ci);conditionSeed=cfg.ojcdMiniMasterSeed+100000*ncw;
    for pidx=1:packetCount
        packetSeed=conditionSeed+pidx;rng(packetSeed,'twister');packet=makePacket(ncw);
        [Hbase,Hproposed,gate]=auditOjcdMiniCausalEstimates(cfg,packet);assertGates(gate);
        methodResult=cell(1,5);
        methodResult{1}=epDecode(packet,packet.H,'perfect',0);
        methodResult{2}=epDecode(packet,Hbase,'base',gate.baseEstimationTimeSec);
        methodResult{3}=epDecode(packet,Hproposed,'proposed',gate.proposedEstimationTimeSec);
        methodResult{4}=traditionalDecode(packet,covariance);
        methodResult{5}=ojcdDecode(packet,covariance);
        rollbackTables{ci,pidx}=auditBuildOjcdRollbackAuditTable( ...
            methodResult{5}.auditDetail.rollback,packet.Npayload,pidx,cfg.epIterations);
        conditionTables{ci,pidx}=auditBuildOjcdConditionAuditRow( ...
            methodResult{5},packet.Npayload,pidx);
        packetCursor=packetCursor+1;
        for m=1:5
            r=methodResult{m};if isfield(r,'auditDetail'),r=rmfield(r,'auditDetail');end;r.Ncodeword=ncw;r.Npayload=packet.Npayload;r.payloadSymbols=packet.Npayload;r.packetIndex=pidx;r.method=methods(m);r.masterSeed=cfg.ojcdMiniMasterSeed;r.conditionSeed=conditionSeed;r.packetSeed=packetSeed;r=attachHashes(r,packet.hashes);
            rowCursor=rowCursor+1;rowTables{rowCursor}=struct2table(r,'AsArray',true);
        end
        hashTables{packetCursor}=hashRow(packet,ncw,pidx,conditionSeed,packetSeed);
        convergenceTables{packetCursor}=table(ncw,pidx,methodResult{5}.meanEpPosteriorVarianceJcd1,methodResult{5}.meanEpPosteriorVarianceJcd2,methodResult{5}.negativePrecisionRollbackCount);
        regularizationTables{packetCursor}=table(ncw,pidx,methodResult{5}.ojcdRegularizationCount,methodResult{5}.meanOjcdWeightNorm,methodResult{5}.meanOjcdConditionNumber);
        results{ci,pidx}=struct('packetHashes',packet.hashes,'metrics',{methodResult},'hardGates',gate);
    end
end
rows=vertcat(rowTables{:});hashRows=vertcat(hashTables{:});convergenceRows=vertcat(convergenceTables{:});regularizationRows=vertcat(regularizationTables{:});totalWallTimeSec=toc(wall);
if isDiagnostic20,summary=diagnosticSummary(rows);else,summary=groupsummary(rows,{'Ncodeword','Npayload','method'},{'mean','std'},{'avgCsiNmse','nmseLastThirdPayload','preLdpcBer','postLdpcBer','codewordPassRate','wholePayloadCrcPass','payloadOnlyGoodputMbps','endToEndGoodputMbps','processingTimeSec'});end
paired=pairedStatistics(rows);
if isDiagnostic20
    rollbackAudit=vertcat(rollbackTables{:});conditionAudit=vertcat(conditionTables{:});pairingAudit=diagnosticPairingHashes(hashRows,methods);
    artifactTables=struct('packet',rows,'rollback',rollbackAudit,'condition',conditionAudit,'summary',summary,'paired',paired,'hash',pairingAudit);auditValidateOjcdDiagnostic20Tables(artifactTables,2*packetCount,numel(methods));
    writetable(rows,fullfile(out,'ojcd_diagnostic20_packet_level.csv'));writetable(summary,fullfile(out,'ojcd_diagnostic20_summary.csv'));writetable(paired,fullfile(out,'ojcd_diagnostic20_paired_statistics.csv'));writetable(pairingAudit,fullfile(out,'ojcd_diagnostic20_pairing_hashes.csv'));writetable(rollbackAudit,fullfile(out,'ojcd_ep_rollback_rate_audit.csv'));writetable(conditionAudit,fullfile(out,'ojcd_condition_tail_audit.csv'));
else
    writetable(rows,fullfile(out,'ojcd_baseline_mini_packet_level.csv'));writetable(summary,fullfile(out,'ojcd_baseline_mini_summary.csv'));writetable(paired,fullfile(out,'ojcd_baseline_mini_paired_statistics.csv'));writetable(hashRows,fullfile(out,'ojcd_baseline_mini_pairing_hashes.csv'));
end
if ~isDiagnostic20
    convergenceRows.Properties.VariableNames={'Ncodeword','packetIndex','meanEpPosteriorVarianceJcd1','meanEpPosteriorVarianceJcd2','negativePrecisionRollbackCount'};writetable(convergenceRows,fullfile(out,'ojcd_ep_convergence_audit.csv'));
    regularizationRows.Properties.VariableNames={'Ncodeword','packetIndex','ojcdRegularizationCount','meanOjcdWeightNorm','meanOjcdConditionNumber'};writetable(regularizationRows,fullfile(out,'ojcd_regularization_audit.csv'));
end
if isDiagnostic20,save(fullfile(out,'ojcd_diagnostic20_results.mat'),'cfg','rows','summary','paired','hashRows','rollbackAudit','conditionAudit','results','totalWallTimeSec','-v7.3');else,save(fullfile(out,'ojcd_baseline_mini_results.mat'),'cfg','rows','summary','paired','hashRows','results','totalWallTimeSec','-v7.3');end
writeOutputs();fprintf('OJCD baseline %s complete: %s\n',variant,out);

    function packet=makePacket(ncw)
        N=cfg.symbolsPerCodeword*ncw;capacity=N*cfg.codedBitsPerOFDMSymbol;useful=false(capacity,1);bits=logical(randi([0 1],capacity,1));payload=false((cfg.ldpc.K-32)*ncw,1);coded=false(cfg.ldpc.N*ncw,1);
        for cw=1:ncw
            pay=logical(randi([0 1],cfg.ldpc.K-32,1));info=[pay;ofdm.crc32Bits(pay)];code=logical(ldpcEncode([double(info);zeros(cfg.ldpc.K-numel(info),1)],cfg.ldpc.enc));offset=(cw-1)*cfg.symbolsPerCodeword*cfg.codedBitsPerOFDMSymbol;bits(offset+(1:cfg.ldpc.N))=code;useful(offset+(1:cfg.ldpc.N))=true;payload((cw-1)*(cfg.ldpc.K-32)+(1:cfg.ldpc.K-32))=pay;coded((cw-1)*cfg.ldpc.N+(1:cfg.ldpc.N))=code;
        end
        qam=reshape(ofdm.qam16ModBits(double(reshape(bits,4,[]))),2,numel(cfg.data),N);validRe=reshape(all(reshape(useful,8,[]),1),numel(cfg.data),N);
        H=ofdm.generateItuaGmChannel(cfg.NFFT,N,cfg.rho,cfg.Fs);ltf=ofdm.makeNoisyLtfEstimate(squeeze(H(:,1,:,:)),cfg.active,cfg.noiseVar);obs=zeros(size(H),'single');pilotCfr=cell(N,2,2);
        for n=1:N
            po=ofdm.makePayloadPilotObservation(squeeze(H(:,n,:,:)),cfg.pilots,cfg.pilotValues,cfg.pilotTransmitStreamMap,cfg.noiseVar);obs(:,n,:,:)=ofdm.ltfResidualInterpolate(ltf,po,cfg.NFFT);
            for rx=1:2,for tx=1:2,pilotCfr{n,rx,tx}=double(po.h_rx(rx,po.tx==tx)).';end,end
        end
        y=complex(zeros(numel(cfg.data),N,2,'single'));noise=complex(zeros(size(y),'single'));
        for n=1:N,for d=1:numel(cfg.data),w=sqrt(cfg.noiseVar/2)*(randn(2,1)+1j*randn(2,1));noise(d,n,:)=single(w);y(d,n,:)=single(squeeze(H(cfg.data(d),n,:,:))*double(qam(:,d,n))+w);end,end
        paddingBits=bits(~useful);paddingSymbols=qam(repmat(reshape(~validRe,1,numel(cfg.data),N),2,1,1));
        hashes=struct('informationBitsHash',sum(double(payload).*(1:numel(payload))'),'transmitBitsHash',sum(double(bits).*(1:numel(bits))'),'ldpcCodewordHash',sum(double(coded).*(1:numel(coded))'),'qamSymbolsHash',sum(real(qam(:)).*(1:numel(qam))')+sum(imag(qam(:)).*(1:numel(qam))'),'paddingBitHash',sum(double(paddingBits).*(1:numel(paddingBits))'),'paddingSymbolsHash',sum(real(paddingSymbols(:)).*(1:numel(paddingSymbols))')+sum(imag(paddingSymbols(:)).*(1:numel(paddingSymbols))'),'paddingReCount',nnz(~validRe),'paddingMaskHash',sum(double(~useful).*(1:numel(useful))'),'channelHash',sum(abs(H(:)).^2),'noiseHash',sum(abs(noise(:)).^2),'receivedSignalHash',sum(abs(y(:)).^2),'pilotObservationHash',sum(abs(obs(:)).^2));
        packet=struct('Npayload',N,'nCodeword',ncw,'bits',bits,'usefulBitMask',useful,'coded',coded,'payload',payload,'qam',qam,'validReMask',validRe,'H',H,'ltf',ltf,'obs',obs,'pilotCfr',{pilotCfr},'y',y,'noise',noise,'hashes',hashes);
    end
    function result=epDecode(packet,Hhat,label,estimationTime)
        t=tic;N=packet.Npayload;D=numel(cfg.data);llrGrid=zeros(4,2,D,N);rollback=0;variance=zeros(2*nnz(packet.validReMask),1);offset=0;
        for n=1:N,for d=find(packet.validReMask(:,n)).',ep=auditEpDetectorOjcd(reshape(double(packet.y(d,n,:)),2,1),reshape(double(Hhat(cfg.data(d),n,:,:)),2,2),cfg.noiseVar,constellation);llrGrid(:,:,d,n)=ep.bitLlr.';rollback=rollback+ep.negativePrecisionRollbackCount;variance(offset+(1:2))=ep.posteriorVariance;offset=offset+2;end,end
        detectionTime=toc(t);result=decodeMetrics(packet,Hhat,llrGrid,estimationTime+detectionTime);result.negativePrecisionRollbackCount=rollback;result.meanEpPosteriorVarianceJcd1=mean(variance);result.meanEpPosteriorVarianceJcd2=NaN;result.ojcdRegularizationCount=NaN;result.meanOjcdWeightNorm=NaN;result.meanOjcdConditionNumber=NaN;result.futureSymbolReadCount=0;result.testTruthOnlineUseCount=0;result.branchLabel=string(label);result=emptyOjcdAudit(result);
    end
    function result=traditionalDecode(packet,covariance)
        t=tic;N=packet.Npayload;D=numel(cfg.data);Hhat=packet.obs;llrGrid=zeros(4,2,D,N);variance=zeros(2*nnz(packet.validReMask),1);offset=0;rollback=0;
        for n=1:N,pil=pilotCells(packet,n);tr=auditTraditionalLmmseEp(pil,covariance,cfg.noiseVar);Hhat(cfg.data,n,:,:)=reshape(tr.Hdata,D,1,2,2);for d=find(packet.validReMask(:,n)).',ep=auditEpDetectorOjcd(reshape(double(packet.y(d,n,:)),2,1),reshape(tr.Hdata(d,:,:),2,2),cfg.noiseVar,constellation);llrGrid(:,:,d,n)=ep.bitLlr.';variance(offset+(1:2))=ep.posteriorVariance;offset=offset+2;rollback=rollback+ep.negativePrecisionRollbackCount;end,end
        result=decodeMetrics(packet,Hhat,llrGrid,toc(t));result.negativePrecisionRollbackCount=rollback;result.meanEpPosteriorVarianceJcd1=mean(variance);result.meanEpPosteriorVarianceJcd2=NaN;result.ojcdRegularizationCount=NaN;result.meanOjcdWeightNorm=NaN;result.meanOjcdConditionNumber=NaN;result.futureSymbolReadCount=0;result.testTruthOnlineUseCount=0;result.branchLabel="traditional";result=emptyOjcdAudit(result);
    end
    function result=ojcdDecode(packet,covariance)
        t=tic;N=packet.Npayload;D=numel(cfg.data);Hhat=packet.obs;llrGrid=zeros(4,2,D,N);v1=zeros(2*D*N,1);v2=zeros(2*D*N,1);vOffset=0;rollback=0;wn=zeros(N,1);condition=initConditionVectors(2*N);detail=initRollbackDetail();
        for n=1:N
            r=auditOjcdTwoLayerSymbol(reshape(double(packet.y(:,n,:)),D,2),pilotCells(packet,n),covariance,cfg.noiseVar,constellation,validDataMask=packet.validReMask(:,n));
            Hhat(cfg.data,n,:,:)=reshape(r.ojcd.Hdata,D,1,2,2);llrGrid(:,:,:,n)=permute(r.finalExtrinsicLlr,[3 2 1]);validCount=2*nnz(packet.validReMask(:,n));v1(vOffset+(1:validCount))=reshape(r.jcd1PosteriorVariance(packet.validReMask(:,n),:),[],1);v2(vOffset+(1:validCount))=reshape(r.jcd2PosteriorVariance(packet.validReMask(:,n),:),[],1);vOffset=vOffset+validCount;rollback=rollback+r.negativePrecisionRollbackCount;wn(n)=r.ojcd.meanWeightNorm;condition=appendCondition(condition,r.ojcd,2*n-1:2*n);detail=appendRollbackDetail(detail,r);
        end
        v1=v1(1:vOffset);v2=v2(1:vOffset);conditionSummary=auditSummarizeOjcdConditionDiagnostics(condition);
        result=decodeMetrics(packet,Hhat,llrGrid,toc(t));result.negativePrecisionRollbackCount=rollback;result.meanEpPosteriorVarianceJcd1=mean(v1);result.meanEpPosteriorVarianceJcd2=mean(v2);result.ojcdRegularizationCount=conditionSummary.regularizationCount;result.meanOjcdWeightNorm=mean(wn);result.meanOjcdConditionNumber=conditionSummary.conditionMean;result.futureSymbolReadCount=0;result.testTruthOnlineUseCount=0;result.branchLabel="ojcd";
        result.epPrecisionCandidateCountJcd1=detail.candidateJcd1;result.epNegativePrecisionRollbackCountJcd1=detail.rollbackJcd1;result.rollbackRateJcd1=safeRate(detail.rollbackJcd1,detail.candidateJcd1);result.epPrecisionCandidateCountJcd2=detail.candidateJcd2;result.epNegativePrecisionRollbackCountJcd2=detail.rollbackJcd2;result.rollbackRateJcd2=safeRate(detail.rollbackJcd2,detail.candidateJcd2);result.totalRollbackRate=safeRate(detail.rollbackJcd1+detail.rollbackJcd2,detail.candidateJcd1+detail.candidateJcd2);
        conditionFields=fieldnames(conditionSummary);for fi=1:numel(conditionFields),result.(conditionFields{fi})=conditionSummary.(conditionFields{fi});end
        result.auditDetail=struct('rollback',detail,'condition',condition);
    end
    function pil=pilotCells(packet,n)
        pil=cell(2);for rx=1:2,for tx=1:2,pil{rx,tx}=packet.pilotCfr{n,rx,tx};end,end
    end
    function r=decodeMetrics(packet,Hhat,llrGrid,processingTime)
        llr=llrGrid(:);usefulLlr=llr(packet.usefulBitMask);hard=llr<0;pre=mean(hard(packet.usefulBitMask)~=packet.coded);cwPass=false(packet.nCodeword,1);postErrors=0;delivered=0;
        for cw=1:packet.nCodeword,ix=(cw-1)*cfg.ldpc.N+(1:cfg.ldpc.N);dec=logical(ldpcDecode(usefulLlr(ix),cfg.ldpc.dec,50,'DecisionType','hard'));info=dec(1:cfg.ldpc.K);payloadHat=info(1:cfg.ldpc.K-32);truth=packet.payload((cw-1)*(cfg.ldpc.K-32)+(1:cfg.ldpc.K-32));postErrors=postErrors+sum(payloadHat~=truth);cwPass(cw)=isequal(info(cfg.ldpc.K-31:cfg.ldpc.K),ofdm.crc32Bits(payloadHat));delivered=delivered+double(cwPass(cw))*(cfg.ldpc.K-32);end
        nm=zeros(packet.Npayload,1);for n=1:packet.Npayload,a=packet.H(cfg.active,n,:,:);b=Hhat(cfg.active,n,:,:);nm(n)=norm(double(a(:)-b(:)))^2/max(norm(double(a(:)))^2,eps);end
        last=ceil(2*packet.Npayload/3):packet.Npayload;duration=packet.Npayload*cfg.Tsym;preamble=(160+160+144)/cfg.Fs;
        r=struct('avgCsiNmse',mean(nm),'csiNmse',mean(nm),'nmseLastThirdPayload',mean(nm(last)),'preLdpcBer',pre,'postLdpcBer',postErrors/numel(packet.payload),'codewordPassRate',mean(cwPass),'wholePayloadCrcPass',double(all(cwPass)),'deliveredUsefulBits',delivered,'payloadOnlyGoodputMbps',delivered/duration/1e6,'payloadGoodputMbps',delivered/duration/1e6,'endToEndGoodputMbps',delivered/(duration+preamble)/1e6,'processingTimeSec',processingTime,'runtimeSeconds',processingTime,'hasNaN',any(isnan(Hhat(:)))||any(isnan(llr)),'hasInf',any(isinf(Hhat(:)))||any(isinf(llr)));
    end
    function assertGates(g)
        assert(g.inconsistentGroups==0&&g.legacySecondPassUseCount==0&&g.withinSymbolDaFeedbackEvents==0&&g.stateRestartsAfterSymbol1==0&&g.crossSubcarrierStatePropagationEvents==0&&g.repeatedPilotUseCount==0&&g.rejectedTargetsWithDaUpdate==0&&g.paddingTargetsWithDaUpdate==0&&g.maxPilotUpdatesPerTarget<=1&&g.maxDaUpdatesPerTarget<=1);
    end
    function T=hashRow(packet,ncw,pidx,conditionSeed,packetSeed)
        h=packet.hashes;T=table(ncw,pidx,conditionSeed,packetSeed,h.informationBitsHash,h.transmitBitsHash,h.ldpcCodewordHash,h.qamSymbolsHash,h.paddingBitHash,h.paddingSymbolsHash,h.paddingReCount,h.paddingMaskHash,h.channelHash,h.noiseHash,h.receivedSignalHash,h.pilotObservationHash,'VariableNames',{'Ncodeword','packetIndex','conditionSeed','packetSeed','informationBitsHash','transmitBitsHash','ldpcCodewordHash','qamSymbolsHash','paddingBitHash','paddingSymbolsHash','paddingReCount','paddingMaskHash','channelHash','noiseHash','receivedSignalHash','pilotObservationHash'});
    end
    function T=pairedStatistics(R)
        comparisons=["OJCD_LMMSE_EP_Adapted","TraditionalLMMSE_EP_Adapted";"ProposedCausal_EP","BaseKalmanCausal_EP";"ProposedCausal_EP","OJCD_LMMSE_EP_Adapted"];
        metrics=["csiNmse","preLdpcBer","codewordPassRate","payloadGoodputMbps"];lowerIsBetter=[true true false false];rowCount=numel(cfg.Ncodeword)*size(comparisons,1)*numel(metrics);cells=cell(rowCount,1);rowIndex=0;
        for nc=cfg.Ncodeword
            for cidx=1:size(comparisons,1)
                for mi=1:numel(metrics)
                    a=R(R.Ncodeword==nc&R.method==comparisons(cidx,1),:);b=R(R.Ncodeword==nc&R.method==comparisons(cidx,2),:);[~,ia]=sort(a.packetIndex);[~,ib]=sort(b.packetIndex);av=a.(metrics(mi));bv=b.(metrics(mi));delta=av(ia)-bv(ib);tolerance=1e-15;if lowerIsBetter(mi),win=nnz(delta < -tolerance);loss=nnz(delta > tolerance);else,win=nnz(delta > tolerance);loss=nnz(delta < -tolerance);end;tie=numel(delta)-win-loss;rowIndex=rowIndex+1;cells{rowIndex}=table(nc,comparisons(cidx,1),comparisons(cidx,2),metrics(mi),numel(delta),mean(delta),median(delta),std(delta),min(delta),max(delta),win,tie,loss,'VariableNames',{'Ncodeword','methodA','methodB','metric','pairedPacketCount','meanDeltaAminusB','medianDeltaAminusB','stdDelta','minimumDelta','maximumDelta','winCountA','tieCount','lossCountA'});
                end
            end
        end
        T=vertcat(cells{:});
    end
    function result=emptyOjcdAudit(result)
        names={'epPrecisionCandidateCountJcd1','epNegativePrecisionRollbackCountJcd1','rollbackRateJcd1','epPrecisionCandidateCountJcd2','epNegativePrecisionRollbackCountJcd2','rollbackRateJcd2','totalRollbackRate','conditionSampleCount','conditionMean','conditionMedian','conditionP90','conditionP95','conditionP99','conditionMaximum','rcondMinimum','rcondP01','minEigenvalueMinimum','minimumCholeskyPivot','regularizationCount','regularizationRate','maximumRegularizationLoading','solverFailureCount','nonFiniteMatrixCount','nonFiniteSolutionCount','nonFiniteConditionCount','nonFiniteRcondCount','nonFiniteEigenvalueCount','nonFiniteCholeskyPivotCount'};
        for ni=1:numel(names),result.(names{ni})=NaN;end
    end
    function value=safeRate(count,candidate)
        value=auditComputeEpRollbackRate(count,candidate);
    end
    function vectors=initConditionVectors(count)
        vectors=struct('conditionNumber',nan(count,1),'reciprocalConditionNumber',nan(count,1),'minEigenvalueHermitianPart',nan(count,1),'minimumCholeskyPivot',nan(count,1),'regularizationTriggered',false(count,1),'regularizationLoading',zeros(count,1),'solverFailure',false(count,1),'nonFiniteMatrix',false(count,1),'nonFiniteSolution',false(count,1));
    end
    function vectors=appendCondition(vectors,ojcd,indices)
        vectors.conditionNumber(indices)=ojcd.conditionNumbers(:);vectors.reciprocalConditionNumber(indices)=ojcd.reciprocalConditionNumbers(:);vectors.minEigenvalueHermitianPart(indices)=ojcd.minEigenvalueHermitianPart(:);vectors.minimumCholeskyPivot(indices)=ojcd.minimumCholeskyPivot(:);vectors.regularizationTriggered(indices)=ojcd.regularizationTriggered(:);vectors.regularizationLoading(indices)=ojcd.regularizationLoading(:);vectors.solverFailure(indices)=ojcd.solverFailure(:);vectors.nonFiniteMatrix(indices)=ojcd.nonFiniteMatrix(:);vectors.nonFiniteSolution(indices)=ojcd.nonFiniteSolution(:);
    end
    function detail=initRollbackDetail()
        detail=struct('candidateJcd1',0,'rollbackJcd1',0,'candidateJcd2',0,'rollbackJcd2',0,'candidateMatrixJcd1',zeros(cfg.epIterations,2),'rollbackMatrixJcd1',zeros(cfg.epIterations,2),'candidateMatrixJcd2',zeros(cfg.epIterations,2),'rollbackMatrixJcd2',zeros(cfg.epIterations,2));
    end
    function detail=appendRollbackDetail(detail,r)
        detail.candidateJcd1=detail.candidateJcd1+r.epPrecisionCandidateCountJcd1;detail.rollbackJcd1=detail.rollbackJcd1+r.epNegativePrecisionRollbackCountJcd1;detail.candidateJcd2=detail.candidateJcd2+r.epPrecisionCandidateCountJcd2;detail.rollbackJcd2=detail.rollbackJcd2+r.epNegativePrecisionRollbackCountJcd2;detail.candidateMatrixJcd1=detail.candidateMatrixJcd1+r.precisionCandidateCountByIterationStreamJcd1;detail.rollbackMatrixJcd1=detail.rollbackMatrixJcd1+r.rollbackCountByIterationStreamJcd1;detail.candidateMatrixJcd2=detail.candidateMatrixJcd2+r.precisionCandidateCountByIterationStreamJcd2;detail.rollbackMatrixJcd2=detail.rollbackMatrixJcd2+r.rollbackCountByIterationStreamJcd2;
    end
    function result=attachHashes(result,h)
        result.transmitBitsHash=h.transmitBitsHash;result.channelHash=h.channelHash;result.noiseHash=h.noiseHash;result.receivedSignalHash=h.receivedSignalHash;result.pilotObservationHash=h.pilotObservationHash;result.paddingMaskHash=h.paddingMaskHash;
    end
    function summaryTable=diagnosticSummary(R)
        groups=unique(R(:,{'payloadSymbols','method'}),'rows');cells=cell(height(groups),1);
        for gi=1:height(groups),part=R(R.payloadSymbols==groups.payloadSymbols(gi)&R.method==groups.method(gi),:);packetTotal=height(part);totalCodewords=sum(part.Ncodeword);passedCodewords=sum(part.codewordPassRate.*part.Ncodeword);cells{gi}=table(groups.payloadSymbols(gi),groups.method(gi),packetTotal,mean(part.csiNmse),median(part.csiNmse),mean(part.preLdpcBer),median(part.preLdpcBer),totalCodewords,passedCodewords,passedCodewords/max(totalCodewords,1),mean(part.payloadGoodputMbps),median(part.payloadGoodputMbps),mean(part.runtimeSeconds),median(part.runtimeSeconds),nnz(part.hasNaN),nnz(part.hasInf),sum(part.futureSymbolReadCount),sum(part.testTruthOnlineUseCount),'VariableNames',{'payloadSymbols','method','packetCount','meanCsiNmse','medianCsiNmse','meanPreLdpcBer','medianPreLdpcBer','totalCodewords','passedCodewords','codewordPassRate','meanPayloadGoodputMbps','medianPayloadGoodputMbps','meanRuntimeSeconds','medianRuntimeSeconds','hasNaNCount','hasInfCount','futureSymbolReadCountTotal','testTruthOnlineUseCountTotal'});end
        summaryTable=vertcat(cells{:});
    end
    function T=diagnosticPairingHashes(H,methodNames)
        count=height(H)*numel(methodNames);cells=cell(count,1);index=0;
        for hi=1:height(H),for mi=1:numel(methodNames),index=index+1;row=H(hi,:);row.method=methodNames(mi);row.payloadSymbols=cfg.symbolsPerCodeword*row.Ncodeword;cells{index}=row;end,end
        T=vertcat(cells{:});T=movevars(T,{'payloadSymbols','packetIndex','method'},'Before',1);
    end
    function writeOutputs()
        if isDiagnostic20,runtimeName='ojcd_diagnostic20_runtime.txt';configName='ojcd_diagnostic20_config.txt';reportName='ojcd_diagnostic20_report.txt';else,runtimeName='ojcd_baseline_mini_runtime.txt';configName='ojcd_baseline_config.txt';reportName='ojcd_baseline_mini_report.txt';end
        f=fopen(fullfile(out,runtimeName),'w');fprintf(f,'measuredTotalWallTimeSec=%.9g\ncovarianceBuildTimeExcluded=%.9g\n',totalWallTimeSec,covariance.buildTimeSec);fclose(f);
        f=fopen(fullfile(out,configName),'w');fprintf(f,'masterSeed=%d\nSNRdB=%g\nfdHz=%g\nNpacketPerCondition=%d\nNcodeword=%s\nNpayload=%s\nEPiterations=%d\nEPbeta=%.17g\nmethod=%s\n',cfg.ojcdMiniMasterSeed,cfg.snrDb,cfg.fdHz,packetCount,mat2str(cfg.Ncodeword),mat2str(cfg.Npayload),cfg.epIterations,cfg.epBeta,cfg.methodDisplayName);fclose(f);
        f=fopen(fullfile(out,'ojcd_covariance_cache_audit.txt'),'w');fprintf(f,'path=%s\nseed=%d\nsnapshots=%d\nsamples=%d\nminimumEigenvalueBeforeLoading=%.17g\ndiagonalLoading=%.17g\nbuildTimeSec=%.9g\n',cfg.covariancePath,covariance.seed,covariance.numberOfIndependentSnapshots,covariance.sampleCount,covariance.minimumEigenvalueBeforeLoading,covariance.diagonalLoading,covariance.buildTimeSec);fclose(f);
        f=fopen(fullfile(out,reportName),'w','n','UTF-8');
        if isDiagnostic20
            ojcdRows=rows(rows.method=="OJCD_LMMSE_EP_Adapted",:);ratesFinite=all(isfinite([ojcdRows.rollbackRateJcd1;ojcdRows.rollbackRateJcd2;ojcdRows.totalRollbackRate]));ratesInRange=all([ojcdRows.rollbackRateJcd1;ojcdRows.rollbackRateJcd2;ojcdRows.totalRollbackRate]>=0&[ojcdRows.rollbackRateJcd1;ojcdRows.rollbackRateJcd2;ojcdRows.totalRollbackRate]<=1);candidatePositive=all(ojcdRows.epPrecisionCandidateCountJcd1>0&ojcdRows.epPrecisionCandidateCountJcd2>0);amplified=mean(ojcdRows.rollbackRateJcd2)>max(2*mean(ojcdRows.rollbackRateJcd1),mean(ojcdRows.rollbackRateJcd1)+.05);iterationRows=rollbackAudit(rollbackAudit.aggregationLevel=="iteration_stream",:);concentrated=false;if sum(iterationRows.negativePrecisionRollbackCount)>0,concentrated=max(iterationRows.negativePrecisionRollbackCount)/sum(iterationRows.negativePrecisionRollbackCount)>=.8;end
            fprintf(f,'20-packet-per-condition diagnostic run. This is diagnostic evidence, not a final significance conclusion.\npairedPhysicalPackets=%d; packetMethodRows=%d\nrollbackRatesFinite=%d; rollbackRatesInUnitInterval=%d; candidateCountsPositive=%d\nJCD2RollbackRateAbnormallyAmplifiedHeuristic=%d; singleIterationOrStreamConcentrationHeuristic=%d\nNo hard rollback-rate threshold was applied. Padding REs were excluded before EP and OJCD condition samples.\n',2*packetCount,height(rows),ratesFinite,ratesInRange,candidatePositive,amplified,concentrated);
        else
            fprintf(f,'Diagnostic 5-packet mini only; no formal performance conclusion. Rows=%d. Shared packetData and paired seeds were used. Compare Traditional I=1 with OJCD I=2 and Base/Proposed under the same EP detector. Interpret only feasibility and trends; larger samples are required.\n',height(rows));
        end
        fclose(f);
    end
    function validateCovariance(c)
        D=numel(cfg.data);assert(isfield(c,'Rhdhd')&&isfield(c,'Rhdhp')&&isfield(c,'Rhphp')&&isfield(c,'Wtraditional'),'OJCD covariance cache is incomplete.');
        assert(isequal(size(c.Rhdhd),[2 2])&&isequal(size(c.Rhdhp),[2 2])&&isequal(size(c.Rhphp),[2 2])&&numel(c.Wtraditional)==2,'OJCD covariance block layout is invalid.');
        for a=1:2,for b=1:2,Pa=nnz(cfg.pilotTransmitStreamMap==a);Pb=nnz(cfg.pilotTransmitStreamMap==b);assert(isequal(size(c.Rhdhd{a,b}),[D D]));assert(isequal(size(c.Rhdhp{a,b}),[D Pb]));assert(isequal(size(c.Rhphp{a,b}),[Pa Pb]));end;assert(isequal(size(c.Wtraditional{a}),[D nnz(cfg.pilotTransmitStreamMap==a)]));end
    end
end
