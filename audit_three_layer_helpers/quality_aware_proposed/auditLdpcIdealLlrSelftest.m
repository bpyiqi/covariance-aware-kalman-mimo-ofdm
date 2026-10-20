function result=auditLdpcIdealLlrSelftest(root)
%AUDITLDPCIDEALLLRSELFTEST Confirm decoder sign, amplitude, and boundaries.
if nargin<1,root=fileparts(fileparts(fileparts(mfilename('fullpath'))));end;assert(isfolder(root));
cfg=ofdm.makeLdpcConfig(1/2);rng(2026072601,'twister');amplitudes=[.5 1 2 5 10 20 40];errors=zeros(size(amplitudes));
info=logical(randi([0 1],cfg.K,1));coded=logical(ldpcEncode(double(info),cfg.enc));
for i=1:numel(amplitudes),llr=amplitudes(i)*(1-2*double(coded));assert(all((llr>0)==~coded));decoded=logical(ldpcDecode(llr,cfg.dec,50,'DecisionType','hard'));errors(i)=nnz(decoded~=info);end
reversed=logical(ldpcDecode(-40*(1-2*double(coded)),cfg.dec,50,'DecisionType','hard'));reverseErrors=nnz(reversed~=info);
threeInfo=logical(randi([0 1],cfg.K*3,1));threeErrors=zeros(3,1);
for cw=1:3,idx=(cw-1)*cfg.K+(1:cfg.K);c=logical(ldpcEncode(double(threeInfo(idx)),cfg.enc));d=logical(ldpcDecode(10*(1-2*double(c)),cfg.dec,50,'DecisionType','hard'));threeErrors(cw)=nnz(d~=threeInfo(idx));end
assert(all(errors==0)&&all(threeErrors==0)&&reverseErrors>cfg.K/4);
result=struct('amplitudes',amplitudes,'errorCounts',errors,'reverseSignErrorCount',reverseErrors,'threeCodewordErrors',threeErrors,'positiveLlrMeansZero',true);
fprintf('ideal LLR self-test PASS: amplitudes=[%s], errors=0, reversedSignErrors=%d, threeCodewordErrors=0.\n',num2str(amplitudes),reverseErrors);
end
