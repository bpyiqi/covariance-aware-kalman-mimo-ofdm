function report = ucUncertaintyPropagationSelftest(~)
% Deterministic mathematical tests only; no receiver or physical seed is used.
syntheticUnitTestSeed=20260724; rng(syntheticUnitTestSeed,'twister');
names={"state order","real-to-complex size","Hermitian","pseudo covariance", ...
 "contraction orientation","contraction linearity","Rcsi PSD","Reff PD", ...
 "PerfectCSI degeneration","posterior mean","posterior variance", ...
 "deterministic posterior","DA legacy degeneration","nonconjugate transpose", ...
 "candidate metric","no inverse calls","core forbidden-token scan","checkcode"};
passed=false(size(names)); detail=strings(size(names)); k=0;
try
    Nr=2; Nt=2; d=4; H=[1+2i 3+4i;5+6i 7+8i]; h=H(:); assert(isequal(h,[H(1,1);H(2,1);H(1,2);H(2,2)])); k=k+1; passed(k)=true;
    Z=randn(2*d); Preal=Z*Z'; [Ph,Pp,dd]=ucRealStateCovToComplex(Preal); assert(isequal(size(Ph),[d d])); k=k+1; passed(k)=true;
    assert(norm(Ph-Ph','fro')<1e-12); k=k+1; passed(k)=true;
    assert(norm(Pp,'fro')>=0 && isfield(dd,'propernessRatio')); assert(norm(ucComplexCovToRealState(Ph,Pp)-Preal,'fro')<1e-10); k=k+1; passed(k)=true;
    Q=randn(d)+1i*randn(d); Ph=Q*Q'; x=[1-2i; .3+.7i]; S=x*x'; A=kron(x.',eye(Nr)); R=ucChannelCovarianceContraction(Ph,S,Nr,Nt); Rdirect=A*Ph*A'; orientationError=max(abs(R(:)-Rdirect(:))); assert(orientationError<=1e-12); k=k+1; passed(k)=true;
    S2=randn(Nt)+1i*randn(Nt); assert(norm(ucChannelCovarianceContraction(Ph,S+S2,Nr,Nt)-R-ucChannelCovarianceContraction(Ph,S2,Nr,Nt),'fro')<1e-11); k=k+1; passed(k)=true;
    Rn=.2*eye(Nr); mx=[.2+.1i;-.3+.4i]; Vx=diag([.1 .3]); [Reff,Rcsi,ed]=ucChannelUncertaintyEffectiveNoise(Rn,Ph,mx,Vx,Nr,Nt); assert(min(real(eig(Rcsi)))>=-1e-11); k=k+1; passed(k)=true;
    assert(min(real(eig(Reff)))>0 && ed.minEigenvalueReff>0); k=k+1; passed(k)=true;
    [R0,C0]=ucChannelUncertaintyEffectiveNoise(Rn,zeros(d),mx,Vx,Nr,Nt); perfectCsiError=max([max(abs(C0(:))),max(abs(R0(:)-Rn(:)))]); assert(perfectCsiError<=1e-14); k=k+1; passed(k)=true;
    q=[.25 .75;1 0]; c=[-1 1]; [mu,V,Sx]=ucDecisionMomentsFromDiscretePosterior(q,c); assert(max(abs(mu-[.5;-1]))<1e-14); k=k+1; passed(k)=true;
    assert(max(abs(diag(V)-[.75;0]))<1e-14 && norm(Sx-(V+mu*mu'),'fro')<1e-14); k=k+1; passed(k)=true;
    assert(V(2,2)==0); k=k+1; passed(k)=true;
    M=5; Mu=randn(Nt,M)+1i*randn(Nt,M); Y=randn(Nr,M)+1i*randn(Nr,M); G=Mu*Mu'; Gsolve=G\eye(Nt); vc=repmat({zeros(Nt)},1,M); [~,Cda]=ucDecisionAwareLocalLsCovariance(Y,Mu,vc,zeros(Nr,Nt),zeros(d),.2*eye(Nr),struct()); Clegacy=.2*kron(Gsolve.',eye(Nr)); legacyCovarianceError=max(abs(Cda(:)-Clegacy(:))); assert(legacyCovarianceError<=1e-12); k=k+1; passed(k)=true;
    assert(norm(Gsolve.'-transpose(Gsolve),'fro')==0); k=k+1; passed(k)=true;
    y=[.3+.2i;-.1+.7i]; Hhat=randn(Nr,Nt)+1i*randn(Nr,Nt); m=ucRobustCandidateMetric(y,Hhat,Ph,Rn,x,.4); Rc=Rn+A*Ph*A'; e=y-Hhat*x; direct=-real(e'*(Rc\e))-log(det(Rc))+.4; assert(abs(m-direct)<1e-11); k=k+1; passed(k)=true;
    coreDir=fileparts(mfilename('fullpath')); fs=dir(fullfile(coreDir,'uc*.m')); fs=fs(~ismember(string({fs.name}),["ucUncertaintyPropagationSelftest.m","ucCaptureAvailabilityAudit.m"])); coreText=""; for ii=1:numel(fs), coreText=coreText+string(fileread(fullfile(coreDir,fs(ii).name))); end; assert(isempty(regexp(coreText,'(?<![A-Za-z])inv\\s*\\(','once'))); k=k+1; passed(k)=true;
    forbidden=["truth","beta","clip","alpha_dec"]; for ii=1:numel(forbidden), assert(~contains(lower(coreText),forbidden(ii))); end; k=k+1; passed(k)=true;
    if exist('checkcode','file')==2, for ii=1:numel(fs), issues=checkcode(fullfile(coreDir,fs(ii).name),'-id'); assert(isempty(issues)); end, end; k=k+1; passed(k)=true;
catch ME
    detail(k+1)=string(ME.identifier)+": "+string(ME.message);
end
for ii=1:numel(names), if passed(ii), detail(ii)="PASS"; elseif strlength(detail(ii))==0, detail(ii)="NOT RUN"; end, end
report=table(names',passed',detail','VariableNames',{'test','passed','detail'});
fprintf('uncertainty propagation selftest: %d/%d passed\n',nnz(passed),numel(passed)); disp(report);
if ~all(passed), error('ucUncertaintyPropagationSelftest:Failed','Selftest failed.'); end
end
