function [Hbase,Hproposed,diagnostics] = auditOjcdMiniCausalEstimates(cfg,packet)
%AUDITOJCDMINICAUSALESTIMATES Frozen Base/Proposed rules for OJCD mini only.
% The two branches have independent causal states and share only packetData.
K=cfg.NFFT;N=packet.Npayload;F=8;
assert(isequal(size(packet.obs),[K N 2 2]),'packet.obs must be NFFT-by-Npayload-by-2-by-2.');
assert(isequal(size(packet.y),[numel(cfg.data) N 2]),'packet.y must be Ndata-by-Npayload-by-2.');
assert(isequal(size(packet.validReMask),[numel(cfg.data) N]),'validReMask size is inconsistent.');
Z=ofdm.complexToFeatures(packet.obs);
A=reshape(permute(single(Z),[1 3 2]),K*F,N);
stateVariance=max(mean(double(A).^2,2),1e-5);
Q=max(1-cfg.rho^2,1e-8).*stateVariance;R=max(cfg.noiseVar/2,1e-8);
base=initState();proposed=initState();baseTime=0;proposedTime=0;
for n=1:N
    if n>=2
        timer=tic;base=pilotStep(base,n);baseTime=baseTime+toc(timer);
        timer=tic;proposed=pilotStep(proposed,n);proposedTime=proposedTime+toc(timer);
    end
    timer=tic;
    Hseed=proposed.H(:,n,:,:);
    D=numel(cfg.data);Xhat=complex(zeros(2,D));reliability=zeros(1,D);
    for d=1:D
        yVector=reshape(double(packet.y(d,n,:)),2,1);
        Hmatrix=reshape(double(Hseed(cfg.data(d),1,:,:)),2,2);
        xeq=ofdm.mmseEqualize2x2(yVector,Hmatrix,cfg.noiseVar);
        bits=ofdm.qam16DemodBits(xeq);Xhat(:,d)=ofdm.qam16ModBits(double(bits));
        bitLlr=ofdm.qam16DemodLlr(xeq,cfg.noiseVar);reliability(d)=min(abs(bitLlr(:)));
    end
    for d=1:D
        if ~packet.validReMask(d,n),continue;end
        obs=auditBuildLocalMimoPseudoObservation(Xhat,squeeze(packet.y(:,n,:)).',d, ...
            packet.validReMask(:,n),reliability,[1 2 3],2.5,[]);
        if ~obs.accepted,proposed.rejected=proposed.rejected+1;continue;end
        indices=cfg.data(d)+(0:F-1)*K;gain=proposed.P(indices)./(proposed.P(indices)+R);
        proposed.x(indices)=proposed.x(indices)+gain.*(obs.feature-proposed.x(indices));
        proposed.P(indices)=(1-gain).*proposed.P(indices);
        proposed.H(cfg.data(d),n,:,:)=auditFeatureVectorToChannelMatrix(proposed.x(indices));
        proposed.accepted=proposed.accepted+1;proposed.maxDaUpdatesPerTarget=max(proposed.maxDaUpdatesPerTarget,1);
    end
    proposedTime=proposedTime+toc(timer);
end
Hbase=base.H;Hproposed=proposed.H;
diagnostics=struct('inconsistentGroups',0,'legacySecondPassUseCount',0, ...
    'withinSymbolDaFeedbackEvents',0,'stateRestartsAfterSymbol1',0, ...
    'crossSubcarrierStatePropagationEvents',0,'repeatedPilotUseCount',0, ...
    'rejectedTargetsWithDaUpdate',0,'paddingTargetsWithDaUpdate',0, ...
    'maxPilotUpdatesPerTarget',double(N>1),'maxDaUpdatesPerTarget',proposed.maxDaUpdatesPerTarget, ...
    'accepted',proposed.accepted,'rejected',proposed.rejected, ...
    'baseEstimationTimeSec',baseTime,'proposedEstimationTimeSec',proposedTime);

    function s=initState()
        s=struct('x',double(A(:,1)),'P',stateVariance+R, ...
            'H',complex(zeros(K,N,2,2,'single')),'accepted',0,'rejected',0,'maxDaUpdatesPerTarget',0);
        s.H(:,1,:,:)=packet.obs(:,1,:,:);
    end
    function s=pilotStep(s,nSymbol)
        predicted=cfg.rho*s.x;predictedP=cfg.rho^2*s.P+Q;
        gain=predictedP./(predictedP+R);
        s.x=predicted+gain.*(double(A(:,nSymbol))-predicted);s.P=(1-gain).*predictedP;
        feature=permute(reshape(single(s.x),K,F),[1 3 2]);s.H(:,nSymbol,:,:)=ofdm.featuresToComplex(feature);
    end
end
