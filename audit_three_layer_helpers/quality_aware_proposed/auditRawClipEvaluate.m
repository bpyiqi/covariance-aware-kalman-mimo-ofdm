function detail=auditRawClipEvaluate(cfg,chunkPaths,scenarioIndices,clipGrid,kind)
%AUDITRAWCLIPEVALUATE Offline NLL and unchanged LDPC decoding over frozen chunks.
arguments,cfg struct,chunkPaths,scenarioIndices,clipGrid,kind (1,1) string="hard",end
rowsPerScenario=7*numel(cfg.methods)*3*numel(clipGrid);rows=cell(numel(scenarioIndices)*rowsPerScenario,1);cursor=0;
for scenarioIndex=scenarioIndices
    loaded=load(chunkPaths(scenarioIndex),'chunk');chunk=loaded.chunk;truth=logical(chunk.codedBits(:));info=logical(chunk.informationBits(:));
    assert(chunk.scenarioIndex==scenarioIndex&&numel(chunk.records)==7*numel(cfg.methods));
    for r=1:numel(chunk.records)
        rec=chunk.records{r};raw=double(rec.rawUsefulLlr(:));assert(numel(raw)==numel(truth)&&all(isfinite(raw)));
        hardRaw=raw<0;
        for c=1:numel(clipGrid)
            C=clipGrid(c);value=auditRawClipTransform(raw,C,kind);assert(all(isfinite(value)));
            hardUnchanged=isequal(hardRaw,value<0);preErrorsRaw=nnz(hardRaw~=truth);preErrors=nnz((value<0)~=truth);
            for cw=1:3
                codedIndex=(cw-1)*cfg.decoder.N+(1:cfg.decoder.N);code=truth(codedIndex);llr=value(codedIndex);
                timer=tic;decoded=logical(ldpcDecode(llr,cfg.decoder.dec,cfg.decoderIterations,'DecisionType','hard'));runtime=toc(timer);
                informationIndex=(cw-1)*(cfg.decoder.K-32)+(1:cfg.decoder.K-32);payload=decoded(1:cfg.decoder.K-32);
                pass=isequal(decoded(cfg.decoder.K-31:cfg.decoder.K),ofdm.crc32Bits(payload));wrong=hardRaw(codedIndex)~=code;
                margin=(1-2*double(code)).*llr;wrongAbs=abs(llr(wrong));cursor=cursor+1;
                rows{cursor}=table(scenarioIndex,rec.targetSnrDb,rec.method,cw,C,kind,sum(auditStableSoftplus(-margin)), ...
                    numel(margin),preErrorsRaw,preErrors,hardUnchanged,pass,nnz(payload~=info(informationIndex)), ...
                    localMean(wrongAbs),localMax(wrongAbs),nnz(wrongAbs>=10),runtime, ...
                    'VariableNames',{'scenarioIndex','targetSnrDb','method','codewordIndex','clipLevel','transform', ...
                    'nllSum','bitCount','preBitErrorsRawRecord','preBitErrorsRecord','hardBitsUnchanged', ...
                    'decoderPass','postBitErrors','wrongBitMeanAbsLlr','wrongBitMaxAbsLlr', ...
                    'wrongHighConfidenceCount10','decoderRuntimeSec'});
            end
        end
    end
end
detail=vertcat(rows{1:cursor});detail=localAttachTransitions(detail);
end
function detail=localAttachTransitions(detail)
detail.rawDecoderPass=false(height(detail),1);detail.passToFail=false(height(detail),1);detail.failToPass=false(height(detail),1);
keys=unique(detail(:,{'scenarioIndex','targetSnrDb','method','codewordIndex','transform'}),'rows');
for i=1:height(keys)
    mask=detail.scenarioIndex==keys.scenarioIndex(i)&detail.targetSnrDb==keys.targetSnrDb(i)& ...
        detail.method==keys.method(i)&detail.codewordIndex==keys.codewordIndex(i)&detail.transform==keys.transform(i);
    indices=find(mask);reference=detail.decoderPass(indices(detail.clipLevel(indices)==Inf));assert(isscalar(reference));
    detail.rawDecoderPass(indices)=reference;detail.passToFail(indices)=reference&~detail.decoderPass(indices);
    detail.failToPass(indices)=~reference&detail.decoderPass(indices);
end
end
function value=localMean(x),if isempty(x),value=0;else,value=mean(x);end,end
function value=localMax(x),if isempty(x),value=0;else,value=max(x);end,end
