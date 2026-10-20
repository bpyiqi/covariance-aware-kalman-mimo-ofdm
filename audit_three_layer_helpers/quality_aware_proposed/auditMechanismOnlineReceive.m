function result = auditMechanismOnlineReceive(cfg,online,Hhat,estimationRuntimeSeconds,options)
%AUDITMECHANISMONLINERECEIVE One EP pass and receiver-observable decode.
arguments
    cfg struct
    online struct
    Hhat
    estimationRuntimeSeconds (1,1) double
    options.captureEpDiagnostics (1,1) logical = false
    options.bypassCapture (1,1) logical = false
end
required={'receivedData','validReMask','usefulBitMask','nCodeword','Npayload'};missing=setdiff(required,fieldnames(online));assert(isempty(missing),'Receiver online packet is missing fields: %s.',strjoin(missing,', '));
D=numel(cfg.data);N=online.Npayload;llrGrid=zeros(4,2,D,N);soft=complex(nan(2,D,N));hardSymbols=complex(nan(2,D,N));posteriorVariance=nan(2,D,N);if options.captureEpDiagnostics,epDiagnostics=cell(D,N);end;if options.bypassCapture,bypass=struct('posteriorMean',soft,'posteriorVariance',posteriorVariance,'bitLlr',llrGrid,'softMean',soft,'softVariance',posteriorVariance);end;timer=tic;constellation=qammod((0:15).',16,'UnitAveragePower',true);
for n=1:N,for d=find(online.validReMask(:,n)).',ep=auditEpDetectorOjcd(reshape(double(online.receivedData(d,n,:)),2,1),reshape(double(Hhat(cfg.data(d),n,:,:)),2,2),cfg.noiseVar,constellation,captureDiagnostic=options.captureEpDiagnostics);llrGrid(:,:,d,n)=ep.bitLlr.';soft(:,d,n)=ep.posteriorMean;hardSymbols(:,d,n)=ep.hardSymbols;posteriorVariance(:,d,n)=ep.posteriorVariance;if options.bypassCapture,bypass.posteriorMean(:,d,n)=ep.posteriorMean;bypass.posteriorVariance(:,d,n)=ep.posteriorVariance;bypass.bitLlr(:,:,d,n)=ep.bitLlr.';bypass.softMean(:,d,n)=ep.posteriorMean;bypass.softVariance(:,d,n)=ep.posteriorVariance;end;if options.captureEpDiagnostics,epDiagnostics{d,n}=ep.diagOut;end;end,end
llr=llrGrid(:);usefulLlr=llr(online.usefulBitMask);codewordPass=false(online.nCodeword,1);
for codeword=1:online.nCodeword,indices=(codeword-1)*cfg.ldpc.N+(1:cfg.ldpc.N);decoded=logical(ldpcDecode(usefulLlr(indices),cfg.ldpc.dec,50,'DecisionType','hard'));info=decoded(1:cfg.ldpc.K);payload=info(1:cfg.ldpc.K-32);codewordPass(codeword)=isequal(info(cfg.ldpc.K-31:cfg.ldpc.K),ofdm.crc32Bits(payload));end
receiverRuntime=toc(timer);result=struct('llr',llr,'softSymbols',soft,'hardSymbols',hardSymbols,'posteriorVariance',posteriorVariance,'codewordPass',codewordPass,'onlineRuntimeSeconds',estimationRuntimeSeconds+receiverRuntime,'hasNaN',any(isnan(Hhat(:)))||any(isnan(llr)),'hasInf',any(isinf(Hhat(:)))||any(isinf(llr)));
if options.captureEpDiagnostics,result.epDiagnostics=epDiagnostics;end
if options.bypassCapture,bypass.rawUsefulLlrHash=localHash(usefulLlr);bypass.channelEstimateHash=localHash(Hhat);bypass.preLdpcBer=NaN;bypass.daAcceptRejectHash=NaN;bypass.ldpcInputHash=localHash(usefulLlr);bypass.randomStateHash=localHash(rng);result.bypassCapture=bypass;end
end

function h=localHash(x)
if isstruct(x),x=x.State;end;x=double(x(:));h=sum(real(x).*(1:numel(x))')+sum(imag(x).*(numel(x):-1:1)');
end
