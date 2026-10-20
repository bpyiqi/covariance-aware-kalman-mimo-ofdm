function map=auditEpVariancePostprocessV2TruthMap(chunk,cfg)
%AUDITEPVARIANCEPOSTPROCESSV2TRUTHMAP Exact stream/subcarrier/symbol order from frozen mask.
D=numel(cfg.data);N=cfg.Npayload;mask4=reshape(chunk.usefulBitMask,4,[]);assert(all(all(mask4==mask4(1,:),1)));fullIndices=find(mask4(1,:)).';[stream,dataIndex,ofdmSymbol]=ind2sub([2 D N],fullIndices);
assert(numel(fullIndices)==48600&&cfg.NR==2);map=table((1:numel(fullIndices)).',stream(:),dataIndex(:),ofdmSymbol(:),'VariableNames',{'reIndex','stream','dataIndex','ofdmSymbol'});
end
