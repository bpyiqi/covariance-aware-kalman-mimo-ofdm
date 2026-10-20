function [betaGrid,lossGrid,bitCounts]=auditDecoderConfidenceScenarioLossGrid(chunkPaths,cfg)
%AUDITDECODERCONFIDENCESCENARIOLOSSGRID Exact scenario/method NLL on a frozen grid.
betaGrid=linspace(cfg.betaBounds(1),cfg.betaBounds(2),401);S=numel(chunkPaths);M=numel(cfg.methods);lossGrid=zeros(S,M,numel(betaGrid));bitCounts=zeros(S,M);
for s=1:S
    loaded=load(chunkPaths(s),'chunk');chunk=loaded.chunk;
    for m=1:M
        selected=chunk.records(cellfun(@(r)r.method==cfg.methods(m),chunk.records));margins=cell(numel(selected),1);
        for r=1:numel(selected),margins{r}=(1-2*single(chunk.codedBits)).*selected{r}.rawUsefulLlr;end
        z=vertcat(margins{:});bitCounts(s,m)=numel(z);
        for b=1:numel(betaGrid),lossGrid(s,m,b)=mean(auditStableSoftplus(-double(betaGrid(b))*double(z)));end
    end
end
end

