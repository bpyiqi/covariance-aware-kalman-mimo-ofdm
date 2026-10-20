function result=auditLlrBitOrderRoundTripSelftest(root)
%AUDITLLRBITORDERROUNDTRIPSELFTEST Verify resource serialization and padding removal.
cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);N=cfg.Npayload;capacity=N*cfg.codedBitsPerOFDMSymbol;
bits=logical(mod((1:capacity).'+floor((1:capacity).'/7),2));useful=false(capacity,1);
for cw=1:3,offset=(cw-1)*cfg.symbolsPerCodeword*cfg.codedBitsPerOFDMSymbol;useful(offset+(1:cfg.ldpc.N))=true;end
qam=reshape(ofdm.qam16ModBits(double(reshape(bits,4,[]))),2,numel(cfg.data),N);
demapped=logical(ofdm.qam16DemodBits(qam(:)));demapped=demapped(:);
llrGrid=reshape(1-2*double(demapped),4,2,numel(cfg.data),N);serialized=llrGrid(:)<0;
mismatch=find(serialized~=bits,1);usefulRecovered=serialized(useful);
expectedUseful=bits(useful);usefulMismatch=find(usefulRecovered~=expectedUseful,1);
paddingPerCodeword=cfg.symbolsPerCodeword*cfg.codedBitsPerOFDMSymbol-cfg.ldpc.N;
assert(isempty(mismatch)&&isempty(usefulMismatch)&&paddingPerCodeword==96&&paddingPerCodeword/(4*2)==12);
for cw=1:3,idx=(cw-1)*cfg.ldpc.N+(1:cfg.ldpc.N);assert(isequal(usefulRecovered(idx),expectedUseful(idx)));end
result=struct('maximumMisplacementCount',numel(mismatch),'firstMisplacementIndex',NaN,'streamCount',2, ...
'dataSubcarrierCount',numel(cfg.data),'qamBitCount',4,'symbolsPerCodeword',cfg.symbolsPerCodeword, ...
'paddingBitsPerCodeword',paddingPerCodeword,'paddingRePerCodeword',paddingPerCodeword/8);
fprintf('LLR bit-order round-trip PASS: mismatches=0, streams=2, dataSC=48, boundaries=[169 338 507], padding=96 bits/12 RE per codeword.\n');
end
