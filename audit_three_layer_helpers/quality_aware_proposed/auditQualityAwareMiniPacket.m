function packet = auditQualityAwareMiniPacket(cfg,nCodeword)
%AUDITQUALITYAWAREMINIPACKET Build one complete paired physical packet.
N=cfg.symbolsPerCodeword*nCodeword;capacity=N*cfg.codedBitsPerOFDMSymbol;
useful=false(capacity,1);transmitBits=logical(randi([0 1],capacity,1));
informationBits=false((cfg.ldpc.K-32)*nCodeword,1);codedBits=false(cfg.ldpc.N*nCodeword,1);
for codeword=1:nCodeword
    payload=logical(randi([0 1],cfg.ldpc.K-32,1));info=[payload;ofdm.crc32Bits(payload)];
    coded=logical(ldpcEncode([double(info);zeros(cfg.ldpc.K-numel(info),1)],cfg.ldpc.enc));
    resourceOffset=(codeword-1)*cfg.symbolsPerCodeword*cfg.codedBitsPerOFDMSymbol;
    resourceIndices=resourceOffset+(1:cfg.ldpc.N);transmitBits(resourceIndices)=coded;useful(resourceIndices)=true;
    informationBits((codeword-1)*(cfg.ldpc.K-32)+(1:cfg.ldpc.K-32))=payload;
    codedBits((codeword-1)*cfg.ldpc.N+(1:cfg.ldpc.N))=coded;
end
qamSymbols=reshape(ofdm.qam16ModBits(double(reshape(transmitBits,cfg.bitsPerQam,[]))),cfg.NT,numel(cfg.data),N);
validReMask=reshape(all(reshape(useful,cfg.bitsPerQam*cfg.NT,[]),1),numel(cfg.data),N);
H=ofdm.generateItuaGmChannel(cfg.NFFT,N,cfg.rho,cfg.Fs);
ltf=ofdm.makeNoisyLtfEstimate(squeeze(H(:,1,:,:)),cfg.active,cfg.noiseVar);
pilotObservation=complex(zeros(size(H),'single'));y=complex(zeros(numel(cfg.data),N,cfg.NR,'single'));noise=complex(zeros(size(y),'single'));pilotCfr=cell(N,cfg.NR,cfg.NT);
for symbolIndex=1:N
    payloadPilot=ofdm.makePayloadPilotObservation(squeeze(H(:,symbolIndex,:,:)),cfg.pilots,cfg.pilotValues,cfg.pilotTransmitStreamMap,cfg.noiseVar);
    pilotObservation(:,symbolIndex,:,:)=ofdm.ltfResidualInterpolate(ltf,payloadPilot,cfg.NFFT);
    for rx=1:cfg.NR,for tx=1:cfg.NT,pilotCfr{symbolIndex,rx,tx}=double(payloadPilot.h_rx(rx,payloadPilot.tx==tx)).';end,end
    for dataIndex=1:numel(cfg.data)
        sampleNoise=sqrt(cfg.noiseVar/2)*(randn(cfg.NR,1)+1i*randn(cfg.NR,1));noise(dataIndex,symbolIndex,:)=single(sampleNoise);
        y(dataIndex,symbolIndex,:)=single(squeeze(H(cfg.data(dataIndex),symbolIndex,:,:))*double(qamSymbols(:,dataIndex,symbolIndex))+sampleNoise);
    end
end
hashes=struct('informationBitsHash',localHash(informationBits),'transmitBitsHash',localHash(transmitBits), ...
    'codedBitsHash',localHash(codedBits),'qamSymbolsHash',localHash(qamSymbols), ...
    'paddingMaskHash',localHash(~useful),'channelHash',localHash(H),'noiseHash',localHash(noise), ...
    'receivedSignalHash',localHash(y),'pilotObservationHash',localHash(pilotObservation));
paddingSymbolMask=repmat(reshape(~validReMask,1,numel(cfg.data),N),cfg.NT,1,1);
hashes.paddingBitsHash=localHash(transmitBits(~useful));hashes.paddingSymbolsHash=localHash(qamSymbols(paddingSymbolMask));
packet=struct('Npayload',N,'nCodeword',nCodeword,'informationBits',informationBits, ...
    'transmitBits',transmitBits,'codedBits',codedBits,'usefulBitMask',useful, ...
    'qamSymbols',qamSymbols,'qam',qamSymbols,'validReMask',validReMask,'H',H,'ltf',ltf, ...
    'pilotObservation',pilotObservation,'obs',pilotObservation,'pilotCfr',{pilotCfr}, ...
    'receivedData',y,'y',y,'noise',noise,'hashes',hashes);
end
function value=localHash(data)
values=double(data(:));weights=mod((1:numel(values))',104729)+1;
value=sum(real(values).*weights)+sqrt(2)*sum(imag(values).*weights)+sum(abs(values).^2)/max(numel(values),1);
end
