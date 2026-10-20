function results=auditLlrLdpcSelftest(root)
%AUDITLLRLDPCSELFTEST Run deterministic mapping, sign, decoder, and variance gates.
out=fullfile(root,'results_three_layer_validation','covariance_aware_llr_ldpc_selftest_v1');
assert(exist(out,'dir')~=7,'Refusing to overwrite LLR/LDPC self-test output: %s',out);mkdir(out);
results.ideal=auditLdpcIdealLlrSelftest(root);results.roundTrip=auditLlrBitOrderRoundTripSelftest(root);
results.sign=auditLlrSignConventionSelftest(root);results.noiseless=auditNoiselessPerfectCsiLdpcChainSelftest(root);
results.directionalBracket=localDirectionalTests();results.variance=localVarianceTest();
save(fullfile(out,'llr_ldpc_selftest_results.mat'),'results');
f=fopen(fullfile(out,'llr_ldpc_selftest_report.txt'),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,'LLR/LDPC deterministic self-tests PASS.\nIdeal amplitudes [0.5 1 2 5 10 20 40]: zero errors; reversed sign errors=%d.\n',results.ideal.reverseSignErrorCount);
fprintf(f,'Round trip mismatches=%d; padding=%d bits/%d RE per codeword.\n',results.roundTrip.maximumMisplacementCount,results.roundTrip.paddingBitsPerCodeword,results.roundTrip.paddingRePerCodeword);
fprintf(f,'Sign convention mismatches=%d. Noiseless BER=%g, codeword pass=%g, goodput=%.9g Mbps.\n',sum(results.sign.mismatchCount),results.noiseless.preLdpcBer,results.noiseless.codewordPassRate,results.noiseless.goodputMbps);
fprintf(f,'Directional bracket cases A-G pass=true. Variance definition: complex noise variance=noiseVar, each real dimension=noiseVar/2, EP receives complex noiseVar.\n');
fprintf('LLR/LDPC aggregate self-test PASS: output=%s\n',out);
end
function pass=localDirectionalTests()
method="M";target=.1;run=@(b)auditDirectionalBlerBracketAudit(localS(b,method),method,target);
[A,~]=run([.2 .05]);[B,~]=run([.05 .2]);[C,~]=run([.1 .05]);[D,~]=run([.1 .1]);[E,~]=run([.2 .15]);[F,~]=run([.05 .02]);[G,cross]=run([.2 .05 .2 .04]);
pass=A.validDirectionalBracket&&~A.reverseCrossingWarning&&~B.validDirectionalBracket&&B.reverseCrossingWarning&& ...
C.exactGridHit&&D.targetPlateau&&~D.validDirectionalBracket&&~E.validDirectionalBracket&&~F.validDirectionalBracket&& ...
G.monotonicityWarning&&height(cross)==3&&nnz(cross.validDirectionalBracket)==2&&nnz(cross.reverseCrossingWarning)==1;
assert(pass);
end
function S=localS(values,method)
targetSnrDb=(1:numel(values)).';method=repmat(method,numel(values),1);codewordBler=values(:);S=table(targetSnrDb,method,codewordBler);
end
function pass=localVarianceTest()
nv=10^(-20/10);rng(2026072603,'twister');w=sqrt(nv/2)*(randn(200000,1)+1i*randn(200000,1));
complexVariance=mean(abs(w).^2);realVariance=var(real(w),1);imagVariance=var(imag(w),1);
pass=abs(complexVariance/nv-1)<.015&&abs(realVariance/(nv/2)-1)<.02&&abs(imagVariance/(nv/2)-1)<.02;assert(pass);
end

