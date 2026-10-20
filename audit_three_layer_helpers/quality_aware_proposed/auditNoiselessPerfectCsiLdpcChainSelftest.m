function result=auditNoiselessPerfectCsiLdpcChainSelftest(root)
%AUDITNOISELESSPERFECTCSILDPCCHAINSELFTEST Full 507-symbol noiseless chain.
cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);cfg.masterSeed=2026072602;
scenario=auditBuildPairedSnrScenario(cfg,1);H0=[1 .12;.08 .95];H=complex(zeros(cfg.NFFT,cfg.Npayload,2,2,'single'));
for k=1:cfg.NFFT,for n=1:cfg.Npayload,H(k,n,:,:)=single(H0);end,end
y=complex(zeros(numel(cfg.data),cfg.Npayload,2,'single'));
for n=1:cfg.Npayload,for d=1:numel(cfg.data),y(d,n,:)=single(H0*double(scenario.qam(:,d,n)));end,end
% The received samples are exactly noiseless; 1e-4 is only the detector's
% numerically well-conditioned assumed variance for soft-output formation.
cfg.noiseVar=1e-4;online=struct('receivedData',y,'validReMask',scenario.validReMask,'usefulBitMask',scenario.usefulBitMask, ...
'nCodeword',3,'Npayload',cfg.Npayload);receiver=auditMechanismOnlineReceive(cfg,online,H,0);
hard=receiver.llr<0;usefulHard=hard(scenario.usefulBitMask);mismatch=find(usefulHard~=scenario.codedBits,1);
metric=auditMechanismOfflineDetectionMetrics(cfg,receiver,H,H,scenario.qam,scenario.codedBits,scenario.validReMask);
maxGoodput=3*(cfg.ldpc.K-32)/(cfg.Npayload*cfg.Tsym)/1e6;
assert(isempty(mismatch),'Noiseless chain first coded-bit mismatch index=%d.',mismatch);
assert(metric.preLdpcBer==0&&all(receiver.codewordPass)&&metric.codewordPassRate==1&&abs(metric.payloadGoodputMbps-maxGoodput)<1e-12);
paddingBitsPerCodeword=cfg.symbolsPerCodeword*cfg.codedBitsPerOFDMSymbol-cfg.ldpc.N;
result=struct('firstMismatchIndex',NaN,'preLdpcBer',metric.preLdpcBer,'codewordErrorCount',0, ...
'codewordPassRate',metric.codewordPassRate,'goodputMbps',metric.payloadGoodputMbps,'theoreticalMaximumGoodputMbps',maxGoodput, ...
'paddingBitsPerCodeword',paddingBitsPerCodeword,'paddingRePerCodeword',paddingBitsPerCodeword/8);
fprintf('noiseless PerfectCSI LDPC self-test PASS: BER=0, codewords=3/3, goodput=%.9g Mbps, firstMismatch=none.\n',metric.payloadGoodputMbps);
end
