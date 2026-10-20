function scenario=auditBuildPairedSnrScenario(cfg,scenarioIndex)
%AUDITBUILDPAIREDSNRSCENARIO Generate every SNR-invariant random object once.
scenarioSeed=auditPairedSnrScenarioSeed(cfg.masterSeed,scenarioIndex);
paddingSeed=scenarioSeed+101;bitsSeed=scenarioSeed+202;channelSeed=scenarioSeed+303;
unitNoiseSeed=scenarioSeed+404;pilotNoiseSeed=scenarioSeed+505;
N=cfg.Npayload;capacity=N*cfg.codedBitsPerOFDMSymbol;
rng(paddingSeed,'twister');useful=false(capacity,1);transmitBits=logical(randi([0 1],capacity,1));
informationBits=false((cfg.ldpc.K-32)*cfg.Ncodeword,1);codedBits=false(cfg.ldpc.N*cfg.Ncodeword,1);
rng(bitsSeed,'twister');
for cw=1:cfg.Ncodeword
    payload=logical(randi([0 1],cfg.ldpc.K-32,1));info=[payload;ofdm.crc32Bits(payload)];
    coded=logical(ldpcEncode([double(info);zeros(cfg.ldpc.K-numel(info),1)],cfg.ldpc.enc));
    offset=(cw-1)*cfg.symbolsPerCodeword*cfg.codedBitsPerOFDMSymbol;indices=offset+(1:cfg.ldpc.N);
    transmitBits(indices)=coded;useful(indices)=true;
    informationBits((cw-1)*(cfg.ldpc.K-32)+(1:cfg.ldpc.K-32))=payload;
    codedBits((cw-1)*cfg.ldpc.N+(1:cfg.ldpc.N))=coded;
end
qam=reshape(ofdm.qam16ModBits(double(reshape(transmitBits,cfg.bitsPerQam,[]))),cfg.NT,numel(cfg.data),N);
validReMask=reshape(all(reshape(useful,cfg.bitsPerQam*cfg.NT,[]),1),numel(cfg.data),N);
rng(channelSeed,'twister');H=ofdm.generateItuaGmChannel(cfg.NFFT,N,cfg.rho,cfg.Fs);
clean=complex(zeros(numel(cfg.data),N,cfg.NR,'single'));
for n=1:N,for d=1:numel(cfg.data),clean(d,n,:)=single(squeeze(H(cfg.data(d),n,:,:))*double(qam(:,d,n)));end,end
rng(unitNoiseSeed,'twister');Wunit=single((randn(size(clean))+1i*randn(size(clean)))/sqrt(2));
[pilotClean,pilotCfrClean]=localPilot(cfg,H,0);
rng(pilotNoiseSeed,'twister');[pilotUnit,pilotCfrUnit]=localPilot(cfg,H,1);
pilotNoiseUnit=pilotUnit-pilotClean;pilotCfrNoiseUnit=cell(size(pilotCfrClean));
for i=1:numel(pilotCfrClean),pilotCfrNoiseUnit{i}=pilotCfrUnit{i}-pilotCfrClean{i};end
paddingMask=~useful;paddingSymbolMask=repmat(reshape(~validReMask,1,numel(cfg.data),N),cfg.NT,1,1);
hashes=struct('H',localHash(H),'txBits',localHash(transmitBits),'qam',localHash(qam), ...
    'paddingBits',localHash(transmitBits(paddingMask)),'paddingSymbols',localHash(qam(paddingSymbolMask)), ...
    'unitNoise',localHash(Wunit));
scenario=struct('scenarioIndex',scenarioIndex,'scenarioSeed',scenarioSeed,'paddingSeed',paddingSeed, ...
    'bitsSeed',bitsSeed,'channelSeed',channelSeed,'unitNoiseSeed',unitNoiseSeed,'pilotNoiseSeed',pilotNoiseSeed, ...
    'Npayload',N,'nCodeword',cfg.Ncodeword,'informationBits',informationBits,'transmitBits',transmitBits, ...
    'codedBits',codedBits,'usefulBitMask',useful,'qam',qam,'validReMask',validReMask,'H',H, ...
    'cleanReceivedGrid',clean,'Wunit',Wunit,'pilotObservationClean',pilotClean, ...
    'pilotObservationNoiseUnit',pilotNoiseUnit,'pilotCfrClean',{pilotCfrClean}, ...
    'pilotCfrNoiseUnit',{pilotCfrNoiseUnit},'hashes',hashes);
end
function [obs,cfr]=localPilot(cfg,H,noiseVar)
N=size(H,2);ltf=ofdm.makeNoisyLtfEstimate(squeeze(H(:,1,:,:)),cfg.active,noiseVar);
obs=complex(zeros(size(H),'single'));cfr=cell(N,cfg.NR,cfg.NT);
for n=1:N
    p=ofdm.makePayloadPilotObservation(squeeze(H(:,n,:,:)),cfg.pilots,cfg.pilotValues,cfg.pilotTransmitStreamMap,noiseVar);
    obs(:,n,:,:)=ofdm.ltfResidualInterpolate(ltf,p,cfg.NFFT);
    for rx=1:cfg.NR,for tx=1:cfg.NT,cfr{n,rx,tx}=double(p.h_rx(rx,p.tx==tx)).';end,end
end
end
function value=localHash(data)
v=double(data(:));w=mod((1:numel(v))',104729)+1;
value=sum(real(v).*w)+sqrt(2)*sum(imag(v).*w)+sum(abs(v).^2)/max(numel(v),1);
end

