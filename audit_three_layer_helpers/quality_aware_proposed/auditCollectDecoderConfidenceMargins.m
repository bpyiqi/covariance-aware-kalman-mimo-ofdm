function margins=auditCollectDecoderConfidenceMargins(chunkPaths,methods)
%AUDITCOLLECTDECODERCONFIDENCEMARGINS Collect signed coded-bit margins from chunks.
parts={};cursor=0;
for p=1:numel(chunkPaths)
    loaded=load(chunkPaths(p),'chunk');chunk=loaded.chunk;s=1-2*single(chunk.codedBits);
    for r=1:numel(chunk.records)
        if nargin<2||isempty(methods)||ismember(chunk.records{r}.method,methods)
            cursor=cursor+1;parts{cursor,1}=s.*chunk.records{r}.rawUsefulLlr; %#ok<AGROW>
        end
    end
end
margins=vertcat(parts{1:cursor});
end

