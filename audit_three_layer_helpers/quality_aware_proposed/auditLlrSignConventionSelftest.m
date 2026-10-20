function result=auditLlrSignConventionSelftest(root)
%AUDITLLRSIGNCONVENTIONSELFTEST Compare EP LLR, symbol, demapper, and BER hard bits.
cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);assert(cfg.NT==2&&cfg.bitsPerQam==4);constellation=qammod((0:15).',16,'UnitAveragePower',true);
bits=logical([0 0 0 0;1 0 1 1]);x=ofdm.qam16ModBits(double(bits.'));x=x(:);H=[1 .15;.1 1];levels=[1e-10 1e-5 1e-2];names=["noiseless","veryHighSnr","ordinarySnr"];mismatch=zeros(3,1);
fixedNoise=[.03+.02i;-.02+.01i];
for i=1:3
    y=H*x+sqrt(levels(i))*fixedNoise;ep=auditEpDetectorOjcd(y,H,levels(i),constellation);
    llrBits=ep.bitLlr<0;hardSymbolBits=reshape(qamdemod(ep.hardSymbols,16,'UnitAveragePower',true,'OutputType','bit'),4,[]).';
    demapperBits=reshape(ofdm.qam16DemodBits(ep.hardSymbols),4,[]).';
    packetHard=reshape(ep.bitLlr.',[],1)<0;referenceHard=reshape(hardSymbolBits.',[],1);
    mismatch(i)=nnz(llrBits~=hardSymbolBits)+nnz(hardSymbolBits~=demapperBits)+nnz(packetHard~=referenceHard);
end
assert(all(mismatch==0));result=table(names.',levels.',mismatch,'VariableNames',{'condition','noiseVariance','mismatchCount'});
fprintf('LLR sign-convention self-test PASS: positive=bit0, negative=bit1; EP/symbol/demapper/packet hard bits agree in 3 conditions.\n');
end
