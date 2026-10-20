function [rows,tails,variance,quantiles]=auditEpReliabilityBuildRows(cfg,source)
%AUDITEPRELIABILITYBUILDROWS Reconstruct frozen useful-bit coordinates and aggregate raw LLR evidence.
D=numel(source.sourceCfg.data);N=source.sourceCfg.Npayload;maskLoaded=load(source.chunkPaths(1),'chunk');fullIndices=find(maskLoaded.chunk.usefulBitMask);
[bitPosition,stream,dataIndex,symbolIndex]=ind2sub([4 2 D N],fullIndices);codewordIndex=ceil((1:numel(fullIndices)).'/source.sourceCfg.ldpc.N);
third=ceil(3*symbolIndex/N);thirdLabel=["firstThird","middleThird","lastThird"];recordCount=12*7*numel(cfg.methods);
rows=cell(recordCount*9,1);tails=cell(recordCount*5,1);variance=cell(recordCount*2,1);quantiles=cell(recordCount,1);cursor=0;tailCursor=0;varCursor=0;quantileCursor=0;
for s=1:numel(source.chunkPaths)
    loaded=load(source.chunkPaths(s),'chunk');chunk=loaded.chunk;truth=logical(chunk.codedBits(:));assert(numel(truth)==numel(fullIndices));
    for r=1:numel(chunk.records)
        rec=chunk.records{r};llr=double(rec.rawUsefulLlr(:));hard=llr<0;error=hard~=truth;margin=(1-2*double(truth)).*llr;absLlr=abs(llr);
        base=struct('method',string(rec.method),'targetSnrDb',double(rec.targetSnrDb));
        pooledMethod=base;pooledMethod.targetSnrDb=-999;cursor=cursor+1;rows{cursor}=localRows("method",base.method,llr,error,margin,pooledMethod);
        pooledSnr=base;pooledSnr.method="ALL";cursor=cursor+1;rows{cursor}=localRows("snr",string(base.targetSnrDb),llr,error,margin,pooledSnr);
        cursor=cursor+1;rows{cursor}=localRows("methodSnr",base.method+"@"+string(base.targetSnrDb),llr,error,margin,base);
        cursor=cursor+1;rows{cursor}=localGrouped("stream",string(stream),llr,error,margin,base);
        cursor=cursor+1;rows{cursor}=localGrouped("qamBitPosition",string(bitPosition),llr,error,margin,base);
        cursor=cursor+1;rows{cursor}=localGrouped("codewordIndex",string(codewordIndex),llr,error,margin,base);
        cursor=cursor+1;rows{cursor}=localGrouped("ofdmSymbolInterval",thirdLabel(third).',llr,error,margin,base);
        cursor=cursor+1;rows{cursor}=localGrouped("dataSubcarrier",string(source.sourceCfg.data(dataIndex)).',llr,error,margin,base);
        bins=discretize(absLlr,cfg.absLlrEdges);cursor=cursor+1;rows{cursor}=localGrouped("absLlrBin",cfg.absLlrLabels(bins).',llr,error,margin,base);
        for threshold=[5 10 20 40 80]
            wrong=error&absLlr>=threshold;correct=~error&absLlr>=threshold;tailCursor=tailCursor+1;
            tails{tailCursor}=table(base.method,base.targetSnrDb,threshold,nnz(wrong),nnz(correct),sum(auditStableSoftplus(-margin(wrong))),sum(auditStableSoftplus(-margin)), ...
                'VariableNames',{'method','targetSnrDb','absLlrThreshold','wrongBitCount','correctBitCount','wrongTailNll','totalNll'});
        end
        for streamValue=1:2
            streamTake=stream==streamValue;wrongAbs=absLlr(error&streamTake);varCursor=varCursor+1;variance{varCursor}=table(base.method,chunk.scenarioIndex,base.targetSnrDb,streamValue, ...
                "notCapturedInRawChunk",NaN,NaN,NaN,mean(error(streamTake)),mean(error(streamTake)),mean(absLlr(streamTake)),localMean(wrongAbs),localMax(wrongAbs), ...
                'VariableNames',{'method','scenarioIndex','targetSnrDb','stream','availability','posteriorSymbolVariance','extrinsicVariance', ...
                'varianceUsedForLlr','empiricalSymbolError','empiricalBitError','meanAbsLlr','wrongBitMeanAbsLlr','wrongBitMaxAbsLlr'});
        end
        quantileCursor=quantileCursor+1;quantiles{quantileCursor}=table(base.method,chunk.scenarioIndex,base.targetSnrDb,median(margin), ...
            auditDeterministicPercentile(margin,.95),'VariableNames',{'method','scenarioIndex','targetSnrDb','medianSignedMargin','p95SignedMargin'});
    end
end
rows=vertcat(rows{1:cursor});tails=vertcat(tails{1:tailCursor});variance=vertcat(variance{1:varCursor});quantiles=vertcat(quantiles{1:quantileCursor});
end
function row=localRows(dimension,value,llr,error,margin,base)
row=localStats(repmat(string(value),numel(llr),1),dimension,llr,error,margin,base);
end
function row=localGrouped(dimension,values,llr,error,margin,base)
row=localStats(string(values(:)),dimension,llr,error,margin,base);
end
function rows=localStats(values,dimension,llr,error,margin,base)
labels=unique(values,'stable');rows=cell(numel(labels),1);
for i=1:numel(labels)
    take=values==labels(i);l=llr(take);e=error(take);m=margin(take);pred=localErrorProbability(abs(l));
    rows{i}=table(string(dimension),labels(i),base.method,base.targetSnrDb,nnz(take),nnz(e),sum(pred),sum(m),nnz(m<0),sum(auditStableSoftplus(-m)),sum((pred-double(e)).^2), ...
        'VariableNames',{'dimension','dimensionValue','method','targetSnrDb','bitCount','errorCount','predictedErrorProbabilitySum','signedMarginSum','negativeMarginCount','nllSum','brierSum'});
end
rows=vertcat(rows{:});
end
function p=localErrorProbability(a),p=zeros(size(a));low=a<36;p(low)=1./(1+exp(a(low)));p(~low)=exp(-a(~low));end
function value=localMean(x),if isempty(x),value=0;else,value=mean(x);end,end
function value=localMax(x),if isempty(x),value=0;else,value=max(x);end,end
