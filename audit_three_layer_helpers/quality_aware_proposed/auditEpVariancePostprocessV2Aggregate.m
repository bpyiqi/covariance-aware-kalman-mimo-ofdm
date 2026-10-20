function [methodRows,statusRows,floorRows,ojcdRows,extremeRows,hashRows]=auditEpVariancePostprocessV2Aggregate(cfg,meta)
%AUDITEPVARIANCEPOSTPROCESSV2AGGREGATE Rebuild read-only statistics from scenario MAT and dev12 chunks.
% The frozen replay contains 45 receiver records and 54 diagnostic layers.
methodCells=cell(54,1);statusCells=cell(270,1);floorCells=cell(54,1);
ojcdCells=cell(18,1);extremeCells=cell(45,1);hashCells=cell(45,1);
mc=0;sc=0;fc=0;oc=0;ec=0;hc=0;
for scenarioIndex=1:3
    loaded=load(fullfile(cfg.sourceDirectory,sprintf('ep_variance_scenario_%02d.mat',scenarioIndex)),'scenarioRecords');chunkLoaded=load(meta.source.chunkPaths(scenarioIndex),'chunk');chunk=chunkLoaded.chunk;map=auditEpVariancePostprocessV2TruthMap(chunk,meta.cfg);
    assert(numel(loaded.scenarioRecords)==15);
    for r=1:numel(loaded.scenarioRecords)
        record=loaded.scenarioRecords{r};frozen=localFrozenRecord(chunk,record.targetSnrDb,record.method);packed=auditEpVariancePostprocessV2PackLlr(chunk,frozen);preBer=mean(packed.bitErrorByRe(:));expected=localReceiverRow(meta.source.receiverRows,scenarioIndex,record.targetSnrDb,record.method);
        assert(abs(preBer-expected.preLdpcBer)<=1e-15);hc=hc+1;hashCells{hc}=table(scenarioIndex,record.targetSnrDb,record.method,localHash(packed.frozenLlrUseful),true,true,"notCapturedInFrozenReplay",preBer,expected.preLdpcBer, ...
            'VariableNames',{'scenarioIndex','targetSnrDb','method','frozenRawLlrHash','frozenRecordUnique','correctedPreBerMatches','diagnosticFinalLlrAvailability','correctedPreBer','frozenPreBer'});
        for li=1:numel(record.layers)
            layer=record.layers(li);x=record.perReStream{li};x=sortrows(x,{'ofdmSymbol','dataIndex','stream'});assert(height(x)==height(map)&&isequal(x.stream,map.stream)&&isequal(x.dataIndex,map.dataIndex)&&isequal(x.ofdmSymbol,map.ofdmSymbol));
            [bitError,absLlr,~,statusAvailable]=localStatus(layer,packed,map);nr=meta.cfg.NR;assert(nr==2);residual=x.residualPowerOverNoise;
            if layer=="jcd1",residual(:)=NaN;residualAvailability="notCapturedInFrozenReplay";else,residualAvailability="capturedJcd2OrSingle";end
            perRx=residual/nr;logXp=log10(1+x.xpErrorOverVp);[methodCells,mc]=localAppend(methodCells,mc,localStats(x,bitError,absLlr,perRx,logXp,record.method,scenarioIndex,record.targetSnrDb,layer,"all",statusAvailable,residualAvailability));
            if statusAvailable
                labels=["allBitsCorrect","anyBitWrong","highConfidenceWrong10","highConfidenceWrong40","highConfidenceWrong160","saturatedWrong700"];
                masks=[all(~bitError,2),any(bitError,2),any(bitError&absLlr>=10,2),any(bitError&absLlr>=40,2),any(bitError&absLlr>=160,2),any(bitError&absLlr>=700,2)];
                for q=1:numel(labels),[statusCells,sc]=localAppend(statusCells,sc,localStats(x(masks(:,q),:),bitError(masks(:,q),:),absLlr(masks(:,q),:),perRx(masks(:,q)),logXp(masks(:,q)),record.method,scenarioIndex,record.targetSnrDb,layer,labels(q),true,residualAvailability));end
                candidates=x(any(bitError&absLlr>=40,2),:);candidateAbs=absLlr(any(bitError&absLlr>=40,2),:);if ~isempty(candidates),candidates.wrongBitMaxAbsLlr=max(candidateAbs,[],2);candidates=sortrows(candidates,'wrongBitMaxAbsLlr','descend');candidates=candidates(1:min(height(candidates),cfg.maxExtremePerReceiverLayer),:);ec=ec+1;extremeCells{ec}=candidates;end
            end
            floorRow=table(record.method,scenarioIndex,record.targetSnrDb,layer,height(x),sum(x.varianceFloorHits),sum(x.rollbackCount),sum(x.negativePrecisionCandidates),sum(x.nonfiniteCandidates),min(x.minimumVe),min(x.minimumVp),min(x.minimumAbsDenominator),residualAvailability, ...
                'VariableNames',{'method','scenarioIndex','targetSnrDb','layer','recordCount','varianceFloorHits','rollbackCount','negativePrecisionCandidates','nonfiniteCandidates','minimumVe','minimumVp','minimumAbsDenominator','residualAvailability'});[floorCells,fc]=localAppend(floorCells,fc,floorRow);if startsWith(layer,"jcd"),[ojcdCells,oc]=localAppend(ojcdCells,oc,methodCells{mc});end
        end
    end
end
methodRows=vertcat(methodCells{:});statusRows=vertcat(statusCells{:});floorRows=vertcat(floorCells{:});ojcdRows=vertcat(ojcdCells{:});hashRows=vertcat(hashCells{:});if ec==0,extremeRows=table(strings(0,1),'VariableNames',{'noExtremeEvents'});else,extremeRows=vertcat(extremeCells{1:ec});end
end
function record=localFrozenRecord(chunk,snr,method),matches=false(numel(chunk.records),1);for i=1:numel(chunk.records),matches(i)=chunk.records{i}.targetSnrDb==snr&&chunk.records{i}.method==method;end;assert(nnz(matches)==1);record=chunk.records{find(matches,1)};end
function row=localReceiverRow(rows,scenario,snr,method),row=rows(rows.scenarioIndex==scenario&rows.targetSnrDb==snr&rows.method==method,:);assert(height(row)==1);end
function [bitError,absLlr,wrongMax,available]=localStatus(layer,packed,map)
if layer=="jcd1",bitError=false(height(map),4);absLlr=nan(height(map),4);wrongMax=nan(height(map),1);available=false;return;end
assert(height(map)==size(packed.llrByRe,1));bitError=packed.bitErrorByRe;absLlr=abs(packed.llrByRe);wrongMax=max(absLlr.*bitError,[],2);available=true;
end
function T=localStats(x,bitError,absLlr,residual,logXp,method,scenario,snr,layer,status,statusAvailable,residualAvailability)
recordCount=height(x);
if recordCount==0
    bitCount=0;bitErrorCount=0;preLdpcBer=NaN;
    medianVe=NaN;medianVp=NaN;p05Ve=NaN;p05Vp=NaN;varianceFloorRate=NaN;rollbackRate=NaN;
    medianXe=NaN;p95Xe=NaN;p99Xe=NaN;medianLogXp=NaN;p95LogXp=NaN;p99LogXp=NaN;
    medianSumResidual=NaN;medianResidual=NaN;medianGramRcond=NaN;
    high10=0;high40=0;high160=0;high700=0;
else
    medianVe=median(x.extrinsicVariance);medianVp=median(x.posteriorVariance);
    p05Ve=auditDeterministicPercentile(x.extrinsicVariance,.05);p05Vp=auditDeterministicPercentile(x.posteriorVariance,.05);
    varianceFloorRate=sum(x.varianceFloorHits)/recordCount;rollbackRate=sum(x.rollbackCount)/recordCount;
    medianXe=median(x.xeErrorOverVe);p95Xe=auditDeterministicPercentile(x.xeErrorOverVe,.95);p99Xe=auditDeterministicPercentile(x.xeErrorOverVe,.99);
    medianLogXp=median(logXp,'omitnan');p95LogXp=auditDeterministicPercentile(logXp,.95);p99LogXp=auditDeterministicPercentile(logXp,.99);
    medianSumResidual=median(2*residual,'omitnan');medianResidual=median(residual,'omitnan');medianGramRcond=median(x.gramRcond);
    if statusAvailable
        bitCount=4*recordCount;bitErrorCount=sum(bitError(:));preLdpcBer=mean(bitError(:));
        high10=sum(any(bitError&absLlr>=10,2));high40=sum(any(bitError&absLlr>=40,2));high160=sum(any(bitError&absLlr>=160,2));high700=sum(any(bitError&absLlr>=700,2));
    else
        bitCount=NaN;bitErrorCount=NaN;preLdpcBer=NaN;high10=NaN;high40=NaN;high160=NaN;high700=NaN;
    end
end
T=table(method,scenario,snr,layer,status,recordCount,bitCount,bitErrorCount,preLdpcBer,medianVe,medianVp,p05Ve,p05Vp,varianceFloorRate,rollbackRate,medianXe,p95Xe,p99Xe,medianLogXp,p95LogXp,p99LogXp,medianSumResidual,medianResidual,medianGramRcond,high10,high40,high160,high700,statusAvailable,residualAvailability, ...
    'VariableNames',localNames());
end
function names=localNames(),names={'method','scenarioIndex','targetSnrDb','layer','errorStatus','recordCount','bitCount','bitErrorCount','preLdpcBer','medianVe','medianVp','p05Ve','p05Vp','varianceFloorRate','rollbackRate','medianXeErrorOverVe','p95XeErrorOverVe','p99XeErrorOverVe','medianLog10XpErrorOverVp','p95Log10XpErrorOverVp','p99Log10XpErrorOverVp','medianSumResidualPowerOverNoise','medianResidualPowerOverNoisePerRx','medianGramRcond','highConfidenceWrong10Count','highConfidenceWrong40Count','highConfidenceWrong160Count','saturatedWrong700Count','statusAvailability','residualAvailability'};end
function [cells,cursor]=localAppend(cells,cursor,value),cursor=cursor+1;cells{cursor}=value;end
function value=localHash(data),v=double(data(:));w=mod((1:numel(v))',104729)+1;value=sum(real(v).*w)+sqrt(2)*sum(imag(v).*w)+sum(abs(v).^2)/max(numel(v),1);end
