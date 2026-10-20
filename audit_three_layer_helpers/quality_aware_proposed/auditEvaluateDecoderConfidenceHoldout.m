function [H,X,C]=auditEvaluateDecoderConfidenceHoldout(chunkPaths,cfg,betaStar)
%AUDITEVALUATEDECODERCONFIDENCEHOLDOUT Offline raw/calibrated/clip decoder evaluation.
recordCount=0;for p=1:numel(chunkPaths),loaded=load(chunkPaths(p),'chunk');recordCount=recordCount+numel(loaded.chunk.records);end
detail=cell(recordCount*6,1);clipDetail=cell(recordCount*3*numel(cfg.clipLevels),1);cursor=0;clipCursor=0;
for p=1:numel(chunkPaths)
    loaded=load(chunkPaths(p),'chunk');chunk=loaded.chunk;truth=chunk.codedBits;
    for r=1:numel(chunk.records)
        rec=chunk.records{r};raw=double(rec.rawUsefulLlr);hardRaw=raw<0;
        for cw=1:3
            idx=(cw-1)*cfg.ldpc.N+(1:cfg.ldpc.N);code=truth(idx);wrong=hardRaw(idx)~=code;
            for mode=["raw","temperature"]
                if mode=="raw",value=raw(idx);else,value=betaStar*raw(idx);end
                timer=tic;decoded=logical(ldpcDecode(value,cfg.ldpc.dec,50,'DecisionType','hard'));runtime=toc(timer);
                infoIdx=(cw-1)*(cfg.ldpc.K-32)+(1:cfg.ldpc.K-32);payload=decoded(1:cfg.ldpc.K-32);
                pass=isequal(decoded(cfg.ldpc.K-31:cfg.ldpc.K),ofdm.crc32Bits(payload));
                margin=(1-2*double(code)).*value;wrongAbs=abs(value(wrong));
                cursor=cursor+1;detail{cursor}=table(chunk.scenarioIndex,rec.targetSnrDb,rec.method,cw,mode, ...
                    sum(auditStableSoftplus(-margin)),numel(margin),nnz(wrong),pass,nnz(payload~=chunk.informationBits(infoIdx)), ...
                    localMean(wrongAbs),localMax(wrongAbs),nnz(wrongAbs>=10),runtime, ...
                    'VariableNames',{'scenarioIndex','targetSnrDb','method','codewordIndex','mode','nllSum','bitCount', ...
                    'preBitErrors','decoderPass','postBitErrors','wrongMeanAbsLlr','wrongMaxAbsLlr','wrongHighConfidenceCount10','decoderRuntimeSec'});
            end
            for clip=cfg.clipLevels
                value=betaStar*raw(idx);if isfinite(clip),value=sign(value).*min(abs(value),clip);end
                timer=tic;decoded=logical(ldpcDecode(value,cfg.ldpc.dec,50,'DecisionType','hard'));runtime=toc(timer);
                payload=decoded(1:cfg.ldpc.K-32);pass=isequal(decoded(cfg.ldpc.K-31:cfg.ldpc.K),ofdm.crc32Bits(payload));
                margin=(1-2*double(code)).*value;clipCursor=clipCursor+1;
                clipDetail{clipCursor}=table(rec.method,chunk.scenarioIndex,rec.targetSnrDb,cw,clip,sum(auditStableSoftplus(-margin)),numel(margin),pass,runtime, ...
                    'VariableNames',{'method','scenarioIndex','targetSnrDb','codewordIndex','clipLevel','nllSum','bitCount','decoderPass','decoderRuntimeSec'});
            end
        end
    end
end
D=vertcat(detail{:});CD=vertcat(clipDetail{:});X=localTransitions(D);H=localSummary(D,X,cfg);C=localClipSummary(CD,cfg);
end
function H=localSummary(D,X,cfg)
methods=[cfg.methods "ALL"];rows=cell(numel(methods),1);
for i=1:numel(methods)
    if methods(i)=="ALL",d=D;else,d=D(D.method==methods(i),:);end
    raw=d(d.mode=="raw",:);cal=d(d.mode=="temperature",:);
    rawRecord=groupsummary(raw,{'scenarioIndex','targetSnrDb','method'},'mean','decoderPass');
    calRecord=groupsummary(cal,{'scenarioIndex','targetSnrDb','method'},'mean','decoderPass');
    xr=X(X.method==methods(i)|methods(i)=="ALL",:);
    rows{i}=table(methods(i),sum(raw.nllSum)/sum(raw.bitCount),sum(cal.nllSum)/sum(cal.bitCount), ...
        1-mean(raw.decoderPass),1-mean(cal.decoderPass),1-mean(rawRecord.mean_decoderPass==1), ...
        1-mean(calRecord.mean_decoderPass==1),sum(raw.preBitErrors),sum(cal.preBitErrors), ...
        localWeighted(raw.wrongMeanAbsLlr,raw.preBitErrors),localWeighted(cal.wrongMeanAbsLlr,cal.preBitErrors), ...
        max(raw.wrongMaxAbsLlr,[],'omitnan'),max(cal.wrongMaxAbsLlr,[],'omitnan'), ...
        sum(raw.wrongHighConfidenceCount10),sum(cal.wrongHighConfidenceCount10), ...
        sum(raw.decoderRuntimeSec),sum(cal.decoderRuntimeSec), ...
        nnz(xr.mode=="raw"&xr.fewerPreErrorsButPassToFail),nnz(xr.mode=="temperature"&xr.fewerPreErrorsButPassToFail), ...
        localReverseCount(raw),localReverseCount(cal), ...
        'VariableNames',{'method','pooledNllRaw','pooledNllCalibrated','codewordBlerRaw','codewordBlerCalibrated', ...
        'wholePayloadBlerRaw','wholePayloadBlerCalibrated','preBitErrorsRaw','preBitErrorsCalibrated', ...
        'wrongBitMeanAbsLlrRaw','wrongBitMeanAbsLlrCalibrated','wrongBitMaxAbsLlrRaw','wrongBitMaxAbsLlrCalibrated', ...
        'wrongHighConfidenceCount10Raw','wrongHighConfidenceCount10Calibrated','decoderRuntimeSecRaw','decoderRuntimeSecCalibrated', ...
        'fewerPreErrorsButPassToFailRaw','fewerPreErrorsButPassToFailCalibrated','reverseCrossingCountRaw','reverseCrossingCountCalibrated'});
end
H=vertcat(rows{:});
end
function X=localTransitions(D)
keys=unique(D(:,{'method','scenarioIndex','codewordIndex','mode'}),'rows');rows=cell(height(keys)*6,1);cursor=0;
for i=1:height(keys)
    x=sortrows(D(D.method==keys.method(i)&D.scenarioIndex==keys.scenarioIndex(i)& ...
        D.codewordIndex==keys.codewordIndex(i)&D.mode==keys.mode(i),:),'targetSnrDb');
    for j=1:height(x)-1
        cursor=cursor+1;flag=x.preBitErrors(j+1)<=x.preBitErrors(j)&&x.decoderPass(j)&&~x.decoderPass(j+1);
        rows{cursor}=table(keys.method(i),keys.scenarioIndex(i),keys.codewordIndex(i),keys.mode(i), ...
            x.targetSnrDb(j),x.targetSnrDb(j+1),x.preBitErrors(j),x.preBitErrors(j+1), ...
            x.decoderPass(j),x.decoderPass(j+1),flag,'VariableNames',{'method','scenarioIndex', ...
            'codewordIndex','mode','lowerSnr','upperSnr','lowerPreBitErrors','upperPreBitErrors', ...
            'lowerDecoderPass','upperDecoderPass','fewerPreErrorsButPassToFail'});
    end
end
X=vertcat(rows{1:cursor});
end
function C=localClipSummary(D,cfg)
rows=cell(numel(cfg.methods)*numel(cfg.clipLevels),1);cursor=0;
temperature=D(D.clipLevel==Inf,:);
for method=cfg.methods
    reference=temperature(temperature.method==method,:);
    for clip=cfg.clipLevels
        x=D(D.method==method&D.clipLevel==clip,:);cursor=cursor+1;
        keys={'scenarioIndex','targetSnrDb','codewordIndex'};
        reference=sortrows(reference,keys);x=sortrows(x,keys);
        assert(height(reference)==height(x)&&isequal(reference(:,keys),x(:,keys)));
        passToFail=nnz(reference.decoderPass&~x.decoderPass);
        failToPass=nnz(~reference.decoderPass&x.decoderPass);
        rows{cursor}=table(method,clip,sum(x.nllSum)/sum(x.bitCount),1-mean(x.decoderPass), ...
            passToFail,failToPass,sum(x.decoderRuntimeSec), ...
            'VariableNames',{'method','clipLevel','pooledNll','codewordBler', ...
            'temperaturePassToClipFail','temperatureFailToClipPass','decoderRuntimeSec'});
    end
end
C=vertcat(rows{1:cursor});
end
function count=localReverseCount(D)
snr=unique(D.targetSnrDb);count=0;for method=unique(D.method).',b=zeros(numel(snr),1);for i=1:numel(snr),x=D(D.method==method&D.targetSnrDb==snr(i),:);b(i)=1-mean(x.decoderPass);end;count=count+nnz(b(1:end-1)<.1&b(2:end)>.1);end
end
function value=localWeighted(x,w),valid=isfinite(x)&w>0;if ~any(valid),value=NaN;else,value=sum(x(valid).*w(valid))/sum(w(valid));end,end
function value=localMean(x),if isempty(x),value=NaN;else,value=mean(x);end,end
function value=localMax(x),if isempty(x),value=NaN;else,value=max(x);end,end
