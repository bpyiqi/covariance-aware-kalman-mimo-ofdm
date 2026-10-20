function covariance = auditBuildOjcdFrequencyCovariance(cfg, outputPath)
%AUDITBUILDOJCDFREQUENCYCOVARIANCE Independent offline channel statistics.
% No payload, LDPC, test packet, or online H_true enters this builder.
if nargin<2, outputPath=cfg.covariancePath; end
tBuild=tic; old=rng; restore=onCleanup(@()rng(old)); rng(cfg.covarianceSeed,'twister');
allSc=unique([cfg.data cfg.pilots]); K=numel(allSc); nt=cfg.NT;
samples=complex(zeros(K*nt,cfg.covarianceSnapshots*cfg.NR)); column=0;
for s=1:cfg.covarianceSnapshots
    H=ofdm.generateItuaGmChannel(cfg.NFFT,1,0,cfg.Fs);
    for rx=1:cfg.NR
        column=column+1;
        for tx=1:nt
            rows=(tx-1)*K+(1:K);
            samples(rows,column)=double(H(allSc,1,rx,tx));
        end
    end
end
C=(samples*samples')/size(samples,2); C=(C+C')/2;
minimumEigenvalueBeforeLoading=min(real(eig(C))); diagonalLoading=0;
if minimumEigenvalueBeforeLoading < -1e-11
    diagonalLoading=-minimumEigenvalueBeforeLoading+1e-12; C=C+diagonalLoading*eye(size(C));
elseif minimumEigenvalueBeforeLoading < 0
    diagonalLoading=-minimumEigenvalueBeforeLoading; C=C+diagonalLoading*eye(size(C));
end
dataLocal=arrayfun(@(k)find(allSc==k,1),cfg.data);
pilotByTx=cell(1,nt); pilotLocal=cell(1,nt);
for tx=1:nt
    pilotByTx{tx}=cfg.pilots(cfg.pilotTransmitStreamMap==tx);
    pilotLocal{tx}=arrayfun(@(k)find(allSc==k,1),pilotByTx{tx});
end
Rdd=cell(nt); Rdp=cell(nt); Rpp=cell(nt);
for a=1:nt
    da=(a-1)*K+dataLocal;
    pa=(a-1)*K+pilotLocal{a};
    for b=1:nt
        db=(b-1)*K+dataLocal;
        pb=(b-1)*K+pilotLocal{b};
        Rdd{a,b}=C(da,db); Rdp{a,b}=C(da,pb); Rpp{a,b}=C(pa,pb);
    end
end
W=cell(1,nt); for tx=1:nt,W{tx}=Rdp{tx,tx}/(Rpp{tx,tx}+cfg.noiseVar*eye(numel(pilotByTx{tx})));end
covariance=struct('Cfull',C,'Rhdhd',{Rdd},'Rhdhp',{Rdp},'Rhphp',{Rpp}, ...
    'Wtraditional',{W},'allSubcarriers',allSc,'dataSubcarriers',cfg.data, ...
    'pilotSubcarriersByTx',{pilotByTx},'seed',cfg.covarianceSeed, ...
    'numberOfIndependentSnapshots',cfg.covarianceSnapshots, ...
    'sampleCount',size(samples,2),'minimumEigenvalueBeforeLoading',minimumEigenvalueBeforeLoading, ...
    'diagonalLoading',diagonalLoading,'buildTimeSec',toc(tBuild));
folder=fileparts(outputPath);if ~exist(folder,'dir'),mkdir(folder);end
save(outputPath,'covariance','-v7.3');
end
